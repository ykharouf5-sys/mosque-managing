import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  bool _isOnline = true;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final dynamic result = await _connectivity.checkConnectivity();
    if (result is List<ConnectivityResult>) {
      _updateStatusFromList(result);
    } else if (result is ConnectivityResult) {
      _updateStatus(result);
    }
    final inTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (!inTest) {
      _connectivity.onConnectivityChanged.listen((dynamic event) {
        if (event is List<ConnectivityResult>) {
          _updateStatusFromList(event);
        } else if (event is ConnectivityResult) {
          _updateStatus(event);
        }
      });
    }
  }

  Stream<bool> get connectivityStream => _statusController.stream;

  Future<bool> get isOnline async {
    return _isOnline;
  }

  bool get isOnlineNow => _isOnline;

  DateTime? _lastCheckTime;
  bool? _lastCheckResult;

  /// Checks for actual internet access by pinging a reliable server.
  /// Uses caching to prevent spamming requests (valid for 5 seconds).
  Future<bool> checkRealConnectivity({Duration timeout = const Duration(seconds: 2)}) async {
    // 1. Check Cache (reduced to 5 seconds for faster message delivery)
    if (_lastCheckTime != null && _lastCheckResult != null) {
      if (DateTime.now().difference(_lastCheckTime!) < const Duration(seconds: 5)) {
        return _lastCheckResult!;
      }
    }

    // 2. Perform Network Check
    try {
      final request = await HttpClient().getUrl(Uri.parse('https://api.supabase.com')).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final result = response.statusCode >= 200 && response.statusCode < 500;
      
      // 3. Update Cache
      _lastCheckResult = result;
      _lastCheckTime = DateTime.now();
      
      // Update the stream status as well to keep UI in sync
      if (_isOnline != result) {
         _isOnline = result;
         _statusController.add(result);
      }
      
      return result;
    } catch (_) {
      _lastCheckResult = false;
      _lastCheckTime = DateTime.now();
      return false;
    }
  }

  void _updateStatus(ConnectivityResult result) {
    final online = result == ConnectivityResult.mobile || result == ConnectivityResult.wifi || result == ConnectivityResult.ethernet;
    _isOnline = online;
    _statusController.add(online);
  }

  void _updateStatusFromList(List<ConnectivityResult> results) {
    final online = results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet);
    _isOnline = online;
    _statusController.add(online);
  }

  void dispose() {
    _statusController.close();
  }
}