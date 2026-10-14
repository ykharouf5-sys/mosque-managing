import 'package:studentry/utils/app_locale.dart';
import 'dart:convert';
import 'order_submission_result.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/shared/data/request_diagnostics.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:uuid/uuid.dart';

class StoreProductPage {
  final List<Map<String, dynamic>> rows;
  final int currentPage;
  final int lastPage;

  const StoreProductPage({
    required this.rows,
    required this.currentPage,
    required this.lastPage,
  });
}

class StoreApiService {
  static final _api = ApiClient.instance;
  static Map<String, dynamic>? _catalog;
  static String? _catalogEtag;
  static Future<Map<String, dynamic>>? _catalogRequest;
  static int? _catalogRequestGeneration;
  static int _catalogGeneration = 0;
  static DateTime? _catalogCheckedAt;

  static Future<Map<String, dynamic>> _loadCatalog({
    bool refresh = false,
    bool force = false,
  }) {
    if (_catalog != null &&
        !force &&
        _catalogCheckedAt != null &&
        DateTime.now().difference(_catalogCheckedAt!) <
            const Duration(minutes: 5)) {
      return Future.value(_catalog!);
    }
    final active = _catalogRequest;
    final generation = _catalogGeneration;
    if (active != null && _catalogRequestGeneration == generation) {
      return active;
    }
    late final Future<Map<String, dynamic>> request;
    request = _requestCatalog(refresh: refresh, generation: generation)
        .whenComplete(() {
          if (identical(_catalogRequest, request)) {
            _catalogRequest = null;
            _catalogRequestGeneration = null;
          }
        });
    _catalogRequestGeneration = generation;
    _catalogRequest = request;
    return request;
  }

  static void _invalidateCatalog() {
    _catalogGeneration++;
    _catalog = null;
    _catalogEtag = null;
    _catalogCheckedAt = null;
    _api.invalidateReads();
  }

  static void resetSession() => _invalidateCatalog();

  static Future<Map<String, dynamic>> fetchCatalogSummary({
    bool force = false,
  }) => _loadCatalog(refresh: true, force: force);

  static Future<Map<String, dynamic>> _requestCatalog({
    required bool refresh,
    required int generation,
  }) async {
    final etag = _catalogEtag;
    final r = await _api.get(
      '/store/catalog',
      reason: refresh ? RequestReason.automatic : RequestReason.navigation,
      query: const {'include_products': '0', 'locale': 'ar'},
      headers: {'If-None-Match': ?etag},
    );
    if (generation != _catalogGeneration) {
      throw const _StaleCatalogResponse();
    }
    _catalogCheckedAt = DateTime.now();
    if (r.statusCode == 304 && _catalog != null) return _catalog!;
    final oldVersion = _catalog?['version'];
    _catalog = Map<String, dynamic>.from(r.data['data'] as Map);
    if (oldVersion != _catalog!['version']) _api.invalidateReads();
    _catalogEtag = r.headers['etag'];
    return _catalog!;
  }

  static Future<void> refreshCatalog() async {
    await _loadCatalog(refresh: true, force: true);
  }

  static Future<List<Map<String, dynamic>>> fetchCategories() async =>
      _maps((await _loadCatalog())['categories']);
  static Future<List<Map<String, dynamic>>> fetchBanners() async =>
      _maps((await _loadCatalog())['banners']);
  static Future<List<Map<String, dynamic>>> fetchProducts() async =>
      _maps((await _loadCatalog())['products']);
  static Future<List<Map<String, dynamic>>> fetchProductsPage(
    int page,
    int pageSize, {
    String? search,
    String? categoryId,
    String? academicYear,
  }) async {
    final result = await fetchProductPage(
      page + 1,
      pageSize,
      search: search,
      categoryId: categoryId,
      academicYear: academicYear,
    );
    return result.rows;
  }

