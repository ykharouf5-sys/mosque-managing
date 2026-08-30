import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/shared/data/sync_service.dart';

void main() {
  group('sync failure policy', () {
    test('retries transport and temporary server failures', () {
      expect(
        SyncService.classifyFailure(Exception('offline')),
        SyncFailureDisposition.retry,
      );
      expect(
        SyncService.classifyFailure(const ApiException(503, 'unavailable')),
        SyncFailureDisposition.retry,
      );
      expect(
        SyncService.classifyFailure(const ApiException(429, 'busy')),
        SyncFailureDisposition.retry,
      );
    });

    test('keeps permanent validation failures for user review', () {
      expect(
        SyncService.classifyFailure(const ApiException(422, 'invalid data')),
        SyncFailureDisposition.permanentFailure,
      );
      expect(
        SyncService.classifyFailure(const ApiException(413, 'too large')),
        SyncFailureDisposition.permanentFailure,
      );
    });

    test('discards records that are no longer authorized or visible', () {
      expect(
        SyncService.classifyFailure(const ApiException(403, 'forbidden')),
        SyncFailureDisposition.discard,
      );
      expect(
        SyncService.classifyFailure(const ApiException(404, 'not found')),
        SyncFailureDisposition.discard,
      );
    });

    test('resolves optimistic concurrency conflicts from server state', () {
      expect(
        SyncService.classifyFailure(const ApiException(409, 'conflict')),
        SyncFailureDisposition.resolveConflict,
      );
    });

    test('rejects an expired or revoked authenticated session', () {
      expect(
        SyncService.classifyFailure(const ApiException(401, 'unauthorized')),
        SyncFailureDisposition.rejectSession,
      );
      expect(
        SyncService.classifyFailure(const ApiException(419, 'expired')),
        SyncFailureDisposition.rejectSession,
      );
    });
  });
}
