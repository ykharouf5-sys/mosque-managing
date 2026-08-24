import 'dart:async';
import 'package:dentalcare/shared/data/auth_service.dart';

import 'package:dentalcare/shared/data/connectivity_service.dart';
import 'package:dentalcare/store/data/store_models.dart';
import 'package:dentalcare/store/data/store_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef NewOrdersCallback = void Function(List<Order> orders);

class StorePollingService {
  static Timer? _timer;
  static const String _lastCheckKey = 'store_orders_last_check';
  static const Duration _pollInterval = Duration(seconds: 60);
  static NewOrdersCallback? _onNewOrders;
  static final List<Order> _pendingOrders = [];

  static NewOrdersCallback? get onNewOrders => _onNewOrders;

  static set onNewOrders(NewOrdersCallback? cb) {
    _onNewOrders = cb;
    if (_pendingOrders.isNotEmpty) {
      _onNewOrders!(List.from(_pendingOrders));
      _pendingOrders.clear();
    }
  }

  static Future<void> init() async {
    final role = AuthService().role;
    if (role != 'warehouse_manager' && role != 'sales_manager') {
      debugPrint('⏸ StorePolling — not a manager role, skipping');
      return;
    }
    _pollNow();
    _timer = Timer.periodic(_pollInterval, (_) {
      if (ConnectivityService.isOnline.value) {
        _pollNow();
      }
    });
    debugPrint('📡 StorePolling started every 60s for ${AuthService().role}');
  }

  static Future<void> _pollNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck =
          prefs.getString(_lastCheckKey) ?? '1970-01-01T00:00:00.000';

      final rows = await StoreApiService.fetchOrdersSince(lastCheck);
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

      if (_onNewOrders != null) {
        _onNewOrders!(newOrders);
      } else {
        _pendingOrders.addAll(newOrders);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(_lastCheckKey, now);
    } catch (e) {
      debugPrint('⚠️ StorePolling error: $e');
    }
  }

  static void dispose() {
    _timer?.cancel();
  }
}
