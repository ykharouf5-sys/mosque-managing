import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    show DefaultCacheManager;
import 'storage_usage_panel.dart';
import 'package:studentry/shared/data/storage_usage.dart';
import 'package:studentry/shared/cache/cache_manager.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/storage_usage_service.dart';
import 'package:studentry/utils/variable_colors.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});
  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  StorageUsage? _usage;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final usage = await StorageUsageService.inspect();
      if (mounted) {
        setState(() {
          _usage = usage;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر قياس التخزين. حاول مجدداً.');
    }
  }

  Future<void> _maintain({required bool compact}) async {
    setState(() => _busy = true);
    try {
      if (compact) {
        await AppDatabase.compactActiveDatabase();
      } else {
        // Only public downloaded image cache and expired/bounded snapshots.
        // Never delete clinical photos, databases, pending writes or favorites.
        await DefaultCacheManager().emptyCache();
        await CacheManager.instance.prune();
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              compact
                  ? 'تم ضغط قاعدة البيانات بدون حذف سجلات'
                  : 'تم تنظيف الصور المؤقتة والبيانات المنتهية',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إكمال التنظيف؛ بياناتك محفوظة. حاول مجدداً.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('التخزين')),
      body: _usage == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : TextButton(onPressed: _load, child: Text(_error!)),
            )
          : StorageUsagePanel(
              usage: _usage!,
              busy: _busy,
              onClean: () => _maintain(compact: false),
              onCompact: AppDatabase.activeAccountId == null
                  ? null
                  : () => _maintain(compact: true),
            ),
    ),
  );
}
