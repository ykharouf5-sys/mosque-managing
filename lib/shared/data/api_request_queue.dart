import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'api_config.dart';

class ApiRequestQueue {
  ApiRequestQueue._();
  static final instance = ApiRequestQueue._();
  final Queue<_QueuedRequest<dynamic>> _requests = Queue();
  int _running = 0;
  Future<T> add<T>(Future<T> Function() action, {int maxRetries = 3}) {
    final c = Completer<T>();
    _requests.add(_QueuedRequest<T>(action, c, maxRetries));
    _drain();
    return c.future;
  }

  void _drain() {
    while (_running < ApiConfig.maxConcurrentRequests && _requests.isNotEmpty) {
      final r = _requests.removeFirst();
      _running++;
      _run(r).whenComplete(() {
        _running--;
        _drain();
      });
    }
  }

  Future<void> _run(_QueuedRequest<dynamic> r) async {
    for (var attempt = 0; attempt <= r.maxRetries; attempt++) {
      try {
        r.completer.complete(await r.action());
        return;
      } catch (error, stack) {
        final retryable =
            error is ApiException &&
            (error.statusCode == 429 || error.statusCode >= 500);
        if (!retryable || attempt == r.maxRetries) {
          r.completer.completeError(error, stack);
          return;
        }
        final delay = min(8000, 300 * (1 << attempt)) + Random().nextInt(350);
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
    }
  }
}

class _QueuedRequest<T> {
  final Future<T> Function() action;
  final Completer<T> completer;
  final int maxRetries;
  _QueuedRequest(this.action, this.completer, this.maxRetries);
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Object? details;
  const ApiException(this.statusCode, this.message, [this.details]);
  @override
  String toString() => message;
}
