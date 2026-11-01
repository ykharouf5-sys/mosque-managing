import 'package:studentry/store/data/catalog_translations.dart';
import 'dart:async';
import 'dart:convert';
import 'package:studentry/shared/cache/cache_manager.dart';
import 'package:studentry/shared/cache/account_snapshot_cache.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_config.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/shared/data/request_diagnostics.dart';
import 'package:studentry/store/data/pending_order_service.dart';
import 'package:studentry/store/data/cart_storage.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/data/store_polling_service.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// ── Catalog Provider ──

final catalogProvider = NotifierProvider<CatalogNotifier, CatalogState>(
  CatalogNotifier.new,
);

class CatalogState {
  final List<PromoBanner> banners;
  final List<ProductCategory> categories;
  final List<Product> products;
  final List<Coupon> coupons;
  final bool isLoadingProducts;
  final bool hasMoreProducts;
  final int currentProductPage;
  final int lastProductPage;

  const CatalogState({
    this.banners = const [],
    this.categories = const [],
    this.products = const [],
    this.coupons = const [],
    this.isLoadingProducts = false,
    this.hasMoreProducts = true,
    this.currentProductPage = 1,
    this.lastProductPage = 1,
  });

  CatalogState copyWith({
    List<PromoBanner>? banners,
    List<ProductCategory>? categories,
    List<Product>? products,
    List<Coupon>? coupons,
    bool? isLoadingProducts,
    bool? hasMoreProducts,
    int? currentProductPage,
    int? lastProductPage,
  }) {
    return CatalogState(
      banners: banners ?? this.banners,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      coupons: coupons ?? this.coupons,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      hasMoreProducts: hasMoreProducts ?? this.hasMoreProducts,
      currentProductPage: currentProductPage ?? this.currentProductPage,
      lastProductPage: lastProductPage ?? this.lastProductPage,
    );
  }
}

class CatalogNotifier extends Notifier<CatalogState> {
  CatalogState get snapshot => state;
  static String get summaryCacheKey =>
      'catalog:v2:${ApiConfig.baseUrl}:summary';
  static String get _sourceScope =>
      ['sales_manager', 'admin'].contains(AuthService().role)
      ? 'sales:${AuthService().userId}'
      : 'customer';
  static String pageCacheKey(int page, {String? academicYear}) =>
      'catalog:v3:${ApiConfig.baseUrl}:$_sourceScope:products:$page:25:${academicYear ?? 'all'}';
  static String pageMetadataCacheKey(int page, {String? academicYear}) =>
      '${pageCacheKey(page, academicYear: academicYear)}:metadata';
  Future<bool>? _refreshing;
  String? _activeProductYear;
  Object? _catalogVersion;
  bool _pageValidated = false;
  bool get hasCachedProductPage =>
      CacheManager.instance.get<List<dynamic>>(
        pageCacheKey(1, academicYear: _activeProductYear),
      ) !=
      null;

  bool get hasCachedPagination =>
      CacheManager.instance.get<Map<String, dynamic>>(
            pageMetadataCacheKey(1, academicYear: _activeProductYear),
          )?['lastPage']
          is int;

  void _selectAcademicYear(String? academicYear) {
    if (_activeProductYear == academicYear) return;
    _activeProductYear = academicYear;
    _products.clear();
    _currentProductPage = 0;
    _pageValidated = false;
    state = state.copyWith(
      products: const [],
      currentProductPage: 1,
      lastProductPage: 1,
      hasMoreProducts: true,
    );
  }

  bool restoreSnapshot({String? academicYear}) {
    _selectAcademicYear(academicYear);
    final cached = CacheManager.instance.get<Map<String, dynamic>>(
      summaryCacheKey,
    );
    if (cached == null) return false;
    _catalogVersion = cached['version'];
    _categories
      ..clear()
      ..addAll(
        (cached['categories'] as List).map(
          (r) => ProductCategory.fromJson(Map<String, dynamic>.from(r as Map)),
        ),
      );
    _banners
      ..clear()
      ..addAll(
        (cached['banners'] as List).map(
          (r) => PromoBanner.fromJson(Map<String, dynamic>.from(r as Map)),
        ),
      );
    loadCachedSnapshot(_banners.toList(), _categories.toList());
    return true;
  }

  Future<bool> refreshCatalog({String? academicYear, bool force = false}) {
    _selectAcademicYear(academicYear);
    if (_refreshing != null) return _refreshing!;
    late final Future<bool> pending;
    pending = _refreshCatalog(force: force).whenComplete(() {
      if (identical(_refreshing, pending)) _refreshing = null;
    });
    return _refreshing = pending;
  }

  Future<bool> _refreshCatalog({bool force = false}) async {
    try {
      final data = await StoreApiService.fetchCatalogSummary(force: force);
      if (!ref.mounted) return false;
      final categories = (data['categories'] as List)
          .map(
            (r) => ProductCategory.fromJson(
              StoreApiService.rowToCategoryMap(
                Map<String, dynamic>.from(r as Map),
              ),
            ),
          )
          .toList();
      final banners =
          [...data['banners'] as List, ...?data['home_banners'] as List?]
              .map(
                (r) => PromoBanner.fromJson(
                  StoreApiService.rowToBannerMap(
                    Map<String, dynamic>.from(r as Map),
                  ),
                ),
              )
              .toList();
      loadBannersAndCategories(banners, categories);
      await CacheManager.instance.set(
        summaryCacheKey,
        {
          'categories': categories.map((r) => r.toJson()).toList(),
          'banners': banners.map((r) => r.toJson()).toList(),
          'version': data['version'],
        },
        ttl: const Duration(days: 30),
        tags: const [CacheTags.catalog],
      );
      if (!ref.mounted) return false;
      // A 304/version match means the selected page is still valid, including
      // a successfully loaded empty page. Do not fetch it again on every tick.
      final changed = _catalogVersion != data['version'];
      _catalogVersion = data['version'];
      if (force || changed || !_pageValidated) {
        _pageValidated = false;
        await loadProductsPage(
          state.currentProductPage,
          force: force || changed,
          reason: force ? RequestReason.manual : RequestReason.automatic,
        );
        if (!_pageValidated) return false;
      }
      if (!ref.mounted) return false;
      if (AuthService().hasPermission('coupons.manage')) {
        final rows = await StoreApiService.fetchCoupons();
        if (!ref.mounted) return false;
        _coupons
          ..clear()
          ..addAll(rows.map(Coupon.fromJson));
      } else {
        _coupons.clear();
      }
      _rebuildState();
      return true;
    } catch (_) {
      return false;
    }
  }

