// ignore_for_file: prefer_initializing_formals
import 'package:studentry/utils/app_locale.dart';
import 'catalog_translations.dart';

class PromoBanner {
  final String id,
      _title,
      _subtitle,
      _discountText,
      _imageUrl,
      _ctaText,
      actionRoute;
  final CatalogCopy translations;
  String get title => AppLocale.catalogText(translations, "title", _title);
  String get subtitle =>
      AppLocale.catalogText(translations, "subtitle", _subtitle);
  String get discountText =>
      AppLocale.catalogText(translations, "discount_text", _discountText);
  String get ctaText =>
      AppLocale.catalogText(translations, "cta_text", _ctaText);
  String get imageUrl =>
      AppLocale.catalogText(translations, "image_url", _imageUrl);
  final String? productId;
  final String? categoryId;
  const PromoBanner({
    required this.id,
    required String title,
    required String subtitle,
    required String discountText,
    required String imageUrl,
    required String ctaText,
    required this.actionRoute,
    this.productId,
    this.categoryId,
    this.translations = const {},
  }) : _title = title,
       _subtitle = subtitle,
       _discountText = discountText,
       _imageUrl = imageUrl,
       _ctaText = ctaText;

  Map<String, dynamic> toJson() => {
    'id': id,
    'translations': translations,
    'title': _title,
    'subtitle': _subtitle,
    'discountText': _discountText,
    'imageUrl': _imageUrl,
    'ctaText': _ctaText,
    'actionRoute': actionRoute,
    if (productId != null) 'productId': productId,
    if (categoryId != null) 'categoryId': categoryId,
  };

  factory PromoBanner.fromJson(Map<String, dynamic> json) => PromoBanner(
    id: json['id'] as String,
    translations: parseCatalogCopy(json['translations']),
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    discountText: json['discountText'] as String,
    imageUrl: json['imageUrl'] as String,
    ctaText: json['ctaText'] as String,
    actionRoute: json['actionRoute'] as String,
    productId: json['productId'] as String?,
    categoryId: json['categoryId'] as String?,
  );
}

class Coupon {
  final String id, code, description, discountType;
  final double discountValue;
  final double? minPurchase;
  final DateTime? expiresAt;
  final bool isActive;
  final String? productId;
  final String? categoryId;
  const Coupon({
    required this.id,
    required this.code,
    required this.description,
    required this.discountType,
    required this.discountValue,
    this.minPurchase,
    this.expiresAt,
    this.isActive = true,
    this.productId,
    this.categoryId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'description': description,
    'discountType': discountType,
    'discountValue': discountValue,
    if (minPurchase != null) 'minPurchase': minPurchase,
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    'isActive': isActive,
    if (productId != null) 'productId': productId,
    if (categoryId != null) 'categoryId': categoryId,
  };

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
    id: json['id'] as String,
    code: json['code'] as String,
    description: json['description'] as String,
    discountType: json['discountType'] as String,
    discountValue: (json['discountValue'] as num).toDouble(),
    minPurchase: (json['minPurchase'] as num?)?.toDouble(),
    expiresAt: json['expiresAt'] != null
        ? DateTime.parse(json['expiresAt'] as String)
        : null,
    isActive: json['isActive'] as bool? ?? true,
    productId: json['productId'] as String?,
    categoryId: json['categoryId'] as String?,
  );
}

class ProductCategory {
  final String id, _label, iconUrl;
  final CatalogCopy translations;
  String get label => AppLocale.catalogText(translations, "name", _label);
  int? productCount;
  ProductCategory({
    required this.id,
    required String label,
    required this.iconUrl,
    this.productCount,
    this.translations = const {},
  }) : _label = label;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': _label,
    'translations': translations,
    'iconUrl': iconUrl,
    if (productCount != null) 'productCount': productCount,
  };

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(
        id: json['id'] as String,
        translations: parseCatalogCopy(json['translations']),
        label: json['label'] as String,
        iconUrl: json['iconUrl'] as String,
        productCount: (json['productCount'] as num?)?.toInt(),
      );
}

