import 'dart:async';
import 'clinical_sync_policy.dart';

class ClinicalSyncFlight {
  ClinicalSyncFlight({required this.key, required this.pullRequested});
  final String key;
  bool pullRequested;
  bool pulling = false;
  late Future<bool> result;
}

/// Single-flight ownership belongs to a frozen context, never to a global
/// session. Finishing an old context cannot release the new context's flight.
class ClinicalSyncCoordinator<T extends ClinicalSyncFlight> {
  ClinicalSyncCoordinator(this.policy);
  final ClinicalSyncPolicy policy;
  T? active;

  Future<bool> request({
    required String key,
    required T Function(bool pull) create,
    required Future<bool> Function(T flight) execute,
    required Future<void> Function(T flight) onFinished,
    bool pullChanges = true,
    bool manual = false,
    bool force = false,
  }) {
    policy.bind(key);
    final running = active;
    if (running != null && running.key == key) {
      if (manual && (running.pullRequested || running.pulling)) {
        policy.allowPull(key, manual: true);
      }
      if (pullChanges &&
          !running.pullRequested &&
          !running.pulling &&
          policy.allowPull(key, manual: manual, force: force)) {
        running.pullRequested = true;
      }
      return running.result;
    }
    final flight = create(
      pullChanges && policy.allowPull(key, manual: manual, force: force),
    );
    final completer = Completer<bool>();
    flight.result = completer.future;
    active = flight;
    unawaited(
      Future<bool>.sync(() => execute(flight))
          .whenComplete(() async {
            if (identical(active, flight)) active = null;
            await onFinished(flight);
          })
          .then(completer.complete, onError: completer.completeError),
    );
    return flight.result;
  }

  void clear() {
    active = null;
    policy.clear();
  }
}
