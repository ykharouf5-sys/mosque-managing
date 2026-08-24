import 'package:image_picker/image_picker.dart';
import 'package:studentry/shared/data/api_client.dart';

class PatientPhotoService {
  PatientPhotoService._();

  static const _maxBytes = 8 * 1024 * 1024;

  static Future<String> upload(String patientId, XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty || bytes.length > _maxBytes) {
      throw const FormatException('يجب ألا يتجاوز حجم الصورة 8 ميغابايت.');
    }
    final response = await ApiClient.instance.upload(
      '/patients/$patientId/photos',
      bytes,
      image.name,
    );
    final url = response.data['data']?['url']?.toString();
    if (url == null || !url.startsWith('http')) {
      throw const FormatException('لم يُرجع الخادم رابط صورة صالحاً.');
    }
    return url;
  }

  static Future<void> remove(String patientId, String url) async {
    await ApiClient.instance.post(
      '/patients/$patientId/photos/remove',
      body: {'url': url},
      maxRetries: 0,
    );
  }
}
