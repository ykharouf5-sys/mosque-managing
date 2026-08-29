import 'dart:async';

/// Coalesces rapid search input into one action while still allowing an
/// explicit submit to run immediately.
class SearchDebouncer {
  SearchDebouncer({this.delay = const Duration(milliseconds: 500)});

  final Duration delay;
  Timer? _timer;

  void schedule(FutureOr<void> Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      action();
    });
  }

  void runNow(FutureOr<void> Function() action) {
    cancel();
    action();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
