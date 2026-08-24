import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:studentry/shared/data/app_database.dart';

class PhotoService {
  static Future<String> saveLocally(String patientId, String sourcePath) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(patientId)) {
      throw const FormatException('Invalid patient identifier.');
    }
    final accountId = AppDatabase.activeAccountId;
    final generation = AppDatabase.captureActiveDataGeneration();
    if (accountId == null || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(accountId)) {
      throw const FormatException('Invalid account identifier.');
    }
    final dir = await getApplicationDocumentsDirectory();
    final patientDir = Directory(
      '${dir.path}/account_photos/$accountId/patients/$patientId',
    );
    if (!await patientDir.exists()) {
      await patientDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rawExtension = sourcePath.split('.').last.toLowerCase();
    final ext = RegExp(r'^[a-z0-9]{1,10}$').hasMatch(rawExtension)
        ? rawExtension
        : 'jpg';
    final destPath = '${patientDir.path}/$timestamp.$ext';
    final file = File(sourcePath);
    await file.copy(destPath);
    try {
      AppDatabase.ensureDataGeneration(generation);
    } catch (_) {
      try {
        await File(destPath).delete();
      } catch (_) {}
      rethrow;
    }
    return destPath;
  }

  static Future<void> clearAllLocalPhotos() async {
    final documents = await getApplicationDocumentsDirectory();
    final photosDirectory = Directory('${documents.path}/patients');
    if (await photosDirectory.exists()) {
      await photosDirectory.delete(recursive: true);
    }
    final accountPhotosDirectory = Directory(
      '${documents.path}/account_photos',
    );
    if (await accountPhotosDirectory.exists()) {
      await accountPhotosDirectory.delete(recursive: true);
    }
  }
}
