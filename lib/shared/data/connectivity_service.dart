import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'sync_service.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static bool _wasOffline = false;

  static void init() {
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (isOnline.value != online) {
        isOnline.value = online;
        debugPrint('Connectivity changed: ${online ? "ONLINE" : "OFFLINE"}');
        if (online && _wasOffline) {
          _onConnectionRestored();
        }
        _wasOffline = !online;
      }
    });
  }

  static void _onConnectionRestored() async {
    final jitter = Random().nextInt(30);
    debugPrint('🔁 Connection restored — sync in $jitter s (jitter)');
    await Future.delayed(Duration(seconds: jitter));
    await SyncService.syncNow();
  }

  static Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      isOnline.value = results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      isOnline.value = true;
    }
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
