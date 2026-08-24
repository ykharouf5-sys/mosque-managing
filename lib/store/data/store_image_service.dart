import 'package:dentalcare/shared/data/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class StoreImageService {
  static const _maxUploadBytes = 2 * 1024 * 1024;
  static Future<String?> pickAndUpload({String kind = 'product'}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: kind == 'banner' ? 1920 : 1400,
      maxHeight: kind == 'banner' ? 1080 : 1400,
      imageQuality: kind == 'banner' ? 72 : 75,
    );
    return picked == null ? null : uploadFile(picked.path, kind: kind);
  }

  static Future<String?> uploadFile(
    String filePath, {
    String kind = 'product',
  }) async {
    try {
      final source = XFile(filePath);
      final bytes = await source.readAsBytes();
      if (bytes.length > _maxUploadBytes) {
        throw Exception('Compressed image exceeds 2MB');
      }
      final r = await ApiClient.instance.upload(
        '/store/images',
        bytes,
        source.name,
        fields: {'kind': kind},
      );
      return r.data['data']['url']?.toString();
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  static Future<List<String>> pickAndUploadMultiple({
    String kind = 'product',
  }) async {
    final images = await ImagePicker().pickMultiImage(
      imageQuality: kind == 'banner' ? 72 : 75,
      maxWidth: kind == 'banner' ? 1920 : 1400,
      maxHeight: kind == 'banner' ? 1080 : 1400,
    );
    final urls = <String>[];
    for (final image in images) {
      final url = await uploadFile(image.path, kind: kind);
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
