import 'dart:io';

import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';

const Color _kGrey = Color(0xFF9E9E9E);
const Color _kStarFilled = Color(0xFFFFC107);
const Color _kStarEmpty = Color(0xFFD9E6E8);
const Color _kQuantityBg = Color(0xFFF0F6F8);

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    ref.read(reviewsProvider.notifier).listenToReviews(widget.product.id);
  }

  @override
  void dispose() {
    ref.read(reviewsProvider.notifier).cancelReviewsListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref
        .watch(favoritesProvider)
        .isFavorite(widget.product.id);
    final updatedProduct = ref
        .watch(catalogProvider)
        .products
        .where((p) => p.id == widget.product.id)
        .firstOrNull;
    final product = updatedProduct ?? widget.product;
    final reviews = ref.watch(reviewsProvider).forProduct(widget.product.id);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'تفاصيل المنتج',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductImage(isFavorite),
              SizedBox(height: 20.h),
              _buildProductInfo(),
              SizedBox(height: 20.h),
              _buildPrice(),
              SizedBox(height: 14.h),
              _buildDescription(),
              SizedBox(height: 12.h),
              _buildStockStatus(product),
              SizedBox(height: 24.h),
              _buildQuantitySelector(),
              SizedBox(height: 24.h),
              _buildAddToCartButton(product),
              SizedBox(height: 32.h),
              _buildReviewsSection(product, reviews),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(bool isFavorite) {
    final product = widget.product;
    Widget imageWidget;
    if (product.imageUrl.isEmpty) {
      imageWidget = Icon(
        Icons.medical_services_outlined,
        color: _kGrey,
        size: 60.sp,
      );
    } else if (product.imageUrl.startsWith('/') ||
        product.imageUrl.contains(':\\')) {
      imageWidget = Image.file(
        File(product.imageUrl),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(Icons.medical_services_outlined, color: _kGrey, size: 60.sp),
      );
    } else {
      imageWidget = Image.network(
        product.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(Icons.medical_services_outlined, color: _kGrey, size: 60.sp),
      );
    }
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 280.h,
          decoration: BoxDecoration(
            color: _kQuantityBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: imageWidget,
          ),
        ),
        Positioned(
          top: 14.h,
          left: 14.w,
          child: GestureDetector(
            onTap: () =>
                ref.read(favoritesProvider.notifier).toggle(widget.product.id),
            child: Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: AppColors.primary,
                size: 22.sp,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductInfo() {
    final product = widget.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name,
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          product.brand.isNotEmpty ? product.brand : product.categoryName,
          style: TextStyle(
            color: _kGrey,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            _buildStarRating(product.rating),
            SizedBox(width: 8.w),
            Text(
              '${product.rating} (${product.reviewsCount})',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(Icons.star, color: _kStarFilled, size: 18.sp);
        } else if (i < rating) {
          return Icon(Icons.star_half, color: _kStarFilled, size: 18.sp);
        } else {
          return Icon(Icons.star, color: _kStarEmpty, size: 18.sp);
        }
      }),
    );
  }

  Widget _buildPrice() {
    return Text(
      '${_formatPrice(widget.product.price)} د.س',
      style: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.bold,
        fontSize: 24.sp,
      ),
    );
  }

  String _formatPrice(double price) {
    return price
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  Widget _buildDescription() {
    return Text(
      widget.product.description,
      style: TextStyle(color: _kGrey, fontSize: 13.sp, height: 1.7),
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: _kQuantityBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: AppColors.primary),
                onPressed: () {
                  if (_quantity > 1) setState(() => _quantity--);
                },
              ),
              SizedBox(
                width: 36.w,
                child: Text(
                  _quantity.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary),
                onPressed: () => setState(() => _quantity++),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddToCartButton(Product product) {
    final outOfStock = !product.inStock;
    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: outOfStock ? _kGrey : AppColors.primary,
          foregroundColor: AppColors.textLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: outOfStock
            ? null
            : () {
                ref
                    .read(cartProvider.notifier)
                    .addToCart(product, quantity: _quantity);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تمت إضافة $_quantity × ${product.name} إلى السلة',
                    ),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
        child: Text(
          outOfStock ? 'نفد من المخزون' : 'إضافة إلى السلة',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildStockStatus(Product product) {
    if (product.stock <= 0) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              'نفد من المخزون',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    if (product.stock <= 5) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.pending.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2, color: AppColors.pending, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              'بقيت ${product.stock} قطع فقط',
              style: TextStyle(
                color: AppColors.pending,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppColors.success,
            size: 18.sp,
          ),
          SizedBox(width: 8.w),
          Text(
            'متوفر في المخزون',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(Product product, List<Review> reviews) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 8.w),
                Text(
                  'التقييمات (${product.reviewsCount})',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _showAddReviewDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: Text('أضف تقييم', style: TextStyle(fontSize: 13.sp)),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 24.h),
            decoration: BoxDecoration(
              color: _kQuantityBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(Icons.rate_review_outlined, color: _kGrey, size: 32.sp),
                SizedBox(height: 8.h),
                Text(
                  'لا توجد تقييمات بعد',
                  style: TextStyle(color: _kGrey, fontSize: 13.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  'كن أول من يقيم هذا المنتج',
                  style: TextStyle(color: _kGrey, fontSize: 12.sp),
                ),
              ],
            ),
          )
        else
          ...reviews.map((r) => _buildReviewCard(r)),
      ],
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16.r,
                backgroundColor: AppColors.primarySurface,
                child: Text(
                  review.userName.isNotEmpty
                      ? review.userName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating.floor()
                              ? Icons.star
                              : Icons.star_border,
                          color: _kStarFilled,
                          size: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              review.comment,
              style: TextStyle(color: _kGrey, fontSize: 12.sp, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddReviewDialog() {
    double rating = 5;
    final commentC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'أضف تقييمك',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'التقييم',
                  style: TextStyle(color: _kGrey, fontSize: 13.sp),
                ),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= rating ? Icons.star : Icons.star_border,
                        color: _kStarFilled,
                        size: 36.sp,
                      ),
                      onPressed: () =>
                          setDialogState(() => rating = starIndex.toDouble()),
                    );
                  }),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: commentC,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'اكتب تعليقك (اختياري)',
                    filled: true,
                    fillColor: _kQuantityBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  ref
                      .read(reviewsProvider.notifier)
                      .addReview(
                        widget.product.id,
                        rating,
                        commentC.text.trim(),
                      );
                  setState(() {});
                  Navigator.pop(ctx);
                },
                child: const Text('إرسال'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
