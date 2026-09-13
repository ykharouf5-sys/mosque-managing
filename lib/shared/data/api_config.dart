class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// Explicit opt-in used only for release-signed builds installed on a
  /// physical device while testing against a server on the same LAN.
  static const bool allowInsecureLocalApi = bool.fromEnvironment(
    'ALLOW_INSECURE_LOCAL_API',
    defaultValue: false,
  );

  static void validateForRelease({
    required bool isRelease,
    String url = baseUrl,
    bool allowInsecureLocal = allowInsecureLocalApi,
  }) {
    if (!isRelease) return;

    final uri = Uri.tryParse(url);
    final isLocalHost =
        uri == null ||
        uri.host.isEmpty ||
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2';
    final isAllowedLanEndpoint =
        allowInsecureLocal &&
        uri?.scheme == 'http' &&
        uri != null &&
        _isPrivateIpv4(uri.host);
    if (isAllowedLanEndpoint) return;
    if (uri?.scheme != 'https' || isLocalHost) {
      throw StateError(
        'Release builds require a public HTTPS API_BASE_URL. '
        'Build with --dart-define=API_BASE_URL=https://api.studentry.app/api/v1',
      );
    }
  }

  static bool _isPrivateIpv4(String host) {
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return false;
    final values = parts.cast<int>();
    if (values.any((part) => part < 0 || part > 255)) return false;
    return values[0] == 10 ||
        (values[0] == 192 && values[1] == 168) ||
        (values[0] == 172 && values[1] >= 16 && values[1] <= 31);
  }

  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration catalogRefreshInterval = Duration(hours: 2);
  static const int maxConcurrentRequests = 3;
}