  static Future<StoreProductPage> fetchProductPage(
    int page,
    int pageSize, {
    String? search,
    String? categoryId,
    String? academicYear,
    bool force = false,
    RequestReason reason = RequestReason.navigation,
  }) async {
    final r = await _api.get(
      '/store/products',
      freshness: const Duration(minutes: 5),
      force: force,
      reason: reason,
      query: {
        'page': '$page',
        'per_page': '$pageSize',
        'locale': AppLocale.language,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (categoryId != null && categoryId.isNotEmpty)
          'category_id': categoryId,
        if (academicYear != null && academicYear.isNotEmpty)
          'academic_year': academicYear,
      },
    );
    final payload = Map<String, dynamic>.from(r.data['data'] as Map);
    return StoreProductPage(
      rows: _maps(payload['data']),
      currentPage: (payload['current_page'] as num?)?.toInt() ?? page,
      lastPage: (payload['last_page'] as num?)?.toInt() ?? 1,
    );
  }

  static Future<void> insertCategory(Map<String, dynamic> c) async {
    await _api.post(
      '/store/categories',
      body: {
        'id': c['id'] ?? const Uuid().v4(),
        'name': c['name'],
        'icon_url': c['iconUrl'] ?? c['icon_url'],
        if (c.containsKey('translations')) 'translations': c['translations'],
      },
    );
    _invalidateCatalog();
  }

  static Future<void> updateCategory(
    String id,
    String name,
    String iconUrl, {
    Map<String, dynamic>? translations,
  }) async {
    await _api.put(
      '/store/categories/$id',
      body: {'name': name, 'icon_url': iconUrl, 'translations': ?translations},
    );
    _invalidateCatalog();
  }

  static Future<void> deleteCategory(String id) async {
    await _api.delete('/store/categories/$id');
    _invalidateCatalog();
  }

  static Future<void> insertProduct(Map<String, dynamic> p) async {
    await _api.post('/store/products', body: _productPayload(p));
    _invalidateCatalog();
  }

  static Future<void> updateProduct(String id, Map<String, dynamic> p) async {
    await _api.put(
      '/store/products/$id',
      body: _productPayload(p, partial: true),
    );
    _invalidateCatalog();
  }

  static Future<void> deleteProduct(String id) async {
    await _api.delete('/store/products/$id');
    _invalidateCatalog();
  }

  static Future<void> insertBanner(Map<String, dynamic> b) async {
    await _api.post('/store/banners', body: _bannerPayload(b));
    _invalidateCatalog();
  }

  static Future<void> updateBanner(String id, Map<String, dynamic> b) async {
    await _api.put(
      '/store/banners/$id',
      body: _bannerPayload(b, partial: true),
    );
    _invalidateCatalog();
  }

  static Future<void> deleteBanner(String id) async {
    await _api.delete('/store/banners/$id');
    _invalidateCatalog();
  }

