import '../../patients/data/photo_service.dart';
import '../../patients/data/notification_service.dart';
import '../../patients/data/storage_service.dart';
import '../cache/cache_manager.dart';
import 'app_database.dart';

class AccountDataLifecycle {
  AccountDataLifecycle._();

  static Future<AccountActivationResult> activate({
    required String accountId,
    required int clinicalScopeVersion,
    bool forceClinicalReset = false,
  }) async {
    final result = await AppDatabase.activateAccount(
      accountId: accountId,
      clinicalScopeVersion: clinicalScopeVersion,
    );
    if (forceClinicalReset && !result.requiresClinicalPurge) {
      await AppDatabase.resetClinicalDataForResync();
    }
    if (forceClinicalReset || result.requiresClinicalPurge) {
      await _clearAncillaryClinicalData();
    }
    return result;
  }

  static Future<void> clearAllUserData() async {
    await AppDatabase.clearAllLocalData();
    await _clearAncillaryClinicalData();
  }

  static Future<void> _clearAncillaryClinicalData() async {
    await CacheManager.instance.invalidateAll();
    await PhotoService.clearAllLocalPhotos();
    await StorageService.clearLegacyClinicalData();
    try {
      await NotificationService.cancelAll();
    } catch (_) {
      // The database and files are already purged. A platform notification
      // plugin failure must not resurrect or expose those records in-app.
    }
  }
}
