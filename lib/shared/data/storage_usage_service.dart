import 'dart:io';
import 'storage_usage.dart';
import 'development_artifact_cleanup.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:studentry/shared/cache/cache_manager.dart';

class StorageUsageService {
  static Future<int> cleanupDevelopmentArtifacts() async {
    if (kDebugMode) return 0;
    return removeObsoleteDebugArtifacts(
      await getApplicationDocumentsDirectory(),
      compiledRuntime: true,
    );
  }

  static Future<StorageUsage> inspect() async {
    final documents = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    final temporary = await getTemporaryDirectory();
    final databases = await getDatabasesPath();
    // Android's app-private root includes SDK/no_backup and preferences, not
    // just files managed by our Dart code. Never inspect external user files.
    final roots = Platform.isAndroid
        ? [support.parent.path]
        : [documents.path, support.path, temporary.path, databases];
    final counts = await compute(_measureAppFiles, {
      'roots': roots,
      'documents': documents.path,
      'temporary': temporary.path,
      'databases': databases,
    });
    return StorageUsage(
      databases: counts[0],
      clinicalFiles: counts[1],
      preferences: counts[2] == 0
          ? CacheManager.instance.persistedBytes
          : counts[2],
      temporaryFiles: counts[3],
      otherFiles: counts[4],
    );
  }
}

List<int> _measureAppFiles(Map<String, dynamic> paths) {
  final totals = List.filled(5, 0);
  final visited = <String>{};
  for (final root in (paths['roots'] as List).cast<String>()) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final item in directory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (item is! File || !visited.add(item.path)) continue;
      try {
        final path = item.path.replaceAll('\\', '/');
        final databaseRoot = (paths['databases'] as String).replaceAll(
          '\\',
          '/',
        );
        final temporaryRoot = (paths['temporary'] as String).replaceAll(
          '\\',
          '/',
        );
        final category = path.startsWith('$databaseRoot/')
            ? 0
            : path.contains('/account_photos/') || path.contains('/patients/')
            ? 1
            : path.contains('/shared_prefs/')
            ? 2
            : path.startsWith('$temporaryRoot/') ||
                  path.contains('/code_cache/')
            ? 3
            : 4;
        totals[category] += item.lengthSync();
      } on FileSystemException {
        /* Files may disappear during inspection. */
      }
    }
  }
  return totals;
}