  static const int productPageSize = 25;
  final List<Product> _products = [];
  final List<PromoBanner> _banners = [];
  final List<ProductCategory> _categories = [];
  final List<Coupon> _coupons = [];
  int _currentProductPage = 0;

  @override
  CatalogState build() {
    return CatalogState(
      banners: [..._banners],
      categories: [..._categories],
      products: [..._products],
      coupons: [..._coupons],
      hasMoreProducts:
          _currentProductPage == 0 || _products.length % productPageSize == 0,
    );
  }

  void _rebuildState() {
    if (!ref.mounted) return;
    _recalcProductCounts();
    state = state.copyWith(
      banners: [..._banners],
      categories: [..._categories],
      products: [..._products],
      coupons: [..._coupons],
    );
  }

  void _recalcProductCounts() {
    for (final cat in _categories) {
      cat.productCount ??= _products
          .where((p) => p.categoryId == cat.id)
          .length;
    }
  }

  List<Product> getProductsByCategory(String categoryId) =>
      _products.where((p) => p.categoryId == categoryId).toList();

  List<Product> getProductsByAcademicYear(String? year) {
    if (year == null || year.isEmpty) return _products;
    return _products
        .where((p) => p.academicYear == year || p.academicYear == null)
        .toList();
  }

  void loadBannersAndCategories(
    List<PromoBanner> banners,
    List<ProductCategory> categories,
  ) {
    _banners
      ..clear()
      ..addAll(banners);
    _categories
      ..clear()
      ..addAll(categories);
    _rebuildState();
  }

