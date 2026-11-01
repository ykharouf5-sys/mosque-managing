import '../cache/account_snapshot_cache.dart';
import 'api_client.dart';
import 'auth_service.dart';

class NotificationPage {
  const NotificationPage(this.rows, this.hasMore);
  final List<Map<String, dynamic>> rows;
  final bool hasMore;
}

class NotificationInboxService {
  static final _flights = <String, Future<NotificationPage>>{};
  static int _revision = 0;
  static Future<void> received({
    String? id,
    String? title,
    String? body,
  }) async {
    _revision++;
    if (id == null || title == null) return;
    final generation = AuthService().sessionGeneration;
    final key = AccountSnapshotCache.key('notifications:1');
    final cached = await AccountSnapshotCache.load(key);
    final rows = <Map<String, dynamic>>[
      {
        'id': id,
        'title': title,
        'body': body ?? '',
        'scheduled_at': DateTime.now().toUtc().toIso8601String(),
      },
      for (final row in (cached?['data'] as List? ?? []).whereType<Map>())
        if (row['id'] != id) Map<String, dynamic>.from(row),
    ];
    await AccountSnapshotCache.save(key, {
      'data': rows.take(25).toList(),
      'current_page': 1,
      'last_page': cached?['last_page'] ?? 2,
    }, generation: generation);
  }

  static Future<NotificationPage?> cached(int page) async {
    final data = await AccountSnapshotCache.load(
      AccountSnapshotCache.key('notifications:$page'),
    );
    return data == null ? null : _parse(data);
  }

  static NotificationPage _parse(Map<String, dynamic> payload) =>
      NotificationPage(
        (payload['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        (payload['current_page'] as num) < (payload['last_page'] as num),
      );

  static Future<NotificationPage> page(int page, {bool force = false}) {
    final key = AccountSnapshotCache.key('notifications:$page');
    if (key == null) return Future.error(StateError('Sign in required'));
    final flight = _flights[key];
    if (flight != null) return flight;
    final generation = AuthService().sessionGeneration;
    late final Future<NotificationPage> request;
    request =
        (() async {
          final result = await ApiClient.instance.get(
            '/notifications',
            query: {'page': '$page', 'per_page': '25'},
            freshness: const Duration(seconds: 30),
            force: force,
            headers: {'X-Inbox-Revision': '$_revision'},
          );
          if (generation != AuthService().sessionGeneration) {
            throw StateError('Account changed');
          }
          final payload = Map<String, dynamic>.from(result.data['data'] as Map);
          final parsed = _parse(payload);
          // Cache at most 8 pages (200 notices), older history remains available via REST.
          if (page <= 8) {
            await AccountSnapshotCache.save(
              key,
              payload,
              generation: generation,
            );
          }
          return parsed;
        })().whenComplete(() {
          if (identical(_flights[key], request)) _flights.remove(key);
        });
    _flights[key] = request;
    return request;
  }
}
