import '../../patients/data/photo_service.dart';
import '../../patients/data/notification_service.dart';
import '../../patients/data/storage_service.dart';
import '../cache/cache_manager.dart';
import 'app_database.dart';
import 'api_config.dart';
import '../../store/data/cart_storage.dart';

class AccountDataLifecycle {
  AccountDataLifecycle._();

  static Future<AccountActivationResult> activate({
    required String accountId,
    required int clinicalScopeVersion,
    String? clinicId,
    String? previousClinicId,
    bool forceClinicalReset = false,
  }) async {
    final result = await AppDatabase.activateAccount(
      accountId: accountId,
      clinicalScopeVersion: clinicalScopeVersion,
      clinicId: clinicId,
      previousClinicId: previousClinicId,
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
    final accountId = AppDatabase.activeAccountId;
    try {
      if (accountId != null) {
        await CartStorage.save(
          CartStorage.key(ApiConfig.baseUrl, accountId),
          [],
        );
      }
    } finally {
      // A cart storage failure must never prevent deletion of clinical data.
      await AppDatabase.clearAllLocalData();
      if (accountId != null) await PhotoService.clearAccountPhotos(accountId);
      await _clearAncillaryClinicalData();
    }
  }

  /// Ends access to the active account without deleting its encrypted file.
  static Future<void> close() async {
    await AppDatabase.close();
    await _clearAncillaryClinicalData();
  }

  static Future<void> _clearAncillaryClinicalData() async {
    // Catalog/product data is public and identical for every account. Keep it
    // warm across sign-out while removing every account-scoped cache entry.
    CacheManager.instance.invalidateTags(const [
      CacheTags.patients,
      CacheTags.appointments,
      CacheTags.orders,
    ]);
    await StorageService.clearLegacyClinicalData();
    try {
      await NotificationService.cancelAll();
    } catch (_) {
      // The database and files are already purged. A platform notification
      // plugin failure must not resurrect or expose those records in-app.
    }
  }
}