class Product {
  final String id, _name, _description, imageUrl, categoryId, _categoryName;
  final CatalogCopy translations, categoryTranslations;
  final String publicationStatus;
  final bool isTest;
  String get name => AppLocale.catalogText(translations, "name", _name);
  String get description =>
      AppLocale.catalogText(translations, "description", _description);
  String get categoryName =>
      AppLocale.catalogText(categoryTranslations, "name", _categoryName);
  final double price, rating;
  final int reviewsCount, stock;
  final DateTime createdAt;
  final String brand;
  final String? academicYear;
  final double deliveryPrice;
  final String? thumbnailUrl;
  final int? physicalStock;
  String get listImageUrl =>
      thumbnailUrl?.isNotEmpty == true ? thumbnailUrl! : imageUrl;
  Product({
    required this.id,
    required String name,
    this.brand = '',
    required String description,
    required this.imageUrl,
    required this.categoryId,
    required String categoryName,
    required this.price,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.stock = 0,
    required this.createdAt,
    this.academicYear,
    this.deliveryPrice = 0.0,
    this.thumbnailUrl,
    this.physicalStock,
    this.translations = const {},
    this.categoryTranslations = const {},
    this.publicationStatus = 'published',
    this.isTest = false,
  }) : _name = name,
       _description = description,
       _categoryName = categoryName;

  bool get inStock => stock > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'translations': translations,
    'categoryTranslations': categoryTranslations,
    'publicationStatus': publicationStatus,
    'isTest': isTest,
    'name': _name,
    'brand': brand,
    'description': _description,
    'imageUrl': imageUrl,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (physicalStock != null) 'physicalStock': physicalStock,
    'categoryId': categoryId,
    'categoryName': _categoryName,
    'price': price,
    'rating': rating,
    'reviewsCount': reviewsCount,
    'stock': stock,
    'createdAt': createdAt.toIso8601String(),
    if (academicYear != null) 'academicYear': academicYear,
    if (deliveryPrice > 0) 'deliveryPrice': deliveryPrice,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    translations: parseCatalogCopy(json['translations']),
    categoryTranslations: parseCatalogCopy(json['categoryTranslations']),
    publicationStatus: json['publicationStatus'] as String? ?? 'published',
    isTest: json['isTest'] == true,
    name: json['name'] as String,
    brand: (json['brand'] as String?) ?? '',
    description: json['description'] as String,
    imageUrl: json['imageUrl'] as String,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    physicalStock: (json['physicalStock'] as num?)?.toInt(),
    categoryId: json['categoryId'] as String,
    categoryName: json['categoryName'] as String,
    price: (json['price'] as num).toDouble(),
    rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    reviewsCount: (json['reviewsCount'] as int?) ?? 0,
    stock: (json['stock'] as int?) ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    academicYear: json['academicYear'] as String?,
    deliveryPrice: (json['deliveryPrice'] as num?)?.toDouble() ?? 0.0,
  );
}

enum OrderStatus {
  pending,
  accepted,
  preparing,
  outForDelivery,
  delivered,
  rejected,
  cancelled,
}

OrderStatus orderStatusFromWire(String? value) {
  switch (value?.toLowerCase()) {
    case 'accepted':
    case 'approved':
      return OrderStatus.accepted;
    case 'preparing':
    case 'processing':
      return OrderStatus.preparing;
    case 'out_for_delivery':
    case 'outfordelivery':
    case 'shipped':
      return OrderStatus.outForDelivery;
    case 'delivered':
      return OrderStatus.delivered;
    case 'rejected':
      return OrderStatus.rejected;
    case 'cancelled':
      return OrderStatus.cancelled;
    default:
      return OrderStatus.pending;
  }
}

String orderStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return AppLocale.text('قيد الانتظار', 'Pending');
    case OrderStatus.accepted:
      return AppLocale.text('مقبول', 'Accepted');
    case OrderStatus.preparing:
      return AppLocale.text('قيد التحضير', 'Preparing');
    case OrderStatus.outForDelivery:
      return AppLocale.text('خرج للتوصيل', 'Out for delivery');
    case OrderStatus.delivered:
      return AppLocale.text('تم التسليم', 'Delivered');
    case OrderStatus.rejected:
      return AppLocale.text('مرفوض', 'Rejected');
    case OrderStatus.cancelled:
      return AppLocale.text('ملغي', 'Cancelled');
  }
}

