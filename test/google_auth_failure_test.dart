import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:studentry/shared/data/google_auth_failure.dart';
import 'package:studentry/shared/data/api_request_queue.dart';

void main() {
  test('modern provider configuration errors are not blamed on Laravel', () {
    final message = googleSignInFailureMessage(
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description:
            'This android application is not registered to use OAuth2.0',
      ),
    );
    expect(message, contains('غير متاح لهذا الإصدار'));
    expect(message, isNot(contains('Laravel')));
  });
  test('ambiguous Android canceled results remain visible', () {
    expect(
      googleSignInFailureMessage(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      ),
      contains('لم يكتمل'),
    );
  });
  test('sensitive exception details never enter UI messages', () {
    const marker = 'private-id-token-and-email@example.test';
    for (final error in <Object>[
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: marker,
        details: marker,
      ),
      const ApiException(401, marker, {'id_token': marker}),
      const ApiException(503, marker),
      StateError(marker),
    ]) {
      expect(googleSignInFailureMessage(error), isNot(contains(marker)));
    }
  });
}
