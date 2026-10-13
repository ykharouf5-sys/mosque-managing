import 'dart:convert';
import 'dart:async';
import 'order_submission_result.dart';
import 'order_retry_policy.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/data/connectivity_service.dart';
import 'package:studentry/store/data/store_api_service.dart';

class PendingOrderService {
  static bool _initialized = false;
  static Future<void>? _retrying;
  static Timer? _retryTimer;
  static DateTime? _scheduledFor;
  static final Map<String, Future<OrderSubmissionResult>> _sending = {};
  static final _updates = StreamController<void>.broadcast();
  static Stream<void> get updates => _updates.stream;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    ConnectivityService.isOnline.addListener(_onConnectivityChanged);
    await retryPending();
  }

  static void _onConnectivityChanged() {
    if (ConnectivityService.isOnline.value) {
      retryPending();
    }
  }

  /// Save order locally first, then send it through REST.
  /// Returns the server-confirmed order, a queued result, or a retained failure.
  static Future<OrderSubmissionResult> savePendingOrder(
    Map<String, dynamic> order,
  ) async {
    final id = order['id'] as String;
    final dataJson = jsonEncode(order);
    final generation = await AppDatabase.insertPendingOrder(id, dataJson);
    if (!ConnectivityService.isOnline.value) {
      return const OrderSubmissionResult('pending');
    }
    return _sendAndCleanup(order, generation);
  }

  /// Retry all pending orders.
  static Future<void> retryPending() {
    final active = _retrying;
    if (active != null) return active;
    late final Future<void> request;
    request = _retryPending().whenComplete(() {
      if (identical(_retrying, request)) _retrying = null;
    });
    _retrying = request;
    return request;
  }

  static Future<void> _retryPending() async {
    if (!ConnectivityService.isOnline.value || !AuthService().isLoggedIn) {
      return;
    }
    final generation = AppDatabase.captureActiveDataGeneration();
    final pending = await AppDatabase.getPendingOrders(
      expectedGeneration: generation,
    );
    if (pending.isEmpty) return;
    DateTime? earliest;
    for (final row in pending) {
      try {
        final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
        if (data['submissionError'] != null) continue;
        final due = OrderRetryPolicy.due(data);
        if (due != null && due.isAfter(DateTime.now())) {
          if (earliest == null || due.isBefore(earliest)) earliest = due;
          continue;
        }
        final result = await _sendAndCleanup(data, generation);
        if (!result.isConfirmed && !result.isPermanentFailure) {
          // Read the persisted due time on the next pass.
          final next = DateTime.now().add(
            result.retryAfter ?? const Duration(seconds: 5),
          );
          if (earliest == null || next.isBefore(earliest)) earliest = next;
        }
      } catch (_) {}
    }
    if (earliest != null) _schedule(earliest);
  }

  static void _schedule(DateTime due) {
    if (!_initialized) return;
    if (_retryTimer?.isActive == true &&
        _scheduledFor != null &&
        !_scheduledFor!.isAfter(due)) {
      return;
    }
    _retryTimer?.cancel();
    _scheduledFor = due;
    final delay = due.difference(DateTime.now());
    _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      _scheduledFor = null;
      unawaited(retryPending().catchError((Object _) {}));
    });
  }

  /// Send to Laravel through the idempotent order endpoint.
  /// Permanent failures remain visible locally and are not retried silently.
  static Future<OrderSubmissionResult> _sendAndCleanup(
    Map<String, dynamic> order,
    int generation,
  ) {
    final key = '$generation:${order['id']}';
    final active = _sending[key];
    if (active != null) return active;
    late final Future<OrderSubmissionResult> request;
    request = _sendOnce(order, generation).whenComplete(() {
      if (identical(_sending[key], request)) _sending.remove(key);
    });
    _sending[key] = request;
    return request;
  }

  static Future<OrderSubmissionResult> _defer(
    Map<String, dynamic> order,
    int generation,
    Duration? retryAfter,
  ) async {
    final attempt = (order['_retryCount'] as num?)?.toInt() ?? 0;
    final delay = OrderRetryPolicy.delay(attempt, retryAfter: retryAfter);
    final due = DateTime.now().toUtc().add(delay);
    await AppDatabase.updatePendingOrderData(
      order['id'] as String,
      jsonEncode({
        ...order,
        '_retryCount': attempt + 1,
        '_nextRetryAt': due.toIso8601String(),
      }),
      expectedGeneration: generation,
    );
    _schedule(due);
    return OrderSubmissionResult('pending', retryAfter: delay);
  }

  static Future<OrderSubmissionResult> _sendOnce(
    Map<String, dynamic> order,
    int generation,
  ) async {
    final id = order['id'] as String;
    try {
      AppDatabase.ensureDataGeneration(generation);
      final row = StoreApiService.orderToRow(order);
      final result = await StoreApiService.createOrderSafe(row);
      switch (result.status) {
        case 'inserted':
        case 'exists':
          await AppDatabase.deletePendingOrder(
            id,
            expectedGeneration: generation,
          );
          _updates.add(null);
          return result;
        case 'insufficient_stock':
        case 'invalid_order':
        case 'payment_failed':
        case 'forbidden':
          await AppDatabase.updatePendingOrderData(
            id,
            jsonEncode({
              ...order,
              'submissionError': result.status,
              'awaitingSync': false,
            }),
            expectedGeneration: generation,
          );
          _updates.add(null);
          return result;
        default:
          return _defer(order, generation, result.retryAfter);
      }
    } catch (_) {
      return _defer(order, generation, null);
    }
  }

  static void dispose() {
    ConnectivityService.isOnline.removeListener(_onConnectivityChanged);
    _initialized = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _scheduledFor = null;
  }
}
