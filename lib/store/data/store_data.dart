import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/shared/cache/cache_manager.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:uuid/uuid.dart';

// ── Global in-memory lists ──
List<PromoBanner> storeBanners = [];
List<ProductCategory> storeCategories = [];
List<Product> storeProducts = [];
List<Coupon> storeCoupons = [];

const _categoriesCacheKey = 'store:catalog:categories';
const _bannersCacheKey = 'store:catalog:banners';
const _catalogCacheTtl = Duration(days: 30);

/// Restores the last server catalog before any network request is made.
/// A first-time installation stays empty until a real response arrives.
bool loadStoreSnapshot() {
  final cachedCategories = CacheManager.instance.get<List<dynamic>>(
    _categoriesCacheKey,
  );
  final cachedBanners = CacheManager.instance.get<List<dynamic>>(
    _bannersCacheKey,
  );

  final hasSnapshot = cachedCategories != null && cachedBanners != null;
  storeCategories = cachedCategories == null
      ? []
      : cachedCategories
            .map(
              (item) => ProductCategory.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
  storeBanners = cachedBanners == null
      ? []
      : cachedBanners
            .map(
              (item) =>
                  PromoBanner.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
  return hasSnapshot;
}

Future<void> _persistStoreSnapshot() async {
  await Future.wait([
    CacheManager.instance.set(
      _categoriesCacheKey,
      storeCategories.map((item) => item.toJson()).toList(),
      ttl: _catalogCacheTtl,
      tags: const [CacheTags.catalog, CacheTags.categories],
    ),
    CacheManager.instance.set(
      _bannersCacheKey,
      storeBanners.map((item) => item.toJson()).toList(),
      ttl: _catalogCacheTtl,
      tags: const [CacheTags.catalog, CacheTags.banners],
    ),
  ]);
}

// ── REST API load (categories & banners only; products are paginated) ──

Future<bool> loadStoreFromApi({bool refresh = false}) async {
  try {
    if (refresh) await StoreApiService.refreshCatalog();
    final catRows = await StoreApiService.fetchCategories();
    storeCategories.clear();
    for (final row in catRows) {
      final m = StoreApiService.rowToCategoryMap(row);
      storeCategories.add(
        ProductCategory(
          id: m['id'] as String,
          label: m['label'] as String,
          iconUrl: m['iconUrl'] as String? ?? '',
        ),
      );
    }

    final banRows = await StoreApiService.fetchBanners();
    storeBanners.clear();
    for (final row in banRows) {
      final m = StoreApiService.rowToBannerMap(row);
      storeBanners.add(
        PromoBanner(
          id: m['id'] as String,
          title: m['title'] as String,
          subtitle: m['subtitle'] as String? ?? '',
          discountText: m['discountText'] as String? ?? '',
          imageUrl: m['imageUrl'] as String? ?? '',
          ctaText: m['ctaText'] as String? ?? '',
          actionRoute: m['actionRoute'] as String? ?? '',
          productId: m['productId'] as String?,
          categoryId: m['categoryId'] as String?,
        ),
      );
    }

    if (AuthService().hasPermission('coupons.manage')) {
      final couponRows = await StoreApiService.fetchCoupons();
      storeCoupons
        ..clear()
        ..addAll(couponRows.map(Coupon.fromJson));
    } else {
      storeCoupons.clear();
    }

    recalcProductCounts();
    await _persistStoreSnapshot();
    return true;
  } catch (_) {
    return false;
  }
}

// ── Defaults ──
String _genBannerId() => const Uuid().v4();

int get categoryCount => storeCategories.length;
int get productCount => storeProducts.length;

void recalcProductCounts() {
  for (final cat in storeCategories) {
    cat.productCount = storeProducts
        .where((p) => p.categoryId == cat.id)
        .length;
  }
}

List<Product> getProductsByCategory(String categoryId) =>
    storeProducts.where((p) => p.categoryId == categoryId).toList();

List<Product> getProductsByAcademicYear(String? academicYear) {
  if (academicYear == null || academicYear.isEmpty) return storeProducts;
  return storeProducts
      .where((p) => p.academicYear == academicYear || p.academicYear == null)
      .toList();
}

// ── Category CRUD ──
Future<void> addCategory(String name, String iconUrl) async {
  final id = const Uuid().v4();
  await StoreApiService.insertCategory({
    'id': id,
    'name': name,
    'iconUrl': iconUrl,
  });
  storeCategories.add(ProductCategory(id: id, label: name, iconUrl: iconUrl));
  recalcProductCounts();
}

Future<void> deleteCategory(String id) async {
  await StoreApiService.deleteCategory(id);
  storeCategories.removeWhere((c) => c.id == id);
  storeProducts.removeWhere((p) => p.categoryId == id);
  recalcProductCounts();
}

Future<void> updateCategory(String id, String name, String iconUrl) async {
  final idx = storeCategories.indexWhere((c) => c.id == id);
  if (idx >= 0) {
    await StoreApiService.updateCategory(id, name, iconUrl);
    storeCategories[idx] = ProductCategory(
      id: id,
      label: name,
      iconUrl: iconUrl,
    );
    recalcProductCounts();
  }
}

// ── Product CRUD ──
Future<void> addProduct(
  String name,
  String description,
  double price,
  String imageUrl,
  String categoryId,
  String categoryName, {
  String brand = '',
  int stock = 0,
  String? academicYear,
}) async {
  final id = const Uuid().v4();
  await StoreApiService.insertProduct({
    'id': id,
    'name': name,
    'brand': brand,
    'description': description,
    'imageUrl': imageUrl,
    'categoryId': categoryId,
    'price': price,
    'stock': stock,
    'academicYear': academicYear,
  });
  storeProducts.add(
    Product(
      id: id,
      name: name,
      description: description,
      price: price,
      imageUrl: imageUrl,
      categoryId: categoryId,
      categoryName: categoryName,
      brand: brand,
      stock: stock,
      academicYear: academicYear,
      createdAt: DateTime.now(),
    ),
  );
  recalcProductCounts();
}

Future<void> deleteProduct(String id) async {
  await StoreApiService.deleteProduct(id);
  storeProducts.removeWhere((p) => p.id == id);
  recalcProductCounts();
}

Future<void> updateProduct(
  String id,
  String name,
  String description,
  double price,
  String imageUrl,
  String categoryId,
  String categoryName, {
  String brand = '',
  int stock = 0,
  String? academicYear,
}) async {
  final idx = storeProducts.indexWhere((p) => p.id == id);
  if (idx >= 0) {
    await StoreApiService.updateProduct(id, {
      'name': name,
      'brand': brand,
      'description': description,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'price': price,
      'stock': stock,
      'academicYear': academicYear,
    });
    storeProducts[idx] = Product(
      id: id,
      name: name,
      description: description,
      price: price,
      imageUrl: imageUrl,
      categoryId: categoryId,
      categoryName: categoryName,
      brand: brand,
      stock: stock,
      academicYear: academicYear,
      createdAt: storeProducts[idx].createdAt,
    );
    recalcProductCounts();
  }
}

// ── Banner CRUD ──
Future<void> addBanner(
  String title,
  String subtitle,
  String discountText,
  String imageUrl,
  String ctaText,
  String actionRoute, {
  String? productId,
  String? categoryId,
}) async {
  final id = _genBannerId();
  await StoreApiService.insertBanner({
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'discountText': discountText,
    'imageUrl': imageUrl,
    'ctaText': ctaText,
    'actionRoute': actionRoute,
    'productId': productId,
    'categoryId': categoryId,
  });
  storeBanners.add(
    PromoBanner(
      id: id,
      title: title,
      subtitle: subtitle,
      discountText: discountText,
      imageUrl: imageUrl,
      ctaText: ctaText,
      actionRoute: actionRoute,
      productId: productId,
      categoryId: categoryId,
    ),
  );
}

Future<void> deleteBanner(String id) async {
  await StoreApiService.deleteBanner(id);
  storeBanners.removeWhere((b) => b.id == id);
}

Future<void> updateBanner(
  String id,
  String title,
  String subtitle,
  String discountText,
  String imageUrl,
  String ctaText,
  String actionRoute, {
  String? productId,
  String? categoryId,
}) async {
  final idx = storeBanners.indexWhere((b) => b.id == id);
  if (idx >= 0) {
    await StoreApiService.updateBanner(id, {
      'title': title,
      'subtitle': subtitle,
      'discountText': discountText,
      'imageUrl': imageUrl,
      'ctaText': ctaText,
      'actionRoute': actionRoute,
      'productId': productId,
      'categoryId': categoryId,
    });
    storeBanners[idx] = PromoBanner(
      id: id,
      title: title,
      subtitle: subtitle,
      discountText: discountText,
      imageUrl: imageUrl,
      ctaText: ctaText,
      actionRoute: actionRoute,
      productId: productId,
      categoryId: categoryId,
    );
  }
}

// ── Coupon CRUD ──
Future<void> addCoupon(
  String code,
  String description,
  String discountType,
  double discountValue, {
  double? minPurchase,
  DateTime? expiresAt,
  bool isActive = true,
  String? categoryId,
  String? productId,
}) async {
  final id = const Uuid().v4();
  final row = await StoreApiService.insertCoupon({
    'id': id,
    'code': code,
    'description': description,
    'discountType': discountType,
    'discountValue': discountValue,
    'minPurchase': minPurchase,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'isActive': isActive,
    'categoryId': categoryId,
    'productId': productId,
  });
  storeCoupons.add(Coupon.fromJson(row));
}

Future<void> deleteCoupon(String id) async {
  await StoreApiService.deleteCoupon(id);
  storeCoupons.removeWhere((c) => c.id == id);
}

Future<void> updateCoupon(
  String id,
  String code,
  String description,
  String discountType,
  double discountValue, {
  double? minPurchase,
  DateTime? expiresAt,
  bool isActive = true,
  String? categoryId,
  String? productId,
}) async {
  final idx = storeCoupons.indexWhere((c) => c.id == id);
  if (idx >= 0) {
    final row = await StoreApiService.updateCoupon(id, {
      'code': code,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'minPurchase': minPurchase,
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
      'isActive': isActive,
      'categoryId': categoryId,
      'productId': productId,
    });
    storeCoupons[idx] = Coupon.fromJson(row);
  }
}
