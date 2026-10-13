import 'dart:async';
import 'dart:math';
import 'package:studentry/shared/data/auth_service.dart';

import 'package:studentry/shared/data/connectivity_service.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef NewOrdersCallback = void Function(List<Order> orders);

class StorePollingService {
  static Timer? _timer;
  static const String _lastCheckKeyPrefix = 'store_orders_last_check';
  static const Duration _pollInterval = Duration(minutes: 2);
  static const Duration _pollJitter = Duration(seconds: 30);
  static final Random _random = Random();
  static NewOrdersCallback? _onNewOrders;
  static final List<Order> _pendingOrders = [];
  static int _generation = 0;
  static int? _pollingGeneration;
  static String? _accountId;
  static bool _isAppActive = true;
  static DateTime? _lastPollAt;
  static int? _lastPolledGeneration;

  static NewOrdersCallback? get onNewOrders => _onNewOrders;

  static set onNewOrders(NewOrdersCallback? cb) {
    _onNewOrders = cb;
    if (cb != null && _pendingOrders.isNotEmpty) {
      cb(List.from(_pendingOrders));
      _pendingOrders.clear();
    }
  }

  static Future<void> init() => rebindToCurrentSession();

  static void setAppActive(bool active) {
    if (_isAppActive == active) return;
    _isAppActive = active;
    if (!active) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (active && ConnectivityService.isOnline.value && _accountId != null) {
      _pollNow(_generation, _accountId!);
      _scheduleNextPoll(_generation, _accountId!);
    }
  }

  static Future<void> rebindToCurrentSession() async {
    final generation = ++_generation;
    _timer?.cancel();
    _timer = null;
    _onNewOrders = null;
    _pendingOrders.clear();
    _accountId = null;

    final auth = AuthService();
    final role = auth.role;
    final accountId = auth.userId;
    // Store orders belong to the account and are not clinical data. A sales
    // or warehouse manager must keep receiving order updates without a clinic.
    if ((role != 'warehouse_manager' && role != 'sales_manager') ||
        accountId == null) {
      return;
    }
    _accountId = accountId;
    if (_isAppActive) await _pollNow(generation, accountId);
    if (!_isAppActive || !_isCurrent(generation, accountId)) return;
    _scheduleNextPoll(generation, accountId);
  }

  static void _scheduleNextPoll(int generation, String accountId) {
    if (!_isAppActive || !_isCurrent(generation, accountId)) return;
    _timer?.cancel();
    final delay =
        _pollInterval -
        _pollJitter +
        Duration(
          milliseconds: _random.nextInt(_pollJitter.inMilliseconds * 2 + 1),
        );
    _timer = Timer(delay, () async {
      if (_isAppActive && ConnectivityService.isOnline.value) {
        await _pollNow(generation, accountId);
      }
      _scheduleNextPoll(generation, accountId);
    });
  }

  static Future<void> _pollNow(int generation, String accountId) async {
    if (!_isAppActive ||
        !ConnectivityService.isOnline.value ||
        !_isCurrent(generation, accountId) ||
        _pollingGeneration == generation) {
      return;
    }
    if (_lastPolledGeneration == generation &&
        _lastPollAt != null &&
        DateTime.now().difference(_lastPollAt!) < const Duration(seconds: 30)) {
      return;
    }
    _pollingGeneration = generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckKey = '$_lastCheckKeyPrefix:$accountId';
      final lastCheck =
          prefs.getString(lastCheckKey) ?? '1970-01-01T00:00:00.000';
      final requestStartedAt = DateTime.now().toUtc().toIso8601String();

      final rows = await StoreApiService.fetchOrdersSince(lastCheck);
      if (!_isCurrent(generation, accountId)) return;
      _lastPollAt = DateTime.now();
      _lastPolledGeneration = generation;
      await prefs.setString(lastCheckKey, requestStartedAt);
      if (rows.isEmpty) return;

      final newOrders = <Order>[];

      for (final row in rows) {
        final map = StoreApiService.rowToOrderMap(row);
        final statusStr = map['status'] as String? ?? 'pending';
        final itemsData = map['items'] as List? ?? [];
        final items = itemsData
            .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
            .toList();

        newOrders.add(
          Order(
            id: map['id'] as String,
            items: items,
            totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0,
            status: orderStatusFromWire(statusStr),
            createdAt: DateTime.parse(map['createdAt'] as String),
            updatedAt: DateTime.parse(map['updatedAt'] as String),
            userId: map['userId'] as String? ?? '',
            notes: map['notes'] as String?,
            couponCode: map['couponCode'] as String?,
            discountAmount: (map['discountAmount'] as num?)?.toDouble(),
            shippingAddress: map['shippingAddress'] as String?,
            managerApproved: map['managerApproved'] as bool? ?? false,
            approvedAt: map['approvedAt'] != null
                ? DateTime.tryParse(map['approvedAt'] as String)
                : null,
            doctorName: map['doctorName'] as String?,
            doctorPhone: map['doctorPhone'] as String?,
            clinicAddress: map['clinicAddress'] as String?,
            doctorGovernorate: map['doctorGovernorate'] as String?,
            paymentMethod: map['paymentMethod'] as String?,
            deliveryPrice: (map['deliveryPrice'] as num?)?.toDouble() ?? 0,
            phone: map['phone'] as String?,
            governorate: map['governorate'] as String?,
            region: map['region'] as String?,
          ),
        );
      }

      if (!_isCurrent(generation, accountId)) return;
      if (_onNewOrders != null) {
        _onNewOrders!(newOrders);
      } else {
        _pendingOrders.addAll(newOrders);
      }
    } catch (_) {
    } finally {
      if (_pollingGeneration == generation) _pollingGeneration = null;
    }
  }

  static bool _isCurrent(int generation, String accountId) =>
      generation == _generation &&
      _accountId == accountId &&
      AuthService().userId == accountId &&
      AuthService().isLoggedIn;

  static void dispose() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _onNewOrders = null;
    _pendingOrders.clear();
    _accountId = null;
  }
}
