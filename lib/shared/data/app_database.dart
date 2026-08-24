import 'dart:convert';
import 'package:sqflite/sqflite.dart' as plain;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'database_key_service.dart';
import 'device_service.dart';
import 'local_database.dart';

class AppDatabase {
  static Database? _db;
  static const _dbName = 'aqua_app_secure.db';
  static const _legacyDbName = 'aqua_app.db';
  static const _obsoleteSyncDbName = 'dentalcare_sync.db';
  static const _dbVersion = 6;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    final legacyPath = p.join(dbPath, _legacyDbName);
    final secureExists = await databaseExists(path);
    final existingKey = await DatabaseKeyService.read();
    if (secureExists && existingKey == null) {
      throw StateError(
        'The encrypted database key is unavailable. Refusing to overwrite local data.',
      );
    }
    final key = existingKey ?? await DatabaseKeyService.getOrCreate();
    if (!secureExists && await plain.databaseExists(legacyPath)) {
      await _migratePlaintextDatabase(legacyPath, path, key);
    }
    final db = await openDatabase(
      path,
      password: key,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onOpen: _verifyCipher,
    );
    final obsoleteSyncPath = p.join(dbPath, _obsoleteSyncDbName);
    if (await plain.databaseExists(obsoleteSyncPath)) {
      await plain.deleteDatabase(obsoleteSyncPath);
    }
    return db;
  }

  static Future<void> _migratePlaintextDatabase(
    String legacyPath,
    String securePath,
    String key,
  ) async {
    final source = await plain.openDatabase(
      legacyPath,
      readOnly: true,
      singleInstance: false,
    );
    Database? target;
    try {
      target = await openDatabase(
        securePath,
        password: key,
        version: _dbVersion,
        singleInstance: false,
        onCreate: _createTables,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = OFF'),
      );
      await _verifyCipher(target);
      const tables = [
        'patients',
        'appointments',
        'pending_orders',
        'metadata',
        'sync_queue',
      ];
      final sourceTables = (await source.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      )).map((row) => row['name']?.toString()).toSet();
      final targetColumns = <String, Set<String>>{};
      for (final table in tables.where(sourceTables.contains)) {
        targetColumns[table] =
            (await target.rawQuery('PRAGMA table_info($table)'))
                .map((column) => column['name']?.toString())
                .whereType<String>()
                .toSet();
      }
      await target.transaction((txn) async {
        for (final table in tables.where(sourceTables.contains)) {
          var offset = 0;
          const batchSize = 250;
          while (true) {
            final rows = await source.query(
              table,
              limit: batchSize,
              offset: offset,
            );
            if (rows.isEmpty) break;
            final batch = txn.batch();
            for (final row in rows) {
              // Older plaintext databases can contain columns that were
              // deliberately removed from the secure local schema (for
              // example clinic_id/doctor_id). Copy only the intersection so
              // a legacy install can always migrate without losing its rows.
              final compatibleRow = Map<String, Object?>.fromEntries(
                row.entries.where(
                  (entry) => targetColumns[table]!.contains(entry.key),
                ),
              );
              batch.insert(
                table,
                compatibleRow,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            await batch.commit(noResult: true);
            offset += rows.length;
          }
        }
      });
      for (final table in tables.where(sourceTables.contains)) {
        final sourceCount =
            Sqflite.firstIntValue(
              await source.rawQuery('SELECT COUNT(*) FROM $table'),
            ) ??
            0;
        final targetCount =
            Sqflite.firstIntValue(
              await target.rawQuery('SELECT COUNT(*) FROM $table'),
            ) ??
            0;
        if (sourceCount != targetCount) {
          throw StateError(
            'Encrypted database migration verification failed for $table.',
          );
        }
      }
      await _verifyCipher(target);
      await target.close();
      target = null;
      await source.close();
      await plain.deleteDatabase(legacyPath);
    } catch (_) {
      await target?.close();
      await source.close();
      await deleteDatabase(securePath);
      rethrow;
    }
  }

  static Future<void> _verifyCipher(Database db) async {
    final version = await db.rawQuery('PRAGMA cipher_version');
    if (version.isEmpty ||
        version.first.values.every(
          (value) => value == null || value.toString().isEmpty,
        )) {
      throw StateError('SQLCipher is not active for the local database.');
    }
    await db.rawQuery('PRAGMA cipher_integrity_check');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation TEXT NOT NULL,
          table_name TEXT NOT NULL,
          record_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0,
          status TEXT DEFAULT 'pending'
        )
      ''');
    }
    if (oldVersion < 3) {
      await _createQueryIndexes(db);
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE patients ADD COLUMN version INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute('ALTER TABLE sync_queue ADD COLUMN operation_id TEXT');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS sync_queue_operation_id_idx ON sync_queue(operation_id)',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE appointments ADD COLUMN version INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 6) {
      await _createAcademicResultTables(db);
    }
  }

  static Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        age INTEGER NOT NULL DEFAULT 0,
        address TEXT NOT NULL DEFAULT '',
        registrationDate TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        photoUrl TEXT NOT NULL DEFAULT '',
        amountDue REAL NOT NULL DEFAULT 0,
        amountPaid REAL NOT NULL DEFAULT 0,
        todayPayment REAL NOT NULL DEFAULT 0,
        appointmentDate TEXT,
        treatmentPlan TEXT NOT NULL DEFAULT '[]',
        photos TEXT NOT NULL DEFAULT '[]',
        updated_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        device_id TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        patientId TEXT NOT NULL,
        patientName TEXT NOT NULL DEFAULT '',
        time TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT '',
        treatment TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        reminderSent INTEGER NOT NULL DEFAULT 0,
        notificationSent INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        device_id TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_orders (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
          status TEXT DEFAULT 'pending'
          ,operation_id TEXT
        )
    ''');
    await _createAcademicResultTables(db);
    await _createQueryIndexes(db);
  }

  static Future<void> _createAcademicResultTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS result_uploads (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS result_records (
        id TEXT PRIMARY KEY,
        upload_id TEXT NOT NULL,
        exam_number TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY(upload_id) REFERENCES result_uploads(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS result_records_upload_idx ON result_records(upload_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS result_records_exam_idx ON result_records(exam_number)',
    );
  }

  static Future<void> _createQueryIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS patients_updated_idx ON patients(updated_at DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS patients_name_idx ON patients(name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS patients_phone_idx ON patients(phone)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS appointments_date_idx ON appointments(date DESC, time DESC)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS sync_queue_operation_id_idx ON sync_queue(operation_id)',
    );
  }

  // ── Metadata ──
  static Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert('metadata', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getMetadata(String key) async {
    final db = await database;
    final rows = await db.query('metadata', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  // ── Patients CRUD ──

  static Future<List<Map<String, dynamic>>> getAllPatients() async {
    final db = await database;
    return db.query(
      'patients',
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> getPatientsPage(
    int offset,
    int limit,
  ) async {
    final db = await database;
    return db.query(
      'patients',
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  static Future<int> getPatientsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM patients WHERE deleted_at IS NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<Map<String, dynamic>?> getPatientById(String id) async {
    final db = await database;
    final rows = await db.query(
      'patients',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<void> insertPatient(Map<String, dynamic> patient) async {
    final db = await database;
    final deviceId = await DeviceService.getDeviceId();
    final now = DateTime.now().toUtc().toIso8601String();
    patient['updated_at'] = now;
    patient['is_synced'] = 0;
    patient['device_id'] = deviceId;
    patient['deleted_at'] = null;
    patient['version'] = patient['version'] ?? 1;
    if (!patient.containsKey('id') || patient['id'] == null) {
      patient['id'] = const Uuid().v4();
    }
    await db.insert(
      'patients',
      patient,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await LocalDatabaseService.addToQueue(
      operation: 'insert',
      tableName: 'patients',
      recordId: patient['id'] as String,
      payload: jsonEncode(patient),
    );
  }

  static Future<void> updatePatient(
    String id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    final current = await db.query(
      'patients',
      columns: ['version'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final currentVersion = current.isEmpty
        ? 1
        : ((current.first['version'] as num?)?.toInt() ?? 1);
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    data['is_synced'] = 0;
    data.remove('version');
    await db.update('patients', data, where: 'id = ?', whereArgs: [id]);
    final payload = Map<String, dynamic>.from(data);
    payload['id'] = id;
    payload['version'] = currentVersion;
    await LocalDatabaseService.addToQueue(
      operation: 'update',
      tableName: 'patients',
      recordId: id,
      payload: jsonEncode(payload),
    );
  }

  static Future<void> softDeletePatient(String id) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'patients',
      {'deleted_at': now, 'updated_at': now, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await LocalDatabaseService.addToQueue(
      operation: 'delete',
      tableName: 'patients',
      recordId: id,
      payload: jsonEncode({'id': id}),
    );
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedPatients() async {
    final db = await database;
    return db.query('patients', where: 'is_synced = 0');
  }

  static Future<void> markPatientSynced(String id) async {
    final db = await database;
    await db.update(
      'patients',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> applyLocalPayment(String id, double amount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE patients SET amountPaid = amountPaid + ?, todayPayment = todayPayment + ?, updated_at = ? WHERE id = ?',
      [amount, amount, DateTime.now().toUtc().toIso8601String(), id],
    );
  }

  static Future<void> applyServerPaymentSummary(
    String id, {
    required double amountPaid,
    required double todayPayment,
    required int version,
  }) async {
    final db = await database;
    await db.update(
      'patients',
      {
        'amountPaid': amountPaid,
        'todayPayment': todayPayment,
        'version': version,
        'is_synced': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> upsertPatientFromSync(Map<String, dynamic> row) async {
    final db = await database;
    final local = await db.query(
      'patients',
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    if (local.isNotEmpty) {
      final localUpdatedAt = local.first['updated_at'] as String? ?? '';
      final remoteUpdatedAt = row['updated_at'] as String? ?? '';
      if (remoteUpdatedAt.compareTo(localUpdatedAt) < 0) return;
    }
    row['is_synced'] = 1;
    row['device_id'] = row['device_id'] ?? await DeviceService.getDeviceId();
    await db.insert(
      'patients',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Appointments CRUD ──

  static Future<List<Map<String, dynamic>>> getAllAppointments() async {
    final db = await database;
    return db.query(
      'appointments',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC, time DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> getAppointmentsPage(
    int offset,
    int limit,
  ) async {
    final db = await database;
    return db.query(
      'appointments',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC, time DESC',
      limit: limit,
      offset: offset,
    );
  }

  static Future<int> getAppointmentsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM appointments WHERE deleted_at IS NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<Map<String, dynamic>?> getAppointmentById(String id) async {
    final db = await database;
    final rows = await db.query(
      'appointments',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<void> insertAppointment(
    Map<String, dynamic> appointment,
  ) async {
    final db = await database;
    final deviceId = await DeviceService.getDeviceId();
    final now = DateTime.now().toUtc().toIso8601String();
    appointment['updated_at'] = now;
    appointment['is_synced'] = 0;
    appointment['device_id'] = deviceId;
    appointment['deleted_at'] = null;
    appointment['version'] = appointment['version'] ?? 1;
    if (!appointment.containsKey('id') || appointment['id'] == null) {
      appointment['id'] = const Uuid().v4();
    }
    await db.insert(
      'appointments',
      appointment,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await LocalDatabaseService.addToQueue(
      operation: 'insert',
      tableName: 'appointments',
      recordId: appointment['id'] as String,
      payload: jsonEncode(appointment),
    );
  }

  static Future<void> updateAppointment(
    String id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    final current = await db.query(
      'appointments',
      columns: ['version'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final currentVersion = current.isEmpty
        ? 1
        : ((current.first['version'] as num?)?.toInt() ?? 1);
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    data['is_synced'] = 0;
    data.remove('version');
    await db.update('appointments', data, where: 'id = ?', whereArgs: [id]);
    final payload = Map<String, dynamic>.from(data);
    payload['id'] = id;
    payload['version'] = currentVersion;
    await LocalDatabaseService.addToQueue(
      operation: 'update',
      tableName: 'appointments',
      recordId: id,
      payload: jsonEncode(payload),
    );
  }

  static Future<void> softDeleteAppointment(String id) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'appointments',
      {'deleted_at': now, 'updated_at': now, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await LocalDatabaseService.addToQueue(
      operation: 'delete',
      tableName: 'appointments',
      recordId: id,
      payload: jsonEncode({'id': id}),
    );
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedAppointments() async {
    final db = await database;
    return db.query('appointments', where: 'is_synced = 0');
  }

  static Future<void> markAppointmentSynced(String id) async {
    final db = await database;
    await db.update(
      'appointments',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> upsertAppointmentFromSync(
    Map<String, dynamic> row,
  ) async {
    final db = await database;
    final local = await db.query(
      'appointments',
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    if (local.isNotEmpty) {
      final localUpdatedAt = local.first['updated_at'] as String? ?? '';
      final remoteUpdatedAt = row['updated_at'] as String? ?? '';
      if (remoteUpdatedAt.compareTo(localUpdatedAt) < 0) return;
    }
    row['is_synced'] = 1;
    row['device_id'] = row['device_id'] ?? await DeviceService.getDeviceId();
    await db.insert(
      'appointments',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Bulk sync helpers ──

  static Future<List<Map<String, dynamic>>> getPatientsUpdatedSince(
    String since,
  ) async {
    final db = await database;
    return db.query('patients', where: 'updated_at > ?', whereArgs: [since]);
  }

  static Future<List<Map<String, dynamic>>> getAppointmentsUpdatedSince(
    String since,
  ) async {
    final db = await database;
    return db.query(
      'appointments',
      where: 'updated_at > ?',
      whereArgs: [since],
    );
  }

  static Future<Set<String>> getAllPatientIds() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT id FROM patients WHERE deleted_at IS NULL',
    );
    return rows.map((r) => r['id'] as String).toSet();
  }

  static Future<Set<String>> getAllAppointmentIds() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT id FROM appointments WHERE deleted_at IS NULL',
    );
    return rows.map((r) => r['id'] as String).toSet();
  }

  // ── Pending Orders ──

  static Future<void> insertPendingOrder(String id, String dataJson) async {
    final db = await database;
    await db.insert('pending_orders', {
      'id': id,
      'data': dataJson,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final db = await database;
    return db.query('pending_orders', orderBy: 'created_at ASC');
  }

  static Future<void> deletePendingOrder(String id) async {
    final db = await database;
    await db.delete('pending_orders', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> getPendingOrderCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM pending_orders',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Full export for in-memory lists ──

  static Future<List<Map<String, dynamic>>> exportAllPatients() async {
    final db = await database;
    return db.query('patients', where: 'deleted_at IS NULL');
  }

  static Future<List<Map<String, dynamic>>> exportAllAppointments() async {
    final db = await database;
    return db.query('appointments', where: 'deleted_at IS NULL');
  }

  static Future<void> clearAllLocalData() async {
    final db = await database;
    await db.delete('patients');
    await db.delete('appointments');
    await db.delete('pending_orders');
    await db.delete('sync_queue');
    await db.delete('result_records');
    await db.delete('result_uploads');
    await db.delete('metadata');
  }
}
