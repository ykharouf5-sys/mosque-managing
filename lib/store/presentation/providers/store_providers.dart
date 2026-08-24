import 'package:studentry/shared/cache/cache_manager.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/store/data/pending_order_service.dart';
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

  const CatalogState({
    this.banners = const [],
    this.categories = const [],
    this.products = const [],
    this.coupons = const [],
    this.isLoadingProducts = false,
    this.hasMoreProducts = true,
  });

  CatalogState copyWith({
    List<PromoBanner>? banners,
    List<ProductCategory>? categories,
    List<Product>? products,
    List<Coupon>? coupons,
    bool? isLoadingProducts,
    bool? hasMoreProducts,
  }) {
    return CatalogState(
      banners: banners ?? this.banners,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      coupons: coupons ?? this.coupons,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      hasMoreProducts: hasMoreProducts ?? this.hasMoreProducts,
    );
  }
}

class CatalogNotifier extends Notifier<CatalogState> {
  static const int productPageSize = 30;
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
      cat.productCount = _products.where((p) => p.categoryId == cat.id).length;
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
  /// Categories and banners are supplied by store_data's snapshot loader.
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
    final cached = CacheManager.instance.get<List<dynamic>>('products:all');
    if (cached != null) {
      _products
        ..clear()
        ..addAll(
          cached.map(
            (item) => Product.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
    }
    _rebuildState();
  }

  /// Loads the first page of products from REST (replaces existing).
  Future<void> loadInitialProducts() async {
    state = state.copyWith(isLoadingProducts: true);
    _currentProductPage = 0;
    try {
      final rows = await StoreApiService.fetchProductsPage(0, productPageSize);
      final categoryNames = {
        for (final category in _categories) category.id: category.label,
      };
      final parsed = rows.map((row) {
        final m = StoreApiService.rowToProductMap(row);
        return Product(
          id: m['id'] as String,
          name: m['name'] as String,
          brand: m['brand'] as String? ?? '',
          description: m['description'] as String? ?? '',
          imageUrl: m['imageUrl'] as String? ?? '',
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
      final hasMore = rows.length >= productPageSize;
      _recalcProductCounts();
      _cacheProducts();
      state = state.copyWith(
        categories: [..._categories],
        products: [..._products],
        isLoadingProducts: false,
        hasMoreProducts: hasMore,
      );
    } catch (_) {
      // Keep the cached snapshot visible when the server is unreachable.
      state = state.copyWith(isLoadingProducts: false);
    }
  }

  /// Loads the next page of products from REST and appends to the list.
  Future<void> loadNextProductsPage() async {
    if (state.isLoadingProducts || !state.hasMoreProducts) return;
    state = state.copyWith(isLoadingProducts: true);
    _currentProductPage++;
    try {
      final rows = await StoreApiService.fetchProductsPage(
        _currentProductPage,
        productPageSize,
      );
      final parsed = rows.map((row) {
        final m = StoreApiService.rowToProductMap(row);
        return Product(
          id: m['id'] as String,
          name: m['name'] as String,
          brand: m['brand'] as String? ?? '',
          description: m['description'] as String? ?? '',
          imageUrl: m['imageUrl'] as String? ?? '',
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
      _products.addAll(parsed);
      _recalcProductCounts();
      _cacheProducts();
      final hasMore = rows.length >= productPageSize;
      state = state.copyWith(
        categories: [..._categories],
        products: [..._products],
        isLoadingProducts: false,
        hasMoreProducts: hasMore,
      );
    } catch (_) {
      _currentProductPage--;
      state = state.copyWith(isLoadingProducts: false);
    }
  }

  void _cacheProducts() {
    if (_products.isNotEmpty) {
      CacheManager.instance.set(
        'products:all',
        _products.map((p) => p.toJson()).toList(),
        ttl: const Duration(days: 30),
        tags: [CacheTags.products],
      );
    }
  }

  // ── Category CRUD ──

  Future<void> addCategory(String name, String iconUrl) async {
    final id = const Uuid().v4();
    await StoreApiService.insertCategory({
      'id': id,
      'name': name,
      'iconUrl': iconUrl,
    });
    _categories.add(ProductCategory(id: id, label: name, iconUrl: iconUrl));
    _rebuildState();
  }

  Future<void> deleteCategory(String id) async {
    await StoreApiService.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    _products.removeWhere((p) => p.categoryId == id);
    _rebuildState();
  }

  Future<void> updateCategory(String id, String name, String iconUrl) async {
    final idx = _categories.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      await StoreApiService.updateCategory(id, name, iconUrl);
      _categories[idx] = ProductCategory(id: id, label: name, iconUrl: iconUrl);
      _rebuildState();
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
    _products.add(
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
    _rebuildState();
    CacheManager.instance.invalidate(CacheTags.products);
  }

  Future<void> deleteProduct(String id) async {
    await StoreApiService.deleteProduct(id);
    _products.removeWhere((p) => p.id == id);
    _rebuildState();
    CacheManager.instance.invalidate(CacheTags.products);
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
    final idx = _products.indexWhere((p) => p.id == id);
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
      _products[idx] = Product(
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
        createdAt: _products[idx].createdAt,
      );
      _rebuildState();
      CacheManager.instance.invalidate(CacheTags.products);
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
    final id = const Uuid().v4();
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
    _banners.add(
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
    _rebuildState();
  }

  Future<void> deleteBanner(String id) async {
    await StoreApiService.deleteBanner(id);
    _banners.removeWhere((b) => b.id == id);
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
  }) async {
    final idx = _banners.indexWhere((b) => b.id == id);
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
      _banners[idx] = PromoBanner(
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
      _rebuildState();
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

  @override
  CartState build() {
    return CartState(items: [..._items], appliedCoupon: _appliedCoupon);
  }

  void addToCart(Product product, {int quantity = 1}) {
    final existing = _items.indexWhere((i) => i.product.id == product.id);
    if (existing >= 0) {
      _items[existing].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    state = CartState(items: [..._items], appliedCoupon: _appliedCoupon);
  }

  void removeFromCart(String productId) {
    _items.removeWhere((i) => i.product.id == productId);
    state = CartState(items: [..._items], appliedCoupon: _appliedCoupon);
  }

  void updateQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(productId);
      return;
    }
    final idx = _items.indexWhere((i) => i.product.id == productId);
    if (idx >= 0) {
      _items[idx].quantity = newQuantity;
      state = CartState(items: [..._items], appliedCoupon: _appliedCoupon);
    }
  }

  void clearCart() {
    _items.clear();
    _appliedCoupon = null;
    state = const CartState();
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
  }) async {
    if (_items.isEmpty) throw Exception('السلة فارغة');
    final orderId = const Uuid().v4();
    final now = DateTime.now();
    final discountedTotal = state.discountedTotal;
    final discountAmount = state.discountAmount;
    final order = Order(
      id: orderId,
      items: List.from(_items),
      totalPrice: discountedTotal,
      createdAt: now,
      updatedAt: now,
      userId: '',
      notes: notes,
      couponCode: _appliedCoupon?.code,
      discountAmount: discountAmount > 0 ? discountAmount : null,
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      phone: phone,
      governorate: governorate,
      region: region,
      deliveryPrice: _items.fold(0.0, (t, i) => t + i.product.deliveryPrice),
    );

    final orderMap = order.toJson();
    orderMap['createdAt'] = now.toUtc().toIso8601String();
    orderMap['updatedAt'] = now.toUtc().toIso8601String();
    final result = await PendingOrderService.savePendingOrder(orderMap);

    if (result == 'insufficient_stock') {
      throw Exception('المخزون غير كافٍ لبعض المنتجات');
    }
    if (result == 'invalid_order') {
      throw Exception(
        'تعذر اعتماد الطلب أو كود الخصم. حدّث السلة وحاول مجدداً.',
      );
    }

    return order;
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
  const FavoritesState({this.productIds = const {}});
  bool isFavorite(String id) => productIds.contains(id);
}

class FavoritesNotifier extends Notifier<FavoritesState> {
  final Set<String> _productIds = {};

  @override
  FavoritesState build() {
    Future.microtask(load);
    return FavoritesState(productIds: Set.from(_productIds));
  }

  Future<void> load() async {
    final generation = AuthService().sessionGeneration;
    try {
      final ids = await StoreApiService.fetchFavorites();
      if (generation != AuthService().sessionGeneration) return;
      _productIds
        ..clear()
        ..addAll(ids);
      state = FavoritesState(productIds: Set.from(_productIds));
    } on StaleSessionException {
      return;
    }
  }

  Future<void> toggle(String productId) async {
    if (_productIds.contains(productId)) {
      await StoreApiService.removeFavorite(productId);
      _productIds.remove(productId);
    } else {
      await StoreApiService.addFavorite(productId);
      _productIds.add(productId);
    }
    state = FavoritesState(productIds: Set.from(_productIds));
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
    state = ReviewsState(productReviews: Map.from(_productReviews));
  }

  Future<void> listenToReviews(String productId) async {
    final generation = AuthService().sessionGeneration;
    try {
      final rows = await StoreApiService.fetchReviews(productId);
      if (generation != AuthService().sessionGeneration) return;
      _productReviews[productId] = rows.map(Review.fromJson).toList();
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

  @override
  OrdersState build() {
    StorePollingService.onNewOrders = addOrdersFromPolling;
    return OrdersState(orders: [..._orders]);
  }

  void refresh() {
    state = state.copyWith(orders: [..._orders]);
  }

  void addOrder(Order order) {
    _orders.insert(0, order);
    CacheManager.instance.invalidate(CacheTags.orders);
    state = state.copyWith(orders: [..._orders]);
  }

  /// Loads the first page of orders from REST, replacing existing.
  Future<void> loadInitialOrders() async {
    _currentPage = 0;
    final rows = await StoreApiService.fetchOrdersPage(0, pageSize);
    final parsed = _parseOrders(rows);
    _orders
      ..clear()
      ..addAll(parsed);
    _cacheOrders();
    final hasMore = rows.length >= pageSize;
    state = state.copyWith(
      orders: [..._orders],
      isLoadingMore: false,
      hasMore: hasMore,
    );
  }

  /// Loads the next page of orders from REST and appends.
  Future<void> loadNextOrdersPage() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    _currentPage++;
    final rows = await StoreApiService.fetchOrdersPage(_currentPage, pageSize);
    final parsed = _parseOrders(rows);
    _orders.addAll(parsed);
    _cacheOrders();
    final hasMore = rows.length >= pageSize;
    state = state.copyWith(
      orders: [..._orders],
      isLoadingMore: false,
      hasMore: hasMore,
    );
  }

  void addOrdersFromPolling(List<Order> newOrders) {
    for (final order in newOrders) {
      if (!_orders.any((o) => o.id == order.id)) {
        _orders.insert(0, order);
      }
    }
    _cacheOrders();
    state = state.copyWith(orders: [..._orders]);
  }

  void _cacheOrders() {
    if (_orders.isNotEmpty) {
      CacheManager.instance.set(
        'orders:all',
        _orders.map((o) => o.toJson()).toList(),
        tags: [CacheTags.orders],
      );
    }
  }

  List<Order> _parseOrders(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      final m = StoreApiService.rowToOrderMap(row);
      return Order(
        id: m['id'] as String,
        userId: m['userId'] as String? ?? '',
        items:
            (m['items'] as List?)?.map((i) {
              final item = i as Map<String, dynamic>;
              return CartItem(
                product: Product(
                  id: item['productId']?.toString() ?? '',
                  name: item['productName']?.toString() ?? '',
                  description: '',
                  price: (item['price'] as num?)?.toDouble() ?? 0,
                  imageUrl: '',
                  categoryId: '',
                  categoryName: '',
                  stock: 0,
                  createdAt: DateTime.now(),
                ),
                quantity: (item['quantity'] as num?)?.toInt() ?? 1,
              );
            }).toList() ??
            [],
        status: _parseStatus(m['status']?.toString()),
        totalPrice: (m['totalPrice'] as num?)?.toDouble() ?? 0,
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
      );
    }).toList();
  }

  OrderStatus _parseStatus(String? s) {
    switch (s?.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'accepted':
        return OrderStatus.accepted;
      case 'preparing':
        return OrderStatus.preparing;
      case 'out_for_delivery':
      case 'outForDelivery':
        return OrderStatus.outForDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, OrdersState>(
  OrdersNotifier.new,
);
