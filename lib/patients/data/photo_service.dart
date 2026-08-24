import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PhotoService {
  static Future<String> saveLocally(String patientId, String sourcePath) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(patientId)) {
      throw const FormatException('Invalid patient identifier.');
    }
    final dir = await getApplicationDocumentsDirectory();
    final patientDir = Directory('${dir.path}/patients/$patientId');
    if (!await patientDir.exists()) {
      await patientDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = sourcePath.split('.').last;
    final destPath = '${patientDir.path}/$timestamp.$ext';
    final file = File(sourcePath);
    await file.copy(destPath);
    return destPath;
  }

  static Future<void> clearAllLocalPhotos() async {
    final documents = await getApplicationDocumentsDirectory();
    final photosDirectory = Directory('${documents.path}/patients');
    if (await photosDirectory.exists()) {
      await photosDirectory.delete(recursive: true);
    }
  }
}
