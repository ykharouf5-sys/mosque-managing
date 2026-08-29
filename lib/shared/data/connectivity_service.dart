import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  static void init() {
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (isOnline.value != online) {
        isOnline.value = online;
      }
    });
  }

  static Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      isOnline.value = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      isOnline.value = true;
    }
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
