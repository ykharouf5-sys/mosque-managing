class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static void validateForRelease({
    required bool isRelease,
    String url = baseUrl,
  }) {
    if (!isRelease) return;

    final uri = Uri.tryParse(url);
    final isLocalHost =
        uri == null ||
        uri.host.isEmpty ||
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2';
    if (uri?.scheme != 'https' || isLocalHost) {
      throw StateError(
        'Release builds require a public HTTPS API_BASE_URL. '
        'Build with --dart-define=API_BASE_URL=https://api.example.com/api/v1',
      );
    }
  }

  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration catalogRefreshInterval = Duration(hours: 2);
  static const int maxConcurrentRequests = 3;
}
