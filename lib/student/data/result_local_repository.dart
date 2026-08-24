import 'dart:convert';

import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/student/data/academic_result_api_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'result_models.dart';

class ResultLocalRepository {
  const ResultLocalRepository();

  static const AcademicResultApiService _api = AcademicResultApiService();

  Future<List<ResultUpload>> uploads() async {
    try {
      final remote = await _api.uploads();
      await _replaceLocalUploads(remote);
      return remote;
    } catch (_) {
      return _localUploads();
    }
  }

  Future<List<ResultUpload>> _localUploads() async {
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
    try {
      final remote = await _api.uploadRecords(uploadId);
      await _replaceLocalRecords(uploadId, remote);
      return remote;
    } catch (_) {
      return _localRecords(uploadId);
    }
  }

  Future<List<ResultRecord>> _localRecords(String uploadId) async {
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
    final saved = await _api.save(upload, records);
    await _saveLocal(saved, records);
  }

  Future<void> _saveLocal(
    ResultUpload upload,
    List<ResultRecord> records,
  ) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    await db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      await txn.insert('result_uploads', {
        'id': upload.id,
        'data': jsonEncode(upload.toJson()),
        'created_at': upload.uploadDate.toUtc().toIso8601String(),
        'sync_status': 'synced',
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
          'sync_status': 'synced',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> delete(String uploadId) async {
    await _api.delete(uploadId);
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    AppDatabase.ensureDataGeneration(generation);
    await db.delete('result_uploads', where: 'id = ?', whereArgs: [uploadId]);
  }

  Future<void> _replaceLocalUploads(List<ResultUpload> uploads) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    await db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      final existing = await txn.query('result_uploads', columns: ['id']);
      final existingIds = existing.map((row) => row['id']! as String).toSet();
      final remoteIds = uploads.map((upload) => upload.id).toSet();
      for (final row in existing) {
        final id = row['id']! as String;
        if (!remoteIds.contains(id)) {
          await txn.delete('result_uploads', where: 'id = ?', whereArgs: [id]);
        }
      }
      for (final upload in uploads) {
        final values = {
          'id': upload.id,
          'data': jsonEncode(upload.toJson()),
          'created_at': upload.uploadDate.toUtc().toIso8601String(),
          'sync_status': 'synced',
        };
        if (existingIds.contains(upload.id)) {
          await txn.update(
            'result_uploads',
            values,
            where: 'id = ?',
            whereArgs: [upload.id],
          );
        } else {
          await txn.insert('result_uploads', values);
        }
      }
    });
  }

  Future<void> _replaceLocalRecords(
    String uploadId,
    List<ResultRecord> records,
  ) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    await db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      await txn.delete(
        'result_records',
        where: 'upload_id = ?',
        whereArgs: [uploadId],
      );
      final batch = txn.batch();
      for (final record in records) {
        batch.insert('result_records', {
          'id': '$uploadId:${record.id}',
          'upload_id': uploadId,
          'exam_number': record.examNumber,
          'data': jsonEncode(record.toJson()),
          'created_at': record.uploadDate.toUtc().toIso8601String(),
          'sync_status': 'synced',
        });
      }
      await batch.commit(noResult: true);
    });
  }
}
