import 'package:studentry/shared/data/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiConfig release validation', () {
    test('allows local endpoints outside release mode', () {
      expect(
        () => ApiConfig.validateForRelease(
          isRelease: false,
          url: 'http://10.0.2.2:8000/api/v1',
        ),
        returnsNormally,
      );
    });

    for (final url in [
      'http://10.0.2.2:8000/api/v1',
      'http://localhost/api/v1',
      'https://127.0.0.1/api/v1',
      'not-a-url',
    ]) {
      test('rejects $url in release mode', () {
        expect(
          () => ApiConfig.validateForRelease(isRelease: true, url: url),
          throwsStateError,
        );
      });
    }

    test('accepts a public HTTPS endpoint in release mode', () {
      expect(
        () => ApiConfig.validateForRelease(
          isRelease: true,
          url: 'https://api.studentry.example/api/v1',
        ),
        returnsNormally,
      );
    });
  });
}
