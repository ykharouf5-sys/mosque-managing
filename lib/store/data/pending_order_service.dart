import 'dart:convert';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/data/connectivity_service.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:flutter/foundation.dart';

class PendingOrderService {
  static bool _initialized = false;

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
  /// Returns: 'sent' (confirmed), 'pending' (local, will retry),
  ///          'insufficient_stock' (permanent failure).
  static Future<String> savePendingOrder(Map<String, dynamic> order) async {
    final id = order['id'] as String;
    final dataJson = jsonEncode(order);
    final generation = await AppDatabase.insertPendingOrder(id, dataJson);
    debugPrint('📝 Pending order saved locally: $id');
    if (!ConnectivityService.isOnline.value) return 'pending';
    return _sendAndCleanup(order, generation);
  }

  /// Retry all pending orders.
  static Future<void> retryPending() async {
    if (!ConnectivityService.isOnline.value || !AuthService().isLoggedIn) {
      return;
    }
    final generation = AppDatabase.captureActiveDataGeneration();
    final pending = await AppDatabase.getPendingOrders(
      expectedGeneration: generation,
    );
    if (pending.isEmpty) return;
    debugPrint('🔄 Retrying ${pending.length} pending orders...');
    for (final row in pending) {
      try {
        final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
        await _sendAndCleanup(data, generation);
      } catch (e) {
        debugPrint('⚠️ retryPending error for ${row['id']}: $e');
      }
    }
  }

  /// Send to Laravel through the idempotent order endpoint.
  /// Permanent failures (insufficient_stock) also delete the local row.
  static Future<String> _sendAndCleanup(
    Map<String, dynamic> order,
    int generation,
  ) async {
    final id = order['id'] as String;
    try {
      final row = StoreApiService.orderToRow(order);
      final result = await StoreApiService.createOrderSafe(row);
      switch (result) {
        case 'inserted':
        case 'exists':
          await AppDatabase.deletePendingOrder(
            id,
            expectedGeneration: generation,
          );
          debugPrint('✅ Pending order pushed: $id');
          return 'sent';
        case 'insufficient_stock':
          await AppDatabase.deletePendingOrder(
            id,
            expectedGeneration: generation,
          );
          debugPrint('❌ Insufficient stock for order: $id');
          return 'insufficient_stock';
        default:
          debugPrint('⏳ Pending order kept for retry: $id');
          return 'pending';
      }
    } catch (e) {
      debugPrint('⚠️ Failed to push order $id: $e');
      return 'pending';
    }
  }

  static void dispose() {
    ConnectivityService.isOnline.removeListener(_onConnectivityChanged);
  }
}
