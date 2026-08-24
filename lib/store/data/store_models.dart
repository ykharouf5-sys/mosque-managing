class PromoBanner {
  final String id,
      title,
      subtitle,
      discountText,
      imageUrl,
      ctaText,
      actionRoute;
  final String? productId;
  final String? categoryId;
  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.discountText,
    required this.imageUrl,
    required this.ctaText,
    required this.actionRoute,
    this.productId,
    this.categoryId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'discountText': discountText,
    'imageUrl': imageUrl,
    'ctaText': ctaText,
    'actionRoute': actionRoute,
    if (productId != null) 'productId': productId,
    if (categoryId != null) 'categoryId': categoryId,
  };

  factory PromoBanner.fromJson(Map<String, dynamic> json) => PromoBanner(
    id: json['id'] as String,
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
  final String id, label, iconUrl;
  int? productCount;
  ProductCategory({
    required this.id,
    required this.label,
    required this.iconUrl,
    this.productCount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'iconUrl': iconUrl,
  };

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(
        id: json['id'] as String,
        label: json['label'] as String,
        iconUrl: json['iconUrl'] as String,
      );
}

class Product {
  final String id, name, description, imageUrl, categoryId, categoryName;
  final double price, rating;
  final int reviewsCount, stock;
  final DateTime createdAt;
  final String brand;
  final String? academicYear;
  final double deliveryPrice;
  Product({
    required this.id,
    required this.name,
    this.brand = '',
    required this.description,
    required this.imageUrl,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.stock = 0,
    required this.createdAt,
    this.academicYear,
    this.deliveryPrice = 0.0,
  });

  bool get inStock => stock > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'description': description,
    'imageUrl': imageUrl,
    'categoryId': categoryId,
    'categoryName': categoryName,
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
    name: json['name'] as String,
    brand: (json['brand'] as String?) ?? '',
    description: json['description'] as String,
    imageUrl: json['imageUrl'] as String,
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
  cancelled,
}

String orderStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 'قيد الانتظار';
    case OrderStatus.accepted:
      return 'مقبول';
    case OrderStatus.preparing:
      return 'قيد التحضير';
    case OrderStatus.outForDelivery:
      return 'خرج للتوصيل';
    case OrderStatus.delivered:
      return 'تم التسليم';
    case OrderStatus.cancelled:
      return 'ملغي';
  }
}

class Order {
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

  Order({
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
  });

  Map<String, dynamic> toJson() => {
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
  };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    items: (json['items'] as List)
        .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
        .toList(),
    totalPrice: (json['totalPrice'] as num).toDouble(),
    status: OrderStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => OrderStatus.pending,
    ),
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
