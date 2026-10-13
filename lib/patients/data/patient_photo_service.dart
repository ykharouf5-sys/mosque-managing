import 'package:image_picker/image_picker.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/shared/data/sync_service.dart';

class PatientPhotoService {
  PatientPhotoService._();

  static const _maxBytes = 8 * 1024 * 1024;

  static Future<String> upload(String patientId, XFile image) async {
    final session = ApiClient.instance.sessionGenerationProvider?.call();
    void ensureSession() {
      if (session != ApiClient.instance.sessionGenerationProvider?.call()) {
        throw const StaleSessionException();
      }
    }

    final bytes = await image.readAsBytes();
    ensureSession();
    if (bytes.isEmpty || bytes.length > _maxBytes) {
      throw const FormatException('يجب ألا يتجاوز حجم الصورة 8 ميغابايت.');
    }
    Future<ApiResult> send() {
      ensureSession();
      return ApiClient.instance.upload(
        '/patients/$patientId/photos',
        bytes,
        image.name,
      );
    }

    late final ApiResult response;
    try {
      response = await send();
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      // A newly created patient can still be waiting in the offline sync queue.
      await SyncService.syncNow(force: true, pullChanges: false);
      response = await send();
    }
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
