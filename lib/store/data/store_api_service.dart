import 'dart:convert';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:uuid/uuid.dart';

class StoreApiService {
  static final _api = ApiClient.instance;
  static Map<String, dynamic>? _catalog;
  static String? _catalogEtag;
  static Future<Map<String, dynamic>> _loadCatalog({
    bool refresh = false,
  }) async {
    if (_catalog != null && !refresh) return _catalog!;
    final r = await _api.get(
      '/store/catalog',
      headers: {
        if (refresh && _catalogEtag != null) 'If-None-Match': _catalogEtag!,
      },
    );
    if (r.statusCode == 304 && _catalog != null) return _catalog!;
    _catalog = Map<String, dynamic>.from(r.data['data']);
    _catalogEtag = r.headers['etag'];
    return _catalog!;
  }

  static Future<void> refreshCatalog() async {
    await _loadCatalog(refresh: true);
  }

  static Future<List<Map<String, dynamic>>> fetchCategories() async =>
      _maps((await _loadCatalog())['categories']);
  static Future<List<Map<String, dynamic>>> fetchBanners() async =>
      _maps((await _loadCatalog())['banners']);
  static Future<List<Map<String, dynamic>>> fetchProducts() async =>
      _maps((await _loadCatalog())['products']);
  static Future<List<Map<String, dynamic>>> fetchProductsPage(
    int page,
    int pageSize,
  ) async {
    final r = await _api.get(
      '/store/products',
      query: {'page': '${page + 1}', 'per_page': '$pageSize'},
    );
    return _maps(r.data['data']['data']);
  }

  static Future<void> insertCategory(Map<String, dynamic> c) async {
    await _api.post(
      '/store/categories',
      body: {
        'id': c['id'] ?? const Uuid().v4(),
        'name': c['name'],
        'icon_url': c['iconUrl'] ?? c['icon_url'],
      },
    );
    _catalog = null;
  }

  static Future<void> updateCategory(
    String id,
    String name,
    String iconUrl,
  ) async {
    await _api.put(
      '/store/categories/$id',
      body: {'name': name, 'icon_url': iconUrl},
    );
    _catalog = null;
  }

  static Future<void> deleteCategory(String id) async {
    await _api.delete('/store/categories/$id');
    _catalog = null;
  }

  static Future<void> insertProduct(Map<String, dynamic> p) async {
    await _api.post('/store/products', body: _productPayload(p));
    _catalog = null;
  }

  static Future<void> updateProduct(String id, Map<String, dynamic> p) async {
    await _api.put('/store/products/$id', body: _productPayload(p));
    _catalog = null;
  }

  static Future<void> deleteProduct(String id) async {
    await _api.delete('/store/products/$id');
    _catalog = null;
  }

  static Future<void> insertBanner(Map<String, dynamic> b) async {
    await _api.post('/store/banners', body: _bannerPayload(b));
    _catalog = null;
  }

  static Future<void> updateBanner(String id, Map<String, dynamic> b) async {
    await _api.put('/store/banners/$id', body: _bannerPayload(b));
    _catalog = null;
  }

  static Future<void> deleteBanner(String id) async {
    await _api.delete('/store/banners/$id');
    _catalog = null;
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
  }) async {
    final q = {'page': '${page + 1}', 'per_page': '$pageSize'};
    if (status != null) q['status'] = status;
    final r = await _api.get('/orders', query: q);
    return _maps(r.data['data']['data']);
  }

  static Future<String> createOrderSafe(Map<String, dynamic> order) async {
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
      return r.data['data']['result']?.toString() ?? 'error';
    } on ApiException catch (e) {
      if (e.statusCode == 409) return 'insufficient_stock';
      return 'error';
    }
  }

  static Future<void> updateOrderStatus(String id, String status) async {
    await _api.patch('/orders/$id/status', body: {'status': status});
  }

  static Map<String, dynamic> rowToCategoryMap(Map<String, dynamic> r) => {
    'id': r['id'],
    'label': r['name'],
    'iconUrl': r['icon_url'] ?? '',
    'name': r['name'],
    'icon_url': r['icon_url'],
  };
  static Map<String, dynamic> rowToProductMap(Map<String, dynamic> r) => {
    'id': r['id'],
    'name': r['name'],
    'brand': '',
    'description': r['description'] ?? '',
    'imageUrl': r['image_url'] ?? '',
    'categoryId': r['category_id'] ?? '',
    'categoryName': '',
    'price': _toDouble(r['price']),
    'rating': 0.0,
    'reviewsCount': 0,
    'stock': _toInt(r['stock']),
    'createdAt': r['created_at'] ?? DateTime.now().toIso8601String(),
    'deliveryPrice': 0.0,
    'is_available': r['is_available'] == true || r['is_available'] == 1,
  };
  static Map<String, dynamic> rowToBannerMap(Map<String, dynamic> r) => {
    'id': r['id'],
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
      'id': r['id'],
      'items': r['items'] ?? [],
      'totalPrice': (r['total'] as num?)?.toDouble() ?? 0,
      'status': r['status'] ?? 'pending',
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'] ?? r['created_at'],
      'userId': r['user_id'] ?? '',
      ...d,
    };
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
  };
  static Map<String, dynamic> _productPayload(Map<String, dynamic> p) => {
    'id': p['id'] ?? const Uuid().v4(),
    'category_id': p['categoryId'] ?? p['category_id'],
    'name': p['name'],
    'description': p['description'] ?? '',
    'price': (p['price'] as num?)?.toDouble() ?? 0,
    'stock': (p['stock'] as num?)?.toInt() ?? 0,
    'image_url': p['imageUrl'] ?? p['image_url'] ?? '',
  };
  static Map<String, dynamic> _bannerPayload(Map<String, dynamic> b) => {
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
