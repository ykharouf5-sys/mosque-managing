import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/request_diagnostics.dart';

void main() {
  test(
    'diagnostics are off by default and redact dynamic paths and queries',
    () {
      expect(RequestDiagnostics.enabled, isFalse);
      expect(RequestDiagnostics.routeGroup('/orders'), '/orders');
      expect(
        RequestDiagnostics.routeGroup('/patients/private-id/photos'),
        '/other',
      );
      expect(
        RequestDiagnostics.routeGroup('/auth/reset/private-token'),
        '/other',
      );
      expect(
        RequestDiagnostics.routeGroup('/orders?user_id=private'),
        '/other',
      );
    },
  );
}