  static Future<List<Map<String, dynamic>>> fetchCoupons() async {
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final response = await _api.get(
        '/store/coupons',
        query: {'page': '$page', 'per_page': '50'},
      );
      final payload = Map<String, dynamic>.from(response.data['data'] as Map);
      rows.addAll(_maps(payload['data']));
      lastPage = (payload['last_page'] as num?)?.toInt() ?? page;
      page++;
    } while (page <= lastPage);
    return rows;
  }

  static Future<Map<String, dynamic>> insertCoupon(
    Map<String, dynamic> coupon,
  ) async {
    final response = await _api.post(
      '/store/coupons',
      body: _couponPayload(coupon, includeId: true),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> updateCoupon(
    String id,
    Map<String, dynamic> coupon,
  ) async {
    final response = await _api.put(
      '/store/coupons/$id',
      body: _couponPayload(coupon, includeId: false),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  static Future<void> deleteCoupon(String id) async {
    await _api.delete('/store/coupons/$id');
  }

  static Future<Map<String, dynamic>> validateCoupon(
    String code,
    List<Map<String, dynamic>> items,
  ) async {
    final response = await _api.post(
      '/store/coupons/validate',
      body: {'code': code, 'items': items},
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  static Future<Set<String>> fetchFavorites() async {
    final response = await _api.get('/store/favorites');
    return (response.data['data'] as List).map((id) => id.toString()).toSet();
  }

  static Future<void> addFavorite(String productId) async {
    await _api.put('/store/favorites/$productId');
  }

  static Future<void> removeFavorite(String productId) async {
    await _api.delete('/store/favorites/$productId');
  }

  static Future<List<Map<String, dynamic>>> fetchReviews(
    String productId,
  ) async {
    final response = await _api.get(
      '/store/products/$productId/reviews',
      query: const {'page': '1', 'per_page': '50'},
    );
    return _maps(response.data['data']);
  }

  static Future<Map<String, dynamic>> submitReview(
    String productId, {
    required String id,
    required int rating,
    required String comment,
  }) async {
    final response = await _api.post(
      '/store/products/$productId/reviews',
      body: {'id': id, 'rating': rating, 'comment': comment},
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  static Future<List<Map<String, dynamic>>> fetchOrdersSince(
    String since,
  ) async {
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final r = await _api.get(
        '/orders',
        query: {
          'since': since,
          'status': 'pending',
          'per_page': '25',
          'page': '$page',
        },
      );
      final payload = Map<String, dynamic>.from(r.data['data'] as Map);
      rows.addAll(_maps(payload['data']));
      lastPage = (payload['last_page'] as num?)?.toInt() ?? page;
      page++;
    } while (page <= lastPage);
    return rows;
  }

  static Future<List<Map<String, dynamic>>> fetchOrdersPage(
    int page,
    int pageSize, {
    String? status,
  }) async => (await fetchOrderPage(page, pageSize, status: status)).rows;

  static Future<
    ({List<Map<String, dynamic>> rows, String? serverTime, bool hasMore})
  >
  fetchOrderPage(int page, int pageSize, {String? status}) async {
    final q = {'page': '${page + 1}', 'per_page': '$pageSize'};
    if (status != null) q['status'] = status;
    final r = await _api.get(
      '/orders',
      query: q,
      reason: RequestReason.navigation,
    );
    final payload = r.data['data']['data'];
    return (
      rows: _maps(payload),
      serverTime: r.data['server_time'] as String?,
      hasMore:
          (r.data['data']['current_page'] as num) <
          (r.data['data']['last_page'] as num),
    );
  }

  /// Keyset change feed: keeps old loaded pages and downloads changed statuses
  /// even if their orders are no longer on page one. Never cache this feed.
  static Future<({List<Map<String, dynamic>> rows, String serverTime})>
  fetchOrderChanges(String since) async {
    final rows = <Map<String, dynamic>>[];
    String? cursor;
    String? until;
    final seenCursors = <String>{};
    do {
      final r = await _api.get(
        '/orders',
        reason: RequestReason.automatic,
        query: {
          'updated_since': since,
          'per_page': '25',
          'cursor': ?cursor,
          'sync_until': ?until,
        },
      );
      final serverTime = r.data['server_time'] as String?;
      if (serverTime == null ||
          DateTime.tryParse(serverTime) == null ||
          (until != null && serverTime != until)) {
        throw const FormatException('Invalid order sync boundary');
      }
      until = serverTime;
      rows.addAll(_maps(r.data['data']['data']));
      cursor = r.data['data']['next_cursor'] as String?;
      if (cursor != null && !seenCursors.add(cursor)) {
        throw const FormatException('Repeated order sync cursor');
      }
    } while (cursor != null);
    return (rows: rows, serverTime: until);
  }

  static Future<OrderSubmissionResult> createOrderSafe(
    Map<String, dynamic> order,
  ) async {
    try {
      final row = order.containsKey('total') ? order : orderToRow(order);
      final details = Map<String, dynamic>.from(row)
        ..removeWhere((k, v) => ['id', 'items', 'total', 'status'].contains(k));
      final r = await _api.post(
        '/orders',
        body: {
          'id': row['id'],
          'items': row['items'],
          'total': row['total'],
          'status': 'pending',
          'details': details,
        },
      );
      final payload = Map<String, dynamic>.from(r.data['data'] as Map);
      final confirmed = payload['order'];
      return OrderSubmissionResult(
        payload['result']?.toString() ?? 'error',
        confirmedOrder: confirmed is Map
            ? rowToOrderMap(Map<String, dynamic>.from(confirmed))
            : null,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        final details = e.details;
        final result = details is Map && details['data'] is Map
            ? details['data']['result']?.toString()
            : null;
        return OrderSubmissionResult(
          result == 'insufficient_stock'
              ? 'insufficient_stock'
              : 'invalid_order',
        );
      }
      if (e.statusCode == 422) {
        return const OrderSubmissionResult('invalid_order');
      }
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        return const OrderSubmissionResult('forbidden');
      }
      return OrderSubmissionResult('error', retryAfter: e.retryAfter);
    }
  }

  static Future<void> updateOrderStatus(String id, String status) async {
    await _api.patch('/orders/$id/status', body: {'status': status});
  }

  static Map<String, dynamic> rowToCategoryMap(Map<String, dynamic> r) => {
    'id': r['id'],
    'translations': r['translations'],
    'label': (r['translations'] as Map?)?['ar']?['name'] ?? r['name'],
    'iconUrl': r['icon_url'] ?? '',
    'productCount': r['products_count'],
    'name': (r['translations'] as Map?)?['ar']?['name'] ?? r['name'],
    'icon_url': r['icon_url'],
  };
  static Map<String, dynamic> rowToProductMap(Map<String, dynamic> r) => {
    'id': r['id'],
    'translations': r['translations'],
    'name': (r['translations'] as Map?)?['ar']?['name'] ?? r['name'],
    'publicationStatus': r['publication_status'] ?? 'published',
    'isTest': r['is_test'] == true,
    'brand': r['brand'] ?? '',
    'sourceName': r['source_name'],
    'description':
        (r['translations'] as Map?)?['ar']?['description'] ??
        r['description'] ??
        '',
    'imageUrl': r['image_url'] ?? '',
    'thumbnailUrl': r['thumbnail_url'],
    'categoryId': r['category_id'] ?? '',
    'categoryName': '',
    'price': _toDouble(r['price']),
    'rating': _toDouble(r['reviews_avg_rating']),
    'reviewsCount': _toInt(r['reviews_count']),
    'stock': _toInt(r['available_quantity'] ?? r['stock']),
    'physicalStock': _toInt(r['stock']),
    'createdAt': r['created_at'] ?? DateTime.now().toIso8601String(),
    'academicYear': r['academic_year'],
    'deliveryPrice': _toDouble(r['delivery_price']),
    'is_available': r['is_available'] == true || r['is_available'] == 1,
  };
  static Map<String, dynamic> rowToBannerMap(Map<String, dynamic> r) => {
    'id': r['id'],
    'translations': r['translations'],
    'title': r['title'] ?? '',
    'subtitle': r['subtitle'] ?? '',
    'discountText': r['discount_text'] ?? '',
    'imageUrl': r['image_url'] ?? '',
    'ctaText': r['cta_text'] ?? '',
    'actionRoute': r['action_route'] ?? '',
    'productId': r['product_id'],
    'categoryId': r['category_id'],
  };
  static Map<String, dynamic> rowToOrderMap(Map<String, dynamic> r) {
    final d = Map<String, dynamic>.from(r['details'] as Map? ?? {});
    return {
      ...d,
      'customer': r['customer'],
      'doctorName':
          (r['customer'] as Map?)?['full_name'] ??
          d['doctorName'] ??
          d['doctor_name'],
      'doctorPhone':
          (r['customer'] as Map?)?['phone'] ??
          d['doctorPhone'] ??
          d['doctor_phone'],
      'clinicAddress': d['clinic_address'] ?? d['clinicAddress'],
      'doctorGovernorate': d['doctor_governorate'] ?? d['doctorGovernorate'],
      'locationLatitude': d['location_latitude'] ?? d['locationLatitude'],
      'locationLongitude': d['location_longitude'] ?? d['locationLongitude'],
      'id': r['id'],
      'items': _normalizeOrderItems(r['items']),
      'totalPrice': _toDouble(r['total'] ?? r['totalPrice']),
      'status': r['status'] ?? 'pending',
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'] ?? r['created_at'],
      'userId': r['user_id'] ?? '',
      'deliveryPrice': _toDouble(d['delivery_price'] ?? d['deliveryPrice']),
      'discountAmount': _toDouble(d['discount_amount'] ?? d['discountAmount']),
      'couponCode': d['coupon_code'] ?? d['couponCode'],
      'shippingAddress': d['shipping_address'] ?? d['shippingAddress'],
      'paymentMethod': d['payment_method'] ?? d['paymentMethod'],
      'awaitingSync': false,
    };
  }

  static List<Map<String, dynamic>> _normalizeOrderItems(dynamic value) {
    final decoded = value is String ? jsonDecode(value) : value;
    if (decoded is! List) return const [];

    return decoded.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final nested = item['product'];
      final product = nested is Map
          ? Map<String, dynamic>.from(nested)
          : const <String, dynamic>{};
      final quantity = _toInt(item['quantity']);
      return <String, dynamic>{
        'product': <String, dynamic>{
          'id':
              product['id']?.toString() ??
              item['product_id']?.toString() ??
              item['productId']?.toString() ??
              '',
          'name':
              product['name']?.toString() ??
              item['product_name']?.toString() ??
              item['productName']?.toString() ??
              '',
          'translations':
              item['product_translations'] ?? product['translations'],
          'brand': product['brand']?.toString() ?? '',
          'sourceName': item['product_source_name'] ?? product['sourceName'],
          'description': product['description']?.toString() ?? '',
          'imageUrl':
              product['imageUrl']?.toString() ??
              product['image_url']?.toString() ??
              '',
          'categoryId':
              product['categoryId']?.toString() ??
              product['category_id']?.toString() ??
              '',
          'categoryName': product['categoryName']?.toString() ?? '',
          'price': _toDouble(
            product['price'] ?? item['unit_price'] ?? item['price'],
          ),
          'rating': _toDouble(product['rating']),
          'reviewsCount': _toInt(product['reviewsCount']),
          'stock': _toInt(product['stock']),
          'createdAt':
              product['createdAt']?.toString() ??
              DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
          if (product['academicYear'] != null)
            'academicYear': product['academicYear'],
          'deliveryPrice': _toDouble(product['deliveryPrice']),
        },
        'quantity': quantity > 0 ? quantity : 1,
      };
    }).toList();
  }

  static Map<String, dynamic> orderToRow(Map<String, dynamic> o) => {
    'id': o['id'],
    'clinic_id': AuthService().clinicId ?? '',
    'doctor_id': o['doctorId'] ?? o['doctor_id'] ?? AuthService().userId ?? '',
    'items': o['items'] is String ? jsonDecode(o['items']) : o['items'] ?? [],
    'total': (o['totalPrice'] as num?)?.toDouble() ?? 0,
    'status': o['status'] ?? 'pending',
    'notes': o['notes'],
    'coupon_code': o['couponCode'] ?? o['coupon_code'],
    'discount_amount': (o['discountAmount'] as num?)?.toDouble(),
    'shipping_address': o['shippingAddress'] ?? o['shipping_address'],
    'manager_approved': o['managerApproved'] ?? false,
    'approved_at': o['approvedAt'],
    'doctor_name': o['doctorName'],
    'doctor_phone': o['doctorPhone'],
    'clinic_address': o['clinicAddress'],
    'doctor_governorate': o['doctorGovernorate'],
    'payment_method': o['paymentMethod'],
    'delivery_price': (o['deliveryPrice'] as num?)?.toDouble() ?? 0,
    'phone': o['phone'],
    'governorate': o['governorate'],
    'region': o['region'],
    'location_latitude': o['locationLatitude'] ?? o['location_latitude'],
    'location_longitude': o['locationLongitude'] ?? o['location_longitude'],
  };
  static Map<String, dynamic> _productPayload(
    Map<String, dynamic> p, {
    bool partial = false,
  }) {
    final body = <String, dynamic>{
      'id': p['id'] ?? const Uuid().v4(),
      'category_id': p['categoryId'] ?? p['category_id'],
      'name': p['name'],
      'brand': p['brand'] ?? '',
      'description': p['description'] ?? '',
      'academic_year': p['academicYear'] ?? p['academic_year'],
      'price': (p['price'] as num?)?.toDouble() ?? 0,
      'delivery_price':
          (p['deliveryPrice'] as num?)?.toDouble() ??
          (p['delivery_price'] as num?)?.toDouble() ??
          0,
      'stock': (p['stock'] as num?)?.toInt() ?? 0,
      'image_url': p['imageUrl'] ?? p['image_url'] ?? '',
    };
    if (partial) {
      body.remove('id');
      const aliases = <String, List<String>>{
        'category_id': ['categoryId', 'category_id'],
        'name': ['name'],
        'brand': ['brand'],
        'description': ['description'],
        'academic_year': ['academicYear', 'academic_year'],
        'price': ['price'],
        'delivery_price': ['deliveryPrice', 'delivery_price'],
        'stock': ['stock'],
        'image_url': ['imageUrl', 'image_url'],
      };
      body.removeWhere(
        (key, _) => !(aliases[key]?.any(p.containsKey) ?? false),
      );
    }
    if (p.containsKey('sourceName') || p.containsKey('source_name')) {
      body['source_name'] = p['sourceName'] ?? p['source_name'];
    }
    if (p.containsKey('translations')) body['translations'] = p['translations'];
    if (p.containsKey('publicationStatus')) {
      body['publication_status'] = p['publicationStatus'];
    }
    if (p.containsKey('isTest')) body['is_test'] = p['isTest'];
    return body;
  }

  static Map<String, dynamic> _bannerPayload(
    Map<String, dynamic> b, {
    bool partial = false,
  }) {
    final body = <String, dynamic>{
      'id': b['id'] ?? const Uuid().v4(),
      'title': b['title'] ?? '',
      'subtitle': b['subtitle'] ?? '',
      'discount_text': b['discountText'] ?? b['discount_text'] ?? '',
      'image_url': b['imageUrl'] ?? b['image_url'] ?? '',
      'cta_text': b['ctaText'] ?? b['cta_text'] ?? '',
      'action_route': b['actionRoute'] ?? b['action_route'] ?? '',
      'product_id': b['productId'] ?? b['product_id'],
      'category_id': b['categoryId'] ?? b['category_id'],
    };
    if (partial) {
      body.remove('id');
      const aliases = <String, List<String>>{
        'title': ['title'],
        'subtitle': ['subtitle'],
        'discount_text': ['discountText', 'discount_text'],
        'image_url': ['imageUrl', 'image_url'],
        'cta_text': ['ctaText', 'cta_text'],
        'action_route': ['actionRoute', 'action_route'],
        'product_id': ['productId', 'product_id'],
        'category_id': ['categoryId', 'category_id'],
      };
      body.removeWhere(
        (key, _) => !(aliases[key]?.any(b.containsKey) ?? false),
      );
    }
    if (b.containsKey('translations')) body['translations'] = b['translations'];
    return body;
  }

  static Map<String, dynamic> _couponPayload(
    Map<String, dynamic> coupon, {
    required bool includeId,
  }) => {
    if (includeId) 'id': coupon['id'] ?? const Uuid().v4(),
    'code': coupon['code'],
    'description': coupon['description'] ?? '',
    'discount_type': coupon['discountType'] ?? coupon['discount_type'],
    'discount_value': coupon['discountValue'] ?? coupon['discount_value'],
    'min_purchase': coupon['minPurchase'] ?? coupon['min_purchase'],
    'expires_at': coupon['expiresAt'] ?? coupon['expires_at'],
    'is_active': coupon['isActive'] ?? coupon['is_active'] ?? true,
    'category_id': coupon['categoryId'] ?? coupon['category_id'],
    'product_id': coupon['productId'] ?? coupon['product_id'],
  };
  static List<Map<String, dynamic>> _maps(dynamic value) {
    final dynamic rows = value is Map ? value['data'] : value;
    if (rows is! List) return const [];
    return rows.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static double _toDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static int _toInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

class _StaleCatalogResponse implements Exception {
  const _StaleCatalogResponse();
}
