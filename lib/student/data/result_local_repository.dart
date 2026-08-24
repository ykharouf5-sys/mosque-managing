import 'dart:convert';

import 'package:studentry/shared/data/app_database.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'result_models.dart';

class ResultLocalRepository {
  const ResultLocalRepository();

  Future<List<ResultUpload>> uploads() async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    final rows = await db.query('result_uploads', orderBy: 'created_at DESC');
    AppDatabase.ensureDataGeneration(generation);
    return rows
        .map(
          (row) => ResultUpload.fromJson(
            jsonDecode(row['data']! as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<ResultRecord>> records(String uploadId) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    final rows = await db.query(
      'result_records',
      where: 'upload_id = ?',
      whereArgs: [uploadId],
      orderBy: 'created_at, id',
    );
    AppDatabase.ensureDataGeneration(generation);
    return rows
        .map(
          (row) => ResultRecord.fromJson(
            jsonDecode(row['data']! as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> save(ResultUpload upload, List<ResultRecord> records) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    await db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      await txn.insert('result_uploads', {
        'id': upload.id,
        'data': jsonEncode(upload.toJson()),
        'created_at': upload.uploadDate.toUtc().toIso8601String(),
        'sync_status': 'pending',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final batch = txn.batch();
      for (final record in records) {
        final stored = ResultRecord(
          id: record.id,
          examNumber: record.examNumber,
          studentName: record.studentName,
          subjectName: record.subjectName,
          subjectCode: record.subjectCode,
          mark: record.mark,
          total: record.total,
          status: record.status,
          examSession: record.examSession,
          academicYear: record.academicYear,
          uploadDate: record.uploadDate,
          sourcePdfId: upload.id,
          notes: record.notes,
        );
        batch.insert('result_records', {
          'id': '${upload.id}:${record.id}',
          'upload_id': upload.id,
          'exam_number': record.examNumber,
          'data': jsonEncode(stored.toJson()),
          'created_at': record.uploadDate.toUtc().toIso8601String(),
          'sync_status': 'pending',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> delete(String uploadId) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    AppDatabase.ensureDataGeneration(generation);
    await db.delete('result_uploads', where: 'id = ?', whereArgs: [uploadId]);
  }
}
