import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/data/app_database.dart';

void main() {
  test(
    'rejection of an old session cannot close or purge the current database',
    () async {
      final auth = AuthService();
      final session = auth.sessionGeneration;
      final dataGeneration = AppDatabase.dataGeneration;
      await auth.invalidateRejectedSession(expectedGeneration: session - 1);
      expect(auth.sessionGeneration, session);
      expect(AppDatabase.dataGeneration, dataGeneration);
    },
  );
}
