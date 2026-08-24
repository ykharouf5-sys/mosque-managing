import 'dart:async';
import 'package:studentry/shared/data/auth_service.dart';

import 'package:studentry/shared/data/connectivity_service.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef NewOrdersCallback = void Function(List<Order> orders);

class StorePollingService {
  static Timer? _timer;
  static const String _lastCheckKeyPrefix = 'store_orders_last_check';
  static const Duration _pollInterval = Duration(seconds: 60);
  static NewOrdersCallback? _onNewOrders;
  static final List<Order> _pendingOrders = [];
  static int _generation = 0;
  static int? _pollingGeneration;
  static String? _accountId;
  static String? _clinicId;

  static NewOrdersCallback? get onNewOrders => _onNewOrders;

  static set onNewOrders(NewOrdersCallback? cb) {
    _onNewOrders = cb;
    if (cb != null && _pendingOrders.isNotEmpty) {
      cb(List.from(_pendingOrders));
      _pendingOrders.clear();
    }
  }

  static Future<void> init() => rebindToCurrentSession();

  static Future<void> rebindToCurrentSession() async {
    final generation = ++_generation;
    _timer?.cancel();
    _timer = null;
    _onNewOrders = null;
    _pendingOrders.clear();
    _accountId = null;
    _clinicId = null;

    final auth = AuthService();
    final role = auth.role;
    final accountId = auth.userId;
    final clinicId = auth.clinicId;
    if ((role != 'warehouse_manager' && role != 'sales_manager') ||
        accountId == null ||
        clinicId == null) {
      debugPrint('⏸ StorePolling — not a manager role, skipping');
      return;
    }
    _accountId = accountId;
    _clinicId = clinicId;
    await _pollNow(generation, accountId, clinicId);
    if (!_isCurrent(generation, accountId, clinicId)) return;
    _timer = Timer.periodic(_pollInterval, (_) {
      if (ConnectivityService.isOnline.value) {
        _pollNow(generation, accountId, clinicId);
      }
    });
    debugPrint('📡 StorePolling started every 60s for $role');
  }

  static Future<void> _pollNow(
    int generation,
    String accountId,
    String clinicId,
  ) async {
    if (!_isCurrent(generation, accountId, clinicId) ||
        _pollingGeneration == generation) {
      return;
    }
    _pollingGeneration = generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckKey = '$_lastCheckKeyPrefix:$accountId:$clinicId';
      final lastCheck =
          prefs.getString(lastCheckKey) ?? '1970-01-01T00:00:00.000';

      final rows = await StoreApiService.fetchOrdersSince(lastCheck);
      if (!_isCurrent(generation, accountId, clinicId)) return;
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
            status: OrderStatus.values.firstWhere(
              (s) => s.name == statusStr,
              orElse: () => OrderStatus.pending,
            ),
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

      if (!_isCurrent(generation, accountId, clinicId)) return;
      if (_onNewOrders != null) {
        _onNewOrders!(newOrders);
      } else {
        _pendingOrders.addAll(newOrders);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      if (_isCurrent(generation, accountId, clinicId)) {
        await prefs.setString(lastCheckKey, now);
      }
    } catch (e) {
      debugPrint('⚠️ StorePolling error: $e');
    } finally {
      if (_pollingGeneration == generation) _pollingGeneration = null;
    }
  }

  static bool _isCurrent(int generation, String accountId, String clinicId) =>
      generation == _generation &&
      _accountId == accountId &&
      _clinicId == clinicId &&
      AuthService().userId == accountId &&
      AuthService().clinicId == clinicId;

  static void dispose() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _onNewOrders = null;
    _pendingOrders.clear();
    _accountId = null;
    _clinicId = null;
  }
}