class Order {
  final bool awaitingSync;
  final String? submissionError;
  final String id;
  final List<CartItem> items;
  final double totalPrice;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final String? notes;
  final String? couponCode;
  final double? discountAmount;
  final String? shippingAddress;
  final bool managerApproved;
  final DateTime? approvedAt;
  final String? doctorName;
  final String? doctorPhone;
  final String? clinicAddress;
  final String? doctorGovernorate;
  final String? paymentMethod;
  final double deliveryPrice;
  final String? phone;
  final String? governorate;
  final String? region;
  final double? locationLatitude;
  final double? locationLongitude;

  Order({
    this.awaitingSync = false,
    this.submissionError,
    required this.id,
    required this.items,
    required this.totalPrice,
    this.status = OrderStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    this.notes,
    this.couponCode,
    this.discountAmount,
    this.shippingAddress,
    this.managerApproved = false,
    this.approvedAt,
    this.doctorName,
    this.doctorPhone,
    this.clinicAddress,
    this.doctorGovernorate,
    this.paymentMethod,
    this.deliveryPrice = 0.0,
    this.phone,
    this.governorate,
    this.region,
    this.locationLatitude,
    this.locationLongitude,
  });

  Map<String, dynamic> toJson() => {
    'awaitingSync': awaitingSync,
    if (submissionError != null) 'submissionError': submissionError,
    'id': id,
    'items': items.map((i) => i.toJson()).toList(),
    'totalPrice': totalPrice,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'userId': userId,
    if (notes != null) 'notes': notes,
    if (couponCode != null) 'couponCode': couponCode,
    if (discountAmount != null) 'discountAmount': discountAmount,
    if (shippingAddress != null) 'shippingAddress': shippingAddress,
    'managerApproved': managerApproved,
    if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
    if (doctorName != null) 'doctorName': doctorName,
    if (doctorPhone != null) 'doctorPhone': doctorPhone,
    if (clinicAddress != null) 'clinicAddress': clinicAddress,
    if (doctorGovernorate != null) 'doctorGovernorate': doctorGovernorate,
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
    if (deliveryPrice > 0) 'deliveryPrice': deliveryPrice,
    if (phone != null) 'phone': phone,
    if (governorate != null) 'governorate': governorate,
    if (region != null) 'region': region,
    if (locationLatitude != null) 'locationLatitude': locationLatitude,
    if (locationLongitude != null) 'locationLongitude': locationLongitude,
  };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    awaitingSync: json['awaitingSync'] == true,
    submissionError: json['submissionError'] as String?,
    id: json['id'] as String,
    items: (json['items'] as List)
        .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
        .toList(),
    totalPrice: (json['totalPrice'] as num).toDouble(),
    status: orderStatusFromWire(json['status']?.toString()),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    userId: json['userId'] as String,
    notes: json['notes'] as String?,
    couponCode: json['couponCode'] as String?,
    discountAmount: (json['discountAmount'] as num?)?.toDouble(),
    shippingAddress: json['shippingAddress'] as String?,
    managerApproved: (json['managerApproved'] as bool?) ?? false,
    approvedAt: json['approvedAt'] != null
        ? DateTime.parse(json['approvedAt'] as String)
        : null,
    doctorName: json['doctorName'] as String?,
    doctorPhone: json['doctorPhone'] as String?,
    clinicAddress: json['clinicAddress'] as String?,
    doctorGovernorate: json['doctorGovernorate'] as String?,
    paymentMethod: json['paymentMethod'] as String?,
    deliveryPrice: (json['deliveryPrice'] as num?)?.toDouble() ?? 0.0,
    phone: json['phone'] as String?,
    governorate: json['governorate'] as String?,
    region: json['region'] as String?,
    locationLatitude:
        ((json['locationLatitude'] ?? json['location_latitude']) as num?)
            ?.toDouble(),
    locationLongitude:
        ((json['locationLongitude'] ?? json['location_longitude']) as num?)
            ?.toDouble(),
  );
}

class Review {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'userId': userId,
    'userName': userName,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String,
    productId: json['productId'] as String,
    userId: json['userId'] as String,
    userName: json['userName'] as String,
    rating: (json['rating'] as num).toDouble(),
    comment: json['comment'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});

  double get totalPrice => product.price * quantity;

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    product: Product.fromJson(json['product'] as Map<String, dynamic>),
    quantity: json['quantity'] as int,
  );
}
