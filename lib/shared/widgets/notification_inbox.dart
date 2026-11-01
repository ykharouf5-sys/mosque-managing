import 'dart:async';
import 'package:flutter/material.dart';
import '../data/auth_service.dart';
import '../data/notification_inbox_service.dart';
import '../data/fcm_token_service.dart';
import '../../utils/app_locale.dart';

class NotificationInbox extends StatefulWidget {
  const NotificationInbox({super.key});
  @override
  State<NotificationInbox> createState() => _NotificationInboxState();
}

class _NotificationInboxState extends State<NotificationInbox> {
  int _page = 1;
  int _ticket = 0;
  NotificationPage? _data;
  bool _busy = false;
  String? _error;
  StreamSubscription<void>? _subscription;
  @override
  void initState() {
    super.initState();
    _subscription = FcmTokenService.inboxChanges.listen(
      (_) => _load(force: true),
    );
    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final ticket = ++_ticket;
    final generation = AuthService().sessionGeneration;
    bool current() =>
        mounted &&
        ticket == _ticket &&
        generation == AuthService().sessionGeneration;
    setState(() {
      _busy = true;
      _error = null;
    });
    final cached = await NotificationInboxService.cached(_page);
    if (!current()) return;
    if (cached != null) setState(() => _data = cached);
    try {
      final result = await NotificationInboxService.page(_page, force: force);
      if (current()) setState(() => _data = result);
    } catch (_) {
      if (current()) {
        setState(
          () => _error = AppLocale.text(
            'تعذر تحديث الإشعارات',
            'Could not refresh notifications',
          ),
        );
      }
    } finally {
      if (current()) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              AppLocale.text('الإشعارات السابقة', 'Previous notifications'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: _busy ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (_busy && _data == null) const LinearProgressIndicator(),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (_data != null && _data!.rows.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            AppLocale.text(
              'لا توجد إشعارات سابقة',
              'No previous notifications',
            ),
          ),
        ),
      for (final row in _data?.rows ?? <Map<String, dynamic>>[])
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['title']?.toString() ?? '',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(row['body']?.toString() ?? ''),
                const SizedBox(height: 6),
                Text(
                  (row['scheduled_at']?.toString() ?? '').split('T').first,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _busy || _page == 1
                ? null
                : () {
                    setState(() {
                      _page--;
                      _data = null;
                    });
                    _load();
                  },
            child: Text(AppLocale.text('السابق', 'Previous')),
          ),
          Text('$_page'),
          TextButton(
            onPressed: _busy || !(_data?.hasMore ?? false)
                ? null
                : () {
                    setState(() {
                      _page++;
                      _data = null;
                    });
                    _load();
                  },
            child: Text(AppLocale.text('التالي', 'Next')),
          ),
        ],
      ),
    ],
  );
}
