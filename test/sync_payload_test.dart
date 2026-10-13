import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/sync_payload.dart';

void main() {
  test(
    'old acknowledged CAS receipts advance the exact immutable base version',
    () {
      expect(
        clinicalAcknowledgedVersion(
          operation: 'update',
          payload: {'version': 7},
          receipt: {'status': 'accepted'},
        ),
        8,
      );
      expect(
        clinicalAcknowledgedVersion(
          operation: 'insert',
          payload: {'version': 1},
          receipt: {'status': 'accepted'},
        ),
        1,
      );
      expect(
        clinicalAcknowledgedVersion(
          operation: 'update',
          payload: {'version': 7},
          receipt: {'status': 'accepted', 'version': 8},
        ),
        8,
      );
      expect(
        () => clinicalAcknowledgedVersion(
          operation: 'update',
          payload: {},
          receipt: {'status': 'accepted'},
        ),
        throwsStateError,
      );
      expect(
        () => clinicalAcknowledgedVersion(
          operation: 'update',
          payload: {'version': 7},
          receipt: {'status': 'rejected'},
        ),
        throwsStateError,
      );
    },
  );
  test('new patient bypasses batch so REST creation precedes dependents', () {
    expect(
      canBatchClinicalOperations([
        (tableName: 'patients', operation: 'insert'),
        (tableName: 'appointments', operation: 'insert'),
        (tableName: 'patient_payments', operation: 'insert'),
      ]),
      isFalse,
    );
    expect(
      canBatchClinicalOperations([
        (tableName: 'patients', operation: 'update'),
        (tableName: 'appointments', operation: 'insert'),
      ]),
      isFalse,
    );
    expect(
      canBatchClinicalOperations([
        (tableName: 'appointments', operation: 'update'),
      ]),
      isTrue,
    );
  });
  test('SQLite patient JSON columns are restored before REST upload', () {
    final payload = decodeSyncPayload(r'''
      {"name":"Ahmad","treatmentPlan":"[{\"procedureName\":\"Filling\"}]","photos":"[\"local.jpg\"]"}
    ''');

    expect(payload['treatmentPlan'], isA<List<dynamic>>());
    expect(payload['treatmentPlan'][0]['procedureName'], 'Filling');
    expect(payload['photos'], ['local.jpg']);
  });

  test('SQLite appointment flags are restored as REST booleans', () {
    final payload = decodeSyncPayload(
      '{"reminderSent":1,"notificationSent":0}',
    );

    expect(payload['reminderSent'], isTrue);
    expect(payload['notificationSent'], isFalse);
  });
}
