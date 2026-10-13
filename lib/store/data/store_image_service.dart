import 'package:studentry/shared/data/api_client.dart';
import 'package:image_picker/image_picker.dart';

class StoreImageService {
  static const _maxUploadBytes = 8 * 1024 * 1024;
  static Future<String?> pickAndUpload({String kind = 'product'}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: kind == 'category' ? 512 : (kind == 'banner' ? 1920 : 1400),
      maxHeight: kind == 'category' ? 512 : (kind == 'banner' ? 1080 : 1400),
      imageQuality: kind == 'banner' ? 72 : 75,
    );
    return picked == null ? null : uploadFile(picked.path, kind: kind);
  }

  static Future<String?> uploadFile(
    String filePath, {
    String kind = 'product',
  }) async {
    final source = XFile(filePath);
    final bytes = await source.readAsBytes();
    if (bytes.length > _maxUploadBytes) {
      throw Exception('حجم الصورة بعد الضغط يتجاوز 8 ميغابايت');
    }
    final r = await ApiClient.instance.upload(
      '/store/images',
      bytes,
      source.name,
      fields: {'kind': kind},
    );
    final url = r.data['data']['url']?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('لم يعُد الخادم برابط الصورة');
    }
    return url;
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
