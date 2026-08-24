import 'package:dentalcare/store/data/store_models.dart';
import 'package:dentalcare/store/data/store_api_service.dart';
import 'package:dentalcare/store/data/pending_order_service.dart';
import 'package:dentalcare/shared/cache/cache_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

// ── Global in-memory lists ──
List<PromoBanner> dummyBanners = [];
List<ProductCategory> dummyCategories = [];
List<Product> dummyProducts = [];
List<Coupon> dummyCoupons = [];
List<CartItem> cartItems = [];
final Set<String> favoriteProductIds = {};
List<Order> myOrders = [];
final Map<String, List<Review>> productReviews = {};
void Function()? onStoreDataChanged;

const _categoriesCacheKey = 'store:catalog:categories';
const _bannersCacheKey = 'store:catalog:banners';
const _catalogCacheTtl = Duration(days: 30);

/// Restores the last usable catalog before any network request is made.
/// Bundled defaults are used only on a device that has never downloaded a
/// catalog, so the first store frame is never an empty shell.
bool loadStoreSnapshot() {
  final cachedCategories = CacheManager.instance.get<List<dynamic>>(
    _categoriesCacheKey,
  );
  final cachedBanners = CacheManager.instance.get<List<dynamic>>(
    _bannersCacheKey,
  );

  final hasSnapshot = cachedCategories != null && cachedBanners != null;
  dummyCategories = cachedCategories == null
      ? []
      : cachedCategories
            .map(
              (item) => ProductCategory.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
  dummyBanners = cachedBanners == null
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
      dummyCategories.map((item) => item.toJson()).toList(),
      ttl: _catalogCacheTtl,
      tags: const [CacheTags.catalog, CacheTags.categories],
    ),
    CacheManager.instance.set(
      _bannersCacheKey,
      dummyBanners.map((item) => item.toJson()).toList(),
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
    dummyCategories.clear();
    for (final row in catRows) {
      final m = StoreApiService.rowToCategoryMap(row);
      dummyCategories.add(
        ProductCategory(
          id: m['id'] as String,
          label: m['label'] as String,
          iconUrl: m['iconUrl'] as String? ?? '',
        ),
      );
    }

    final banRows = await StoreApiService.fetchBanners();
    dummyBanners.clear();
    for (final row in banRows) {
      final m = StoreApiService.rowToBannerMap(row);
      dummyBanners.add(
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

    final productRows = await StoreApiService.fetchProducts();
    final categoryNames = {
      for (final category in dummyCategories) category.id: category.label,
    };
    dummyProducts
      ..clear()
      ..addAll(
        productRows.map((row) {
          final m = StoreApiService.rowToProductMap(row);
          final categoryId = m['categoryId'] as String? ?? '';
          return Product(
            id: m['id'] as String,
            name: m['name'] as String,
            brand: m['brand'] as String? ?? '',
            description: m['description'] as String? ?? '',
            imageUrl: m['imageUrl'] as String? ?? '',
            categoryId: categoryId,
            categoryName: categoryNames[categoryId] ?? '',
            price: (m['price'] as num?)?.toDouble() ?? 0,
            stock: (m['stock'] as num?)?.toInt() ?? 0,
            createdAt:
                DateTime.tryParse(m['createdAt'] as String? ?? '') ??
                DateTime.now(),
          );
        }),
      );

    recalcProductCounts();
    await _persistStoreSnapshot();
    debugPrint(
      '📦 Store loaded from API: ${dummyCategories.length} categories, '
      '${dummyProducts.length} products, ${dummyBanners.length} banners',
    );
    return true;
  } catch (e, stackTrace) {
    debugPrint('⚠️ loadStoreFromApi error: $e');
    debugPrintStack(stackTrace: stackTrace);
    return false;
  }
}

// ── Defaults ──
List<PromoBanner> get defaultBanners => [
  const PromoBanner(
    id: 'b1',
    title: 'خصم خاص',
    subtitle: 'على أدوات العناية بالأسنان',
    discountText: 'خصم 30%',
    imageUrl: 'https://i.imgur.com/placeholder1.png',
    ctaText: 'تسوق الآن',
    actionRoute: '/promo-detail',
  ),
  const PromoBanner(
    id: 'b2',
    title: 'عروض التجميل',
    subtitle: 'منتجات تبييض الأسنان',
    discountText: 'خصم 25%',
    imageUrl: 'https://i.imgur.com/placeholder2.png',
    ctaText: 'اكتشف العروض',
    actionRoute: '/promo-detail',
  ),
];

List<ProductCategory> get defaultCategories => [
  ProductCategory(
    id: 'c1',
    label: 'فرش أسنان',
    iconUrl: 'https://img.icons8.com/color/96/toothbrush.png',
  ),
  ProductCategory(
    id: 'c2',
    label: 'معجون أسنان',
    iconUrl: 'https://img.icons8.com/color/96/toothpaste.png',
  ),
  ProductCategory(
    id: 'c3',
    label: 'خيط طبي',
    iconUrl: 'https://img.icons8.com/color/96/dental-floss.png',
  ),
  ProductCategory(
    id: 'c4',
    label: 'غسول فم',
    iconUrl: 'https://img.icons8.com/color/96/mouthwash.png',
  ),
  ProductCategory(
    id: 'c5',
    label: 'تبييض أسنان',
    iconUrl: 'https://img.icons8.com/color/96/whitening.png',
  ),
  ProductCategory(
    id: 'c6',
    label: 'أدوات تقويم',
    iconUrl: 'https://img.icons8.com/color/96/braces.png',
  ),
  ProductCategory(
    id: 'c7',
    label: 'مطهرات',
    iconUrl: 'https://img.icons8.com/color/96/disinfectant.png',
  ),
  ProductCategory(
    id: 'c8',
    label: 'قفازات',
    iconUrl: 'https://img.icons8.com/color/96/gloves.png',
  ),
];

String _genBannerId() => const Uuid().v4();

int get categoryCount => dummyCategories.length;
int get productCount => dummyProducts.length;

void recalcProductCounts() {
  for (final cat in dummyCategories) {
    cat.productCount = dummyProducts
        .where((p) => p.categoryId == cat.id)
        .length;
  }
}

List<Product> getProductsByCategory(String categoryId) =>
    dummyProducts.where((p) => p.categoryId == categoryId).toList();

List<Product> getProductsByAcademicYear(String? academicYear) {
  if (academicYear == null || academicYear.isEmpty) return dummyProducts;
  return dummyProducts
      .where((p) => p.academicYear == academicYear || p.academicYear == null)
      .toList();
}

List<Product> get favoriteProducts =>
    dummyProducts.where((p) => favoriteProductIds.contains(p.id)).toList();

double get cartTotal => cartItems.fold(0.0, (t, ci) => t + ci.totalPrice);
int get cartItemCount => cartItems.fold(0, (t, ci) => t + ci.quantity);
Coupon? appliedCoupon;

double get discountAmount {
  final c = appliedCoupon;
  if (c == null) return 0;
  if (c.expiresAt != null && c.expiresAt!.isBefore(DateTime.now())) return 0;
  if (!c.isActive) return 0;
  if (c.minPurchase != null && cartTotal < c.minPurchase!) return 0;

  double eligible = 0;
  if (c.productId != null) {
    eligible = cartItems
        .where((i) => i.product.id == c.productId)
        .fold(0.0, (t, i) => t + i.totalPrice);
  } else if (c.categoryId != null) {
    eligible = cartItems
        .where((i) => i.product.categoryId == c.categoryId)
        .fold(0.0, (t, i) => t + i.totalPrice);
  } else {
    eligible = cartTotal;
  }
  if (c.discountType == 'percentage') {
    return eligible * c.discountValue / 100;
  } else {
    return c.discountValue > eligible ? eligible : c.discountValue;
  }
}

double get discountedTotal => cartTotal - discountAmount;

// ── Category CRUD ──
void addCategory(String name, String iconUrl) {
  final id = const Uuid().v4();
  dummyCategories.add(ProductCategory(id: id, label: name, iconUrl: iconUrl));
  recalcProductCounts();
  onStoreDataChanged?.call();
  StoreApiService.insertCategory({'id': id, 'name': name, 'iconUrl': iconUrl});
}

void deleteCategory(String id) {
  dummyCategories.removeWhere((c) => c.id == id);
  dummyProducts.removeWhere((p) => p.categoryId == id);
  recalcProductCounts();
  onStoreDataChanged?.call();
  StoreApiService.deleteCategory(id);
}

void updateCategory(String id, String name, String iconUrl) {
  final idx = dummyCategories.indexWhere((c) => c.id == id);
  if (idx >= 0) {
    dummyCategories[idx] = ProductCategory(
      id: id,
      label: name,
      iconUrl: iconUrl,
    );
    recalcProductCounts();
    onStoreDataChanged?.call();
    StoreApiService.updateCategory(id, name, iconUrl);
  }
}

// ── Product CRUD ──
void addProduct(
  String name,
  String description,
  double price,
  String imageUrl,
  String categoryId,
  String categoryName, {
  String brand = '',
  int stock = 0,
  String? academicYear,
}) {
  final id = const Uuid().v4();
  dummyProducts.add(
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
  onStoreDataChanged?.call();
  StoreApiService.insertProduct({
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'categoryId': categoryId,
    'price': price,
    'stock': stock,
  });
}

void deleteProduct(String id) {
  dummyProducts.removeWhere((p) => p.id == id);
  recalcProductCounts();
  onStoreDataChanged?.call();
  StoreApiService.deleteProduct(id);
}

void updateProduct(
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
}) {
  final idx = dummyProducts.indexWhere((p) => p.id == id);
  if (idx >= 0) {
    dummyProducts[idx] = Product(
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
      createdAt: dummyProducts[idx].createdAt,
    );
    recalcProductCounts();
    onStoreDataChanged?.call();
    StoreApiService.updateProduct(id, {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'price': price,
      'stock': stock,
    });
  }
}

// ── Banner CRUD ──
void addBanner(
  String title,
  String subtitle,
  String discountText,
  String imageUrl,
  String ctaText,
  String actionRoute, {
  String? productId,
  String? categoryId,
}) {
  final id = _genBannerId();
  dummyBanners.add(
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
  onStoreDataChanged?.call();
  StoreApiService.insertBanner({
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
}

void deleteBanner(String id) {
  dummyBanners.removeWhere((b) => b.id == id);
  onStoreDataChanged?.call();
  StoreApiService.deleteBanner(id);
}

void updateBanner(
  String id,
  String title,
  String subtitle,
  String discountText,
  String imageUrl,
  String ctaText,
  String actionRoute, {
  String? productId,
  String? categoryId,
}) {
  final idx = dummyBanners.indexWhere((b) => b.id == id);
  if (idx >= 0) {
    dummyBanners[idx] = PromoBanner(
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
    onStoreDataChanged?.call();
    StoreApiService.updateBanner(id, {
      'title': title,
      'subtitle': subtitle,
      'discountText': discountText,
      'imageUrl': imageUrl,
      'ctaText': ctaText,
      'actionRoute': actionRoute,
      'productId': productId,
      'categoryId': categoryId,
    });
  }
}

// ── Coupon CRUD ──
void addCoupon(
  String code,
  String description,
  String discountType,
  double discountValue, {
  double? minPurchase,
  DateTime? expiresAt,
  bool isActive = true,
  String? categoryId,
  String? productId,
}) {
  dummyCoupons.add(
    Coupon(
      id: const Uuid().v4(),
      code: code,
      description: description,
      discountValue: discountValue,
      discountType: discountType,
      minPurchase: minPurchase,
      expiresAt: expiresAt,
      isActive: isActive,
      categoryId: categoryId,
      productId: productId,
    ),
  );
  onStoreDataChanged?.call();
}

void deleteCoupon(String id) {
  dummyCoupons.removeWhere((c) => c.id == id);
  if (appliedCoupon?.id == id) appliedCoupon = null;
  onStoreDataChanged?.call();
}

void updateCoupon(
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
}) {
  final idx = dummyCoupons.indexWhere((c) => c.id == id);
  if (idx >= 0) {
    dummyCoupons[idx] = Coupon(
      id: id,
      code: code,
      description: description,
      discountValue: discountValue,
      discountType: discountType,
      minPurchase: minPurchase,
      expiresAt: expiresAt,
      isActive: isActive,
      categoryId: categoryId,
      productId: productId,
    );
    onStoreDataChanged?.call();
  }
}

// ── Cart ──
void addToCart(Product product, {int quantity = 1}) {
  final existing = cartItems.indexWhere((i) => i.product.id == product.id);
  if (existing >= 0) {
    cartItems[existing].quantity += quantity;
  } else {
    cartItems.add(CartItem(product: product, quantity: quantity));
  }
  onStoreDataChanged?.call();
}

void removeFromCart(String productId) {
  cartItems.removeWhere((i) => i.product.id == productId);
  onStoreDataChanged?.call();
}

void updateCartItemQuantity(String productId, int newQuantity) {
  final idx = cartItems.indexWhere((i) => i.product.id == productId);
  if (idx >= 0) {
    if (newQuantity <= 0) {
      cartItems.removeAt(idx);
    } else {
      cartItems[idx].quantity = newQuantity;
    }
    onStoreDataChanged?.call();
  }
}

// ── Coupon application ──
Future<String?> applyCouponCode(String code) async {
  final coupon = dummyCoupons
      .where((c) => c.code == code && c.isActive)
      .firstOrNull;
  if (coupon == null) return 'كود الخصم غير صالح';
  if (coupon.expiresAt != null && coupon.expiresAt!.isBefore(DateTime.now())) {
    return 'انتهت صلاحية كود الخصم';
  }
  if (coupon.minPurchase != null && cartTotal < coupon.minPurchase!) {
    return 'الحد الأدنى للشراء هو \$${coupon.minPurchase!.toStringAsFixed(0)}';
  }
  appliedCoupon = coupon;
  onStoreDataChanged?.call();
  return null;
}

Future<void> removeAppliedCoupon() async {
  appliedCoupon = null;
  onStoreDataChanged?.call();
}

// ── Orders ──

Future<void> placeOrder({
  required String shippingAddress,
  String? notes,
  required String paymentMethod,
  required String phone,
  String? governorate,
  String? region,
}) async {
  if (cartItems.isEmpty) return;
  final orderId = const Uuid().v4();
  final now = DateTime.now();
  final order = Order(
    id: orderId,
    items: List.from(cartItems),
    totalPrice: discountedTotal,
    createdAt: now,
    updatedAt: now,
    userId: '',
    notes: notes,
    couponCode: appliedCoupon?.code,
    discountAmount: discountAmount > 0 ? discountAmount : null,
    shippingAddress: shippingAddress,
    paymentMethod: paymentMethod,
    phone: phone,
    governorate: governorate,
    region: region,
    deliveryPrice: cartItems.fold(0.0, (t, i) => t + i.product.deliveryPrice),
  );

  // Save to local SQLite first, then send through the REST queue.
  final orderMap = order.toJson();
  orderMap['createdAt'] = now.toUtc().toIso8601String();
  orderMap['updatedAt'] = now.toUtc().toIso8601String();
  final result = await PendingOrderService.savePendingOrder(orderMap);

  if (result == 'insufficient_stock') {
    throw Exception('المخزون غير كافٍ لبعض المنتجات');
  }

  // Update in-memory state only after local persistence confirmed
  myOrders.insert(0, order);
  cartItems.clear();
  appliedCoupon = null;
  onStoreDataChanged?.call();
}

// ── Favorites ──
bool isFavorite(String productId) => favoriteProductIds.contains(productId);

void toggleFavorite(String productId) {
  if (favoriteProductIds.contains(productId)) {
    favoriteProductIds.remove(productId);
  } else {
    favoriteProductIds.add(productId);
  }
  onStoreDataChanged?.call();
}

// ── Reviews ──

void addReview(String productId, double rating, String comment) {
  final id = const Uuid().v4();
  final review = Review(
    id: id,
    productId: productId,
    userId: '',
    userName: 'مستخدم',
    rating: rating,
    comment: comment,
    createdAt: DateTime.now(),
  );
  productReviews[productId] = [review, ...(productReviews[productId] ?? [])];
  _notifyReviewListeners(productId);
  onStoreDataChanged?.call();
}

final _reviewListeners = <String, List<VoidCallback>>{};

void listenToReviews(String productId) {
  _reviewListeners.putIfAbsent(productId, () => []);
}

void cancelReviewsListener() {
  // no-op for local
}

void _notifyReviewListeners(String productId) {
  for (final cb in _reviewListeners[productId] ?? []) {
    cb();
  }
}
