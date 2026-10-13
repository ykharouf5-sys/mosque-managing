import 'dart:convert';
import 'package:flutter/foundation.dart';

enum RequestReason {
  unspecified,
  navigation,
  automatic,
  manual,
  mutation,
  sync,
  notification,
}

enum RequestSource { network, cache, shared }

/// Explicit opt-in only. Never records a URL/query, token, id, body, error
/// message, patient data, or exact filter. At most 200 anonymous aggregate keys.
class RequestDiagnostics {
  static const enabled = bool.fromEnvironment('REQUEST_DIAGNOSTICS');
  static final Map<String, Map<String, int>> _counts = {};
  static const _safeRoutes = {
    '/store/catalog',
    '/store/products',
    '/orders',
    '/sync/pull',
    '/sync/push',
    '/academic/subjects',
    '/academic/enrollments',
  };

  static String routeGroup(String path) =>
      _safeRoutes.contains(path) ? path : '/other';

  static void record(
    String method,
    String path,
    RequestSource source,
    RequestReason reason, {
    int bytes = 0,
    int elapsedMs = 0,
    int? status,
  }) {
    if (!enabled) return;
    final group =
        '$method ${routeGroup(path)} ${reason.name} ${source.name} ${status ?? 0}';
    if (!_counts.containsKey(group) && _counts.length >= 200) return;
    final values = _counts.putIfAbsent(
      group,
      () => {'count': 0, 'bytes': 0, 'total_ms': 0},
    );
    values['count'] = values['count']! + 1;
    values['bytes'] = values['bytes']! + bytes;
    values['total_ms'] = values['total_ms']! + elapsedMs;
    // Aggregate only: useful with `adb logcat` even on a release build.
    debugPrint('[request-metrics] ${jsonEncode({'group': group, ...values})}');
  }
}