  /// Hydrates products persisted by the previous successful server response.
  /// Categories and banners are supplied by the same catalog snapshot.
  void loadCachedSnapshot(
    List<PromoBanner> banners,
    List<ProductCategory> categories,
  ) {
    _banners
      ..clear()
      ..addAll(banners);
    _categories
      ..clear()
      ..addAll(categories);
    final cached = CacheManager.instance.get<List<dynamic>>(
      pageCacheKey(1, academicYear: _activeProductYear),
    );
    if (cached != null) {
      _products
        ..clear()
        ..addAll(
          cached.map(
            (item) => Product.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
      final metadata = CacheManager.instance.get<Map<String, dynamic>>(
        pageMetadataCacheKey(1, academicYear: _activeProductYear),
      );
      final lastPage = (metadata?['lastPage'] as int?) ?? 1;
      _currentProductPage = 0;
      _pageValidated = metadata != null;
      state = state.copyWith(
        currentProductPage: 1,
        lastProductPage: lastPage,
        hasMoreProducts: lastPage > 1,
      );
    }
    _rebuildState();
  }

  /// Loads the first page of products from REST (replaces existing).
  Future<void> loadInitialProducts() async {
    if (state.isLoadingProducts) return;
    state = state.copyWith(isLoadingProducts: true);
    _currentProductPage = 0;
    try {
      final page = await StoreApiService.fetchProductPage(
        1,
        productPageSize,
        academicYear: _activeProductYear,
      );
      if (!ref.mounted) return;
      final rows = page.rows;
      final categoryNames = {
        for (final category in _categories) category.id: category.label,
      };
      final parsed = rows.map((row) {
        final m = StoreApiService.rowToProductMap(row);
        return Product(
          id: m['id'] as String,
          name: m['name'] as String,
          translations: parseCatalogCopy(m['translations']),
          publicationStatus: m['publicationStatus'] as String? ?? 'published',
          isTest: m['isTest'] == true,
          categoryTranslations:
              _categories
                  .where((c) => c.id == m['categoryId'])
                  .firstOrNull
                  ?.translations ??
              const {},
          brand: m['brand'] as String? ?? '',
          sourceName: m['sourceName'] as String?,
          description: m['description'] as String? ?? '',
          imageUrl: m['imageUrl'] as String? ?? '',
          thumbnailUrl: m['thumbnailUrl'] as String?,
          physicalStock: (m['physicalStock'] as num?)?.toInt(),
          categoryId: m['categoryId'] as String? ?? '',
          categoryName: categoryNames[m['categoryId']] ?? '',
          price: (m['price'] as num?)?.toDouble() ?? 0,
          rating: (m['rating'] as num?)?.toDouble() ?? 0,
          reviewsCount: (m['reviewsCount'] as num?)?.toInt() ?? 0,
          stock: (m['stock'] as num?)?.toInt() ?? 0,
          createdAt:
              DateTime.tryParse(m['createdAt'] as String? ?? '') ??
              DateTime.now(),
          academicYear: m['academicYear'] as String?,
          deliveryPrice: (m['deliveryPrice'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
      _products
        ..clear()
        ..addAll(parsed);
      _currentProductPage = page.currentPage - 1;
      final hasMore = page.currentPage < page.lastPage;
      _recalcProductCounts();
      _cacheProducts(lastPage: page.lastPage);
      state = state.copyWith(
        categories: [..._categories],
        products: [..._products],
        isLoadingProducts: false,
        hasMoreProducts: hasMore,
        currentProductPage: page.currentPage,
        lastProductPage: page.lastPage,
      );
    } catch (_) {
      // Keep the cached snapshot visible when the server is unreachable.
      if (!ref.mounted) return;
      state = state.copyWith(isLoadingProducts: false);
    }
  }

  /// Replaces the current products with exactly one REST page.
  Future<void> loadProductsPage(
    int requestedPage, {
    bool force = false,
    RequestReason reason = RequestReason.navigation,
  }) async {
    if (state.isLoadingProducts || requestedPage < 1) return;
    state = state.copyWith(isLoadingProducts: true);
    final previousPage = _currentProductPage;
    try {
      final page = await StoreApiService.fetchProductPage(
        requestedPage,
        productPageSize,
        academicYear: _activeProductYear,
        force: force,
        reason: reason,
      );
      final rows = page.rows;
      if (!ref.mounted) return;
      final parsed = rows.map((row) {
        final m = StoreApiService.rowToProductMap(row);
        return Product(
          id: m['id'] as String,
          name: m['name'] as String,
          translations: parseCatalogCopy(m['translations']),
          publicationStatus: m['publicationStatus'] as String? ?? 'published',
          isTest: m['isTest'] == true,
          categoryTranslations:
              _categories
                  .where((c) => c.id == m['categoryId'])
                  .firstOrNull
                  ?.translations ??
              const {},
          brand: m['brand'] as String? ?? '',
          sourceName: m['sourceName'] as String?,
          description: m['description'] as String? ?? '',
          imageUrl: m['imageUrl'] as String? ?? '',
          thumbnailUrl: m['thumbnailUrl'] as String?,
          physicalStock: (m['physicalStock'] as num?)?.toInt(),
          categoryId: m['categoryId'] as String? ?? '',
          categoryName: m['categoryName'] as String? ?? '',
          price: (m['price'] as num?)?.toDouble() ?? 0,
          rating: (m['rating'] as num?)?.toDouble() ?? 0,
          reviewsCount: (m['reviewsCount'] as num?)?.toInt() ?? 0,
          stock: (m['stock'] as num?)?.toInt() ?? 0,
          createdAt:
              DateTime.tryParse(m['createdAt'] as String? ?? '') ??
              DateTime.now(),
          academicYear: m['academicYear'] as String?,
          deliveryPrice: (m['deliveryPrice'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
      _products
        ..clear()
        ..addAll(parsed);
      _currentProductPage = page.currentPage - 1;
      _pageValidated = true;
      _recalcProductCounts();
      _cacheProducts(lastPage: page.lastPage);
      final hasMore = page.currentPage < page.lastPage;
      state = state.copyWith(
        categories: [..._categories],
        products: [..._products],
        isLoadingProducts: false,
        hasMoreProducts: hasMore,
        currentProductPage: page.currentPage,
        lastProductPage: page.lastPage,
      );
    } catch (_) {
      if (!ref.mounted) return;
      _currentProductPage = previousPage;
      state = state.copyWith(isLoadingProducts: false);
    }
  }

  Future<void> loadNextProductsPage() =>
      loadProductsPage(state.currentProductPage + 1);

  void _cacheProducts({int? lastPage}) {
    if (!ref.mounted) return;
    CacheManager.instance.set(
      pageCacheKey(_currentProductPage + 1, academicYear: _activeProductYear),
      _products.map((p) => p.toJson()).toList(),
      ttl: const Duration(days: 30),
      tags: [CacheTags.products],
    );
    CacheManager.instance.set(
      pageMetadataCacheKey(
        _currentProductPage + 1,
        academicYear: _activeProductYear,
      ),
      {'lastPage': lastPage ?? state.lastProductPage},
      ttl: const Duration(days: 30),
      tags: [CacheTags.products],
    );
  }

  // ── Category CRUD ──

  Future<void> addCategory(
    String name,
    String iconUrl, {
    Map<String, dynamic>? translations,
  }) async {
    final id = const Uuid().v4();
    await StoreApiService.insertCategory({
      'id': id,
      'name': name,
      'iconUrl': iconUrl,
      'translations': ?translations,
    });
    _categories.add(
      ProductCategory(
        id: id,
        label: name,
        iconUrl: iconUrl,
        translations: parseCatalogCopy(translations),
      ),
    );
    CacheManager.instance.invalidateTags([
      CacheTags.catalog,
      CacheTags.categories,
    ]);
    _rebuildState();
  }

  Future<void> deleteCategory(String id) async {
    await StoreApiService.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    CacheManager.instance.invalidateTags([
      CacheTags.catalog,
      CacheTags.categories,
      CacheTags.products,
    ]);
    _rebuildState();
  }

  Future<void> updateCategory(
    String id,
    String name,
    String iconUrl, {
    Map<String, dynamic>? translations,
  }) async {
    await StoreApiService.updateCategory(
      id,
      name,
      iconUrl,
      translations: translations,
    );
    final idx = _categories.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      _categories[idx] = ProductCategory(
        id: id,
        label: name,
        iconUrl: iconUrl,
        translations: parseCatalogCopy(translations),
      );
    } else {
      _categories.add(
        ProductCategory(
          id: id,
          label: name,
          iconUrl: iconUrl,
          translations: parseCatalogCopy(translations),
        ),
      );
    }
    CacheManager.instance.invalidateTags([
      CacheTags.catalog,
      CacheTags.categories,
    ]);
    _rebuildState();
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
    String? sourceName,
    int stock = 0,
    String? academicYear,
    Map<String, dynamic>? translations,
    String? publicationStatus,
    bool? isTest,
  }) async {
    final id = const Uuid().v4();
    await StoreApiService.insertProduct({
      'id': id,
      'name': name,
      'translations': ?translations,
      'publicationStatus': ?publicationStatus,
      'isTest': ?isTest,
      'brand': brand,
      'sourceName': ?sourceName,
      'description': description,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'price': price,
      'stock': stock,
      'academicYear': academicYear,
    });
    _products.add(
      Product(
        id: id,
        translations: parseCatalogCopy(translations),
        publicationStatus: publicationStatus ?? 'published',
        isTest: isTest ?? false,
        name: name,
        description: description,
        price: price,
        imageUrl: imageUrl,
        categoryId: categoryId,
        categoryName: categoryName,
        brand: brand,
        sourceName: sourceName,
        stock: stock,
        academicYear: academicYear,
        createdAt: DateTime.now(),
      ),
    );
    _rebuildState();
    CacheManager.instance.invalidate(CacheTags.products);
    _cacheProducts();
  }

  Future<void> deleteProduct(String id) async {
    await StoreApiService.deleteProduct(id);
    _products.removeWhere((p) => p.id == id);
    _rebuildState();
    CacheManager.instance.invalidate(CacheTags.products);
    _cacheProducts();
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
    String? sourceName,
    int stock = 0,
    String? academicYear,
    Map<String, dynamic>? translations,
    String? publicationStatus,
    bool? isTest,
  }) async {
    await StoreApiService.updateProduct(id, {
      'name': name,
      'translations': ?translations,
      'publicationStatus': ?publicationStatus,
      'isTest': ?isTest,
      'brand': brand,
      'sourceName': ?sourceName,
      'description': description,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'price': price,
      'stock': stock,
      'academicYear': academicYear,
    });
    final idx = _products.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _products[idx] = Product(
        id: id,
        translations: parseCatalogCopy(translations),
        publicationStatus:
            publicationStatus ?? _products[idx].publicationStatus,
        isTest: isTest ?? _products[idx].isTest,
        name: name,
        description: description,
        price: price,
        imageUrl: imageUrl,
        categoryId: categoryId,
        categoryName: categoryName,
        brand: brand,
        sourceName: sourceName ?? _products[idx].sourceName,
        stock: stock,
        academicYear: academicYear,
        createdAt: _products[idx].createdAt,
      );
    }
    _rebuildState();
    CacheManager.instance.invalidate(CacheTags.products);
    _cacheProducts();
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
    Map<String, dynamic>? translations,
  }) async {
    final id = const Uuid().v4();
    await StoreApiService.insertBanner({
      'id': id,
      'title': title,
      'translations': ?translations,
      'subtitle': subtitle,
      'discountText': discountText,
      'imageUrl': imageUrl,
      'ctaText': ctaText,
      'actionRoute': actionRoute,
      'productId': productId,
      'categoryId': categoryId,
    });
    _banners.add(
      PromoBanner(
        id: id,
        translations: parseCatalogCopy(translations),
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
    CacheManager.instance.invalidateTags([
      CacheTags.catalog,
      CacheTags.banners,
    ]);
    _rebuildState();
  }

  Future<void> deleteBanner(String id) async {
    await StoreApiService.deleteBanner(id);
    _banners.removeWhere((b) => b.id == id);
    CacheManager.instance.invalidateTags([
      CacheTags.catalog,
      CacheTags.banners,
    ]);
    _rebuildState();
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
    Map<String, dynamic>? translations,
  }) async {
    await StoreApiService.updateBanner(id, {
      'title': title,
      'translations': ?translations,
      'subtitle': subtitle,
      'discountText': discountText,
      'imageUrl': imageUrl,
      'ctaText': ctaText,
      'actionRoute': actionRoute,
      'productId': productId,
      'categoryId': categoryId,
    });
    final idx = _banners.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      _banners[idx] = PromoBanner(
        id: id,
        translations: parseCatalogCopy(translations),
        title: title,
        subtitle: subtitle,
        discountText: discountText,
        imageUrl: imageUrl,
        ctaText: ctaText,
        actionRoute: actionRoute,
        productId: productId,
        categoryId: categoryId,
      );
    } else {
      _banners.add(
        PromoBanner(
          id: id,
          translations: parseCatalogCopy(translations),
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
    CacheManager.instance.invalidateTags([
      CacheTags.catalog,
      CacheTags.banners,
    ]);
    _rebuildState();
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
    final row = await StoreApiService.insertCoupon({
      'id': const Uuid().v4(),
      'code': code,
      'description': description,
      'discountValue': discountValue,
      'discountType': discountType,
      'minPurchase': minPurchase,
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
      'isActive': isActive,
      'categoryId': categoryId,
      'productId': productId,
    });
    _coupons.add(Coupon.fromJson(row));
    _rebuildState();
  }

  Future<void> deleteCoupon(String id) async {
    await StoreApiService.deleteCoupon(id);
    _coupons.removeWhere((c) => c.id == id);
    _rebuildState();
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
    final idx = _coupons.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      final row = await StoreApiService.updateCoupon(id, {
        'code': code,
        'description': description,
        'discountValue': discountValue,
        'discountType': discountType,
        'minPurchase': minPurchase,
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'isActive': isActive,
        'categoryId': categoryId,
        'productId': productId,
      });
      _coupons[idx] = Coupon.fromJson(row);
      _rebuildState();
    }
  }

  void refresh() {
    _rebuildState();
  }
}

// ── Cart Provider ──

class CartState {
  final List<CartItem> items;
  final Coupon? appliedCoupon;

  const CartState({this.items = const [], this.appliedCoupon});

  double get total => items.fold(0.0, (t, ci) => t + ci.totalPrice);
  int get itemCount => items.fold(0, (t, ci) => t + ci.quantity);

  double get discountAmount {
    final c = appliedCoupon;
    if (c == null) return 0;
    if (c.expiresAt != null && c.expiresAt!.isBefore(DateTime.now())) return 0;
    if (!c.isActive) return 0;
    if (c.minPurchase != null && total < c.minPurchase!) return 0;
    double eligible = 0;
    if (c.productId != null) {
      eligible = items
          .where((i) => i.product.id == c.productId)
          .fold(0.0, (t, i) => t + i.totalPrice);
    } else if (c.categoryId != null) {
      eligible = items
          .where((i) => i.product.categoryId == c.categoryId)
          .fold(0.0, (t, i) => t + i.totalPrice);
    } else {
      eligible = total;
    }
    if (c.discountType == 'percentage') return eligible * c.discountValue / 100;
    return c.discountValue > eligible ? eligible : c.discountValue;
  }

  double get discountedTotal => total - discountAmount;
  double get deliveryTotal => items.fold(
    0.0,
    (sum, item) => sum + item.product.deliveryPrice * item.quantity,
  );
  double get grandTotal => discountedTotal + deliveryTotal;

  CartState copyWith({
    List<CartItem>? items,
    Coupon? appliedCoupon,
    bool clearCoupon = false,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  final List<CartItem> _items = [];
  Coupon? _appliedCoupon;
  String? _storageKey;
  bool _restored = false;
  final List<void Function()> _beforeRestore = [];
  Future<void> persistence = Future.value();

  @override
  CartState build() {
    ref.listen(catalogProvider, (_, next) => refreshProductCopy(next.products));
    final userId = AuthService().userId;
    _storageKey = userId == null
        ? null
        : CartStorage.key(ApiConfig.baseUrl, userId);
    final key = _storageKey;
    _restored = key == null;
    final generation = AuthService().sessionGeneration;
    if (key != null) {
      Future.microtask(() async {
        final items = await CartStorage.load(key);
        if (!ref.mounted || generation != AuthService().sessionGeneration) {
          return;
        }
        _items
          ..clear()
          ..addAll(items);
        _restored = true;
        final edits = List<void Function()>.from(_beforeRestore);
        _beforeRestore.clear();
        for (final edit in edits) {
          edit();
        }
        state = CartState(items: [..._items]);
        refreshProductCopy(ref.read(catalogProvider).products);
      });
    }
    return CartState(items: [..._items], appliedCoupon: _appliedCoupon);
  }

  void _persist() {
    if (!_restored && _storageKey != null) return;
    final key = _storageKey;
    if (key != null) {
      persistence = CartStorage.save(key, _items);
      // Callers can await persistence; avoid an unhandled background failure.
      unawaited(persistence.catchError((Object _) {}));
    }
  }

  /// Catalog sync refreshes display copy only; cart money/quantities remain the same.
  void refreshProductCopy(List<Product> products) {
    if (!_restored || _items.isEmpty) return;
    final current = {for (final product in products) product.id: product};
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final latest = current[item.product.id];
      if (latest == null ||
          latest.translations.isEmpty ||
          jsonEncode(latest.translations) ==
              jsonEncode(item.product.translations)) {
        continue;
      }
      final copy = item.product.toJson();
      copy['translations'] = latest.translations;
      copy['categoryTranslations'] = latest.categoryTranslations;
      _items[i] = CartItem(
        product: Product.fromJson(copy),
        quantity: item.quantity,
      );
      changed = true;
    }
    if (changed && ref.mounted) {
      state = CartState(items: [..._items], appliedCoupon: _appliedCoupon);
      _persist();
    }
  }

  void addToCart(Product product, {int quantity = 1}) {
    if (quantity < 1) return;
    if (!_restored) {
      _beforeRestore.add(() => addToCart(product, quantity: quantity));
    }
    final existing = _items.indexWhere((i) => i.product.id == product.id);
    if (existing >= 0) {
      _items[existing].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    state = CartState(items: [..._items], appliedCoupon: _appliedCoupon);
    _persist();
  }

  void removeFromCart(String productId) {
    if (!_restored) _beforeRestore.add(() => removeFromCart(productId));
    _items.removeWhere((i) => i.product.id == productId);
    state = CartState(items: [..._items], appliedCoupon: _appliedCoupon);
    _persist();
  }

  void updateQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(productId);
      return;
    }
    if (!_restored) {
      _beforeRestore.add(() => updateQuantity(productId, newQuantity));
    }
    final idx = _items.indexWhere((i) => i.product.id == productId);
    if (idx >= 0) {
      _items[idx].quantity = newQuantity;
      state = CartState(items: [..._items], appliedCoupon: _appliedCoupon);
      _persist();
    }
  }

  void clearCart() {
    if (!_restored) _beforeRestore.add(clearCart);
    _items.clear();
    _appliedCoupon = null;
    state = const CartState();
    _persist();
  }

  /// Creates an order from cart state, saves to PendingOrderService, returns the Order.
  /// Does NOT clear cart or add to orders list — caller handles that.
  Future<Order> placeOrder({
    required String shippingAddress,
    String? notes,
    required String paymentMethod,
    required String phone,
    String? governorate,
    String? region,
    double? locationLatitude,
    double? locationLongitude,
  }) async {
    if (_items.isEmpty) throw Exception('السلة فارغة');
    final orderId = const Uuid().v4();
    final now = DateTime.now();
    final discountedTotal = state.discountedTotal;
    final discountAmount = state.discountAmount;
    final order = Order(
      id: orderId,
      items: List.from(_items),
      totalPrice: discountedTotal + state.deliveryTotal,
      awaitingSync: true,
      createdAt: now,
      updatedAt: now,
      userId: AuthService().userId ?? '',
      notes: notes,
      couponCode: _appliedCoupon?.code,
      discountAmount: discountAmount > 0 ? discountAmount : null,
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      phone: phone,
      governorate: governorate,
      region: region,
      locationLatitude: locationLatitude,
      locationLongitude: locationLongitude,
      deliveryPrice: state.deliveryTotal,
    );

    final orderMap = order.toJson();
    orderMap['createdAt'] = now.toUtc().toIso8601String();
    orderMap['updatedAt'] = now.toUtc().toIso8601String();
    final result = await PendingOrderService.savePendingOrder(orderMap);

    if (result.status == 'insufficient_stock') {
      throw Exception('المخزون غير كافٍ لبعض المنتجات');
    }
    if (result.isPermanentFailure) {
      throw Exception(
        'تعذر اعتماد الطلب أو كود الخصم. حدّث السلة وحاول مجدداً.',
      );
    }

    return result.isConfirmed && result.confirmedOrder != null
        ? Order.fromJson(result.confirmedOrder!)
        : order;
  }

  Future<String?> applyCoupon(String code) async {
    try {
      final payload = await StoreApiService.validateCoupon(
        code,
        _items
            .map(
              (item) => {
                'product_id': item.product.id,
                'quantity': item.quantity,
              },
            )
            .toList(),
      );
      final coupon = Coupon.fromJson(
        Map<String, dynamic>.from(payload['coupon'] as Map),
      );
      _appliedCoupon = coupon;
      state = CartState(items: [..._items], appliedCoupon: coupon);
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (error) {
      return error.toString();
    }
  }

  void removeCoupon() {
    _appliedCoupon = null;
    state = CartState(items: [..._items]);
  }

  List<CartItem> get items => _items;
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

// ── Favorites Provider ──

class FavoritesState {
  final Set<String> productIds;
  final Map<String, Product> savedProducts;
  const FavoritesState({
    this.productIds = const {},
    this.savedProducts = const {},
  });
  bool isFavorite(String id) => productIds.contains(id);
}

class FavoritesNotifier extends Notifier<FavoritesState> {
  final Set<String> _productIds = {};
  final Map<String, Product> _savedProducts = {};
  static const cacheTtl = Duration(days: 180);
  static String cacheKey(String userId) =>
      'favorites:v1:${ApiConfig.baseUrl}:$userId';

  FavoritesState _snapshot() => FavoritesState(
    productIds: Set.from(_productIds),
    savedProducts: Map.from(_savedProducts),
  );

  Future<void> _persist(String userId) =>
      CacheManager.instance.set(cacheKey(userId), {
        'ids': _productIds.toList(),
        'products': _savedProducts.map(
          (id, product) => MapEntry(id, product.toJson()),
        ),
      }, ttl: cacheTtl);

  @override
  FavoritesState build() {
    _productIds.clear();
    _savedProducts.clear();
    final userId = AuthService().userId;
    if (userId != null) {
      final cached = CacheManager.instance.get<Map<String, dynamic>>(
        cacheKey(userId),
      );
      if (cached != null) {
        _productIds.addAll((cached['ids'] as List? ?? []).map((id) => '$id'));
        final products = cached['products'];
        if (products is Map) {
          for (final entry in products.entries) {
            try {
              final product = Product.fromJson(
                Map<String, dynamic>.from(entry.value as Map),
              );
              if (_productIds.contains(product.id)) {
                _savedProducts[product.id] = product;
              }
            } catch (_) {
              // Ignore a stale product snapshot, but keep its favorite ID.
            }
          }
        }
      }
      Future.microtask(load);
    }
    return _snapshot();
  }

  Future<void> load() async {
    final generation = AuthService().sessionGeneration;
    final userId = AuthService().userId;
    if (userId == null) return;
    try {
      final ids = await StoreApiService.fetchFavorites();
      if (generation != AuthService().sessionGeneration ||
          userId != AuthService().userId) {
        return;
      }
      _productIds
        ..clear()
        ..addAll(ids);
      _savedProducts.removeWhere((id, _) => !_productIds.contains(id));
      state = _snapshot();
      await _persist(userId);
    } on StaleSessionException {
      return;
    } catch (_) {
      // This load starts in a background microtask. Keep the account-scoped
      // snapshot when the device is offline instead of surfacing an unhandled
      // asynchronous exception.
      return;
    }
  }

  Future<void> toggle(String productId, {Product? product}) async {
    final userId = AuthService().userId;
    if (userId == null) return;
    if (_productIds.contains(productId)) {
      await StoreApiService.removeFavorite(productId);
      _productIds.remove(productId);
      _savedProducts.remove(productId);
    } else {
      await StoreApiService.addFavorite(productId);
      _productIds.add(productId);
      if (product != null) _savedProducts[productId] = product;
    }
    if (userId != AuthService().userId) return;
    state = _snapshot();
    await _persist(userId);
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, FavoritesState>(
  FavoritesNotifier.new,
);

// ── Reviews Provider ──

class ReviewsState {
  final Map<String, List<Review>> productReviews;
  const ReviewsState({this.productReviews = const {}});

  List<Review> forProduct(String productId) => productReviews[productId] ?? [];
}

class ReviewsNotifier extends Notifier<ReviewsState> {
  final Map<String, List<Review>> _productReviews = {};
  final Map<String, DateTime> _loadedAt = {};

  @override
  ReviewsState build() =>
      ReviewsState(productReviews: Map.from(_productReviews));

  Future<void> addReview(
    String productId,
    double rating,
    String comment,
  ) async {
    final id = const Uuid().v4();
    final row = await StoreApiService.submitReview(
      productId,
      id: id,
      rating: rating.round(),
      comment: comment,
    );
    final review = Review.fromJson(row);
    _productReviews[productId] = [
      review,
      ...(_productReviews[productId] ?? []).where(
        (item) => item.userId != review.userId,
      ),
    ];
    _loadedAt[productId] = DateTime.now();
    state = ReviewsState(productReviews: Map.from(_productReviews));
  }

  Future<void> listenToReviews(String productId) async {
    final loadedAt = _loadedAt[productId];
    if (_productReviews.containsKey(productId) &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < const Duration(minutes: 5)) {
      return;
    }
    final generation = AuthService().sessionGeneration;
    try {
      final rows = await StoreApiService.fetchReviews(productId);
      if (generation != AuthService().sessionGeneration) return;
      _productReviews[productId] = rows.map(Review.fromJson).toList();
      _loadedAt[productId] = DateTime.now();
      state = ReviewsState(productReviews: Map.from(_productReviews));
    } on StaleSessionException {
      return;
    }
  }

  void cancelReviewsListener() {}
}

final reviewsProvider = NotifierProvider<ReviewsNotifier, ReviewsState>(
  ReviewsNotifier.new,
);

// ── Orders Provider ──

class OrdersState {
  final List<Order> orders;
  final bool isLoadingMore;
  final bool hasMore;

  const OrdersState({
    this.orders = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  OrdersState copyWith({
    List<Order>? orders,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class OrdersNotifier extends Notifier<OrdersState> {
  static const int pageSize = 20;
  final List<Order> _orders = [];
  int _currentPage = 0;
  Future<void>? _initialLoad;
  String? _syncSince;
  DateTime? _lastLoadedAt;
  bool _lastRefreshSucceeded = false;
  bool _refreshAgain = false;
  bool _snapshotRestored = false;
  bool get lastRefreshSucceeded => _lastRefreshSucceeded;

  bool get hasActiveOrders => _orders.any(
    (order) =>
        order.awaitingSync ||
        !{
          OrderStatus.delivered,
          OrderStatus.cancelled,
          OrderStatus.rejected,
        }.contains(order.status),
  );

  @override
  OrdersState build() {
    StorePollingService.onNewOrders = addOrdersFromPolling;
    final subscription = PendingOrderService.updates.listen((_) {
      if (ref.mounted) unawaited(loadInitialOrders(force: true));
    });
    ref.onDispose(subscription.cancel);
    return OrdersState(orders: [..._orders]);
  }

  void refresh() {
    state = state.copyWith(orders: [..._orders]);
  }

  void addOrder(Order order) {
    _orders.removeWhere((old) => old.id == order.id);
    _orders.insert(0, order);
    _cacheOrders();
    state = state.copyWith(orders: [..._orders]);
  }

  /// Initial page once, then an inclusive change feed; pagination is preserved.
  Future<void> loadInitialOrders({bool force = false}) {
    final active = _initialLoad;
    if (active != null) {
      if (force) _refreshAgain = true;
      return active;
    }
    if (state.isLoadingMore) {
      if (force) {
        _refreshAgain = true;
        _lastRefreshSucceeded = false;
      }
      return Future.value();
    }
    if (!force &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) <
            const Duration(seconds: 60)) {
      return Future.value();
    }
    late final Future<void> request;
    request = _loadInitialOrders().whenComplete(() {
      if (identical(_initialLoad, request)) _initialLoad = null;
      _runDeferredRefresh();
    });
    _initialLoad = request;
    return request;
  }

  Future<void> _loadInitialOrders() async {
    _lastRefreshSucceeded = false;
    final generation = AuthService().sessionGeneration;
    final dataGeneration = AppDatabase.captureActiveDataGeneration();
    try {
      if (!_snapshotRestored) {
        _snapshotRestored = true;
        // Remove the obsolete unscoped, plaintext snapshot from older builds.
        CacheManager.instance.remove('orders:all');
        final cached = await AccountSnapshotCache.load(
          AccountSnapshotCache.key('orders'),
        );
        if (!ref.mounted || generation != AuthService().sessionGeneration) {
          return;
        }
        if (cached != null) {
          final restored = (cached['orders'] as List)
              .whereType<Map>()
              .map((row) => Order.fromJson(Map<String, dynamic>.from(row)))
              .toList();
          _orders.addAll(
            restored.where((row) => !_orders.any((old) => old.id == row.id)),
          );
          _currentPage = (cached['page'] as num?)?.toInt() ?? 0;
          _syncSince = cached['since'] as String?;
          state = state.copyWith(
            orders: [..._orders],
            hasMore: cached['more'] == true,
          );
        }
      }
      final initial = _syncSince == null;
      List<Map<String, dynamic>> rows;
      String? serverTime;
      bool hasMore = state.hasMore;
      if (initial) {
        final page = await StoreApiService.fetchOrderPage(0, pageSize);
        rows = page.rows;
        serverTime = page.serverTime;
        hasMore = page.hasMore;
      } else {
        final changes = await StoreApiService.fetchOrderChanges(_syncSince!);
        rows = changes.rows;
        serverTime = changes.serverTime;
      }
      if (!ref.mounted || generation != AuthService().sessionGeneration) return;
      final parsed = _parseOrders(rows);
      final local = await AppDatabase.getPendingOrders(
        expectedGeneration: dataGeneration,
      );
      if (!ref.mounted || generation != AuthService().sessionGeneration) return;
      final merged = mergeOrderSnapshots(
        mergeConfirmedOrderUpdates(_orders, parsed),
        local,
      );
      _orders
        ..clear()
        ..addAll(merged);
      _syncSince = serverTime;
      _lastLoadedAt = DateTime.now();
      _lastRefreshSucceeded = true;
      _cacheOrders(hasMore: hasMore);
      state = state.copyWith(
        orders: [..._orders],
        isLoadingMore: false,
        hasMore: hasMore,
      );
    } catch (_) {
      // An offline refresh must preserve the account's visible snapshot.
      try {
        final local = await AppDatabase.getPendingOrders(
          expectedGeneration: dataGeneration,
        );
        if (ref.mounted && generation == AuthService().sessionGeneration) {
          final merged = mergeOrderSnapshots(_orders, local);
          _orders
            ..clear()
            ..addAll(merged);
          state = state.copyWith(orders: [..._orders]);
        }
      } catch (_) {
        /* Preserve snapshot if the account/database changed. */
      }
      if (ref.mounted) state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Loads the next page of orders from REST and appends.
  Future<void> loadNextOrdersPage() async {
    final initial = _initialLoad;
    if (initial != null) await initial;
    if (!ref.mounted) return;
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    _currentPage++;
    try {
      final page = await StoreApiService.fetchOrderPage(_currentPage, pageSize);
      final rows = page.rows;
      if (!ref.mounted) return;
      final merged = mergeConfirmedOrderUpdates(_orders, _parseOrders(rows));
      _orders
        ..clear()
        ..addAll(merged);
      _cacheOrders(hasMore: page.hasMore);
      state = state.copyWith(
        orders: [..._orders],
        isLoadingMore: false,
        hasMore: page.hasMore,
      );
    } catch (_) {
      _currentPage--;
      if (ref.mounted) state = state.copyWith(isLoadingMore: false);
    } finally {
      _runDeferredRefresh();
    }
  }

  void _runDeferredRefresh() {
    if (_refreshAgain &&
        ref.mounted &&
        !state.isLoadingMore &&
        _initialLoad == null) {
      _refreshAgain = false;
      unawaited(loadInitialOrders(force: true));
    }
  }

  void addOrdersFromPolling(List<Order> newOrders) {
    final merged = mergeConfirmedOrderUpdates(_orders, newOrders);
    _orders
      ..clear()
      ..addAll(merged);
    _cacheOrders();
    state = state.copyWith(orders: [..._orders]);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await StoreApiService.updateOrderStatus(orderId, status);
    await loadInitialOrders(force: true);
  }

  void _cacheOrders({bool? hasMore}) {
    final confirmed = _orders.where((o) => !o.awaitingSync).toList();
    final snapshot = confirmed.take(200).toList();
    unawaited(
      AccountSnapshotCache.save(
        AccountSnapshotCache.key('orders'),
        {
          'orders': snapshot.map((o) => o.toJson()).toList(),
          'page': confirmed.length > 200 ? 9 : _currentPage,
          'more': confirmed.length > 200 || (hasMore ?? state.hasMore),
          'since': _syncSince,
        },
        generation: AuthService().sessionGeneration,
      ).catchError((Object _) {}),
    );
  }

  List<Order> _parseOrders(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final m = StoreApiService.rowToOrderMap(row);
      return Order(
        id: m['id'] as String,
        userId: m['userId'] as String? ?? '',
        items:
            (m['items'] as List?)
                ?.whereType<Map>()
                .map(
                  (item) => CartItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList() ??
            [],
        status: orderStatusFromWire(m['status']?.toString()),
        totalPrice: (m['totalPrice'] as num?)?.toDouble() ?? 0,
        deliveryPrice: (m['deliveryPrice'] as num?)?.toDouble() ?? 0,
        discountAmount: (m['discountAmount'] as num?)?.toDouble(),
        couponCode: m['couponCode'] as String?,
        paymentMethod: m['paymentMethod']?.toString() ?? 'cod',
        createdAt:
            DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(m['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
        shippingAddress: m['shippingAddress']?.toString(),
        phone: m['phone']?.toString(),
        governorate: m['governorate']?.toString(),
        region: m['region']?.toString(),
        locationLatitude:
            ((m['locationLatitude'] ?? m['location_latitude']) as num?)
                ?.toDouble(),
        locationLongitude:
            ((m['locationLongitude'] ?? m['location_longitude']) as num?)
                ?.toDouble(),
      );
    }).toList();
  }
}

/// Delta merging must not discard loaded history or duplicate overlapping pages.
List<Order> mergeConfirmedOrderUpdates(
  List<Order> existing,
  List<Order> updates,
) {
  final byId = {for (final order in existing) order.id: order};
  for (final order in updates) {
    final old = byId[order.id];
    if (old == null ||
        old.awaitingSync ||
        old.submissionError != null ||
        !order.updatedAt.isBefore(old.updatedAt)) {
      byId[order.id] = order;
    }
  }
  return byId.values.toList()..sort((a, b) {
    final time = b.createdAt.compareTo(a.createdAt);
    return time == 0 ? b.id.compareTo(a.id) : time;
  });
}

/// Local queued/failed attempts remain visible; a confirmed server order wins
/// if a response was lost and the same id exists in both snapshots.
List<Order> mergeOrderSnapshots(
  List<Order> confirmed,
  List<Map<String, dynamic>> localRows,
) {
  final orders = {for (final order in confirmed) order.id: order};
  for (final row in localRows) {
    final data = Map<String, dynamic>.from(
      jsonDecode(row['data'] as String) as Map,
    );
    final id = data['id'] as String;
    if (orders[id] != null &&
        !orders[id]!.awaitingSync &&
        orders[id]!.submissionError == null) {
      continue;
    }
    orders[id] = Order.fromJson({
      ...data,
      'awaitingSync': data['submissionError'] == null,
    });
  }
  return orders.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

final ordersProvider = NotifierProvider<OrdersNotifier, OrdersState>(
  OrdersNotifier.new,
);
