import 'dart:io';

import 'package:studentry/shared/data/api_client.dart';

class AcademicDocumentService {
  const AcademicDocumentService();

  Future<String> uploadPdf(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    if (bytes.length > 20 * 1024 * 1024) {
      throw Exception('PDF file exceeds 20MB');
    }
    final response = await ApiClient.instance.upload(
      '/academic/documents',
      bytes,
      file.uri.pathSegments.last,
      fieldName: 'document',
    );
    return response.data['data']['url'].toString();
  }
}
