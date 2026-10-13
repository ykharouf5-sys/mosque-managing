import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/store/presentation/store_ui.dart';
import 'dart:io';

import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/store/presentation/product_purchase_bar.dart';
import 'package:studentry/shared/widgets/app_cached_network_image.dart';

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
    Localizations.localeOf(context);
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
      textDirection: AppLocale.language == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            storeUi('تفاصيل المنتج'),
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          centerTitle: true,
        ),
        bottomNavigationBar: ProductPurchaseBar(
          quantity: _quantity,
          inStock: product.inStock,
          onDecrease: _quantity > 1 ? () => setState(() => _quantity--) : null,
          onIncrease: _quantity < product.stock
              ? () => setState(() => _quantity++)
              : null,
          onAdd: () => _addToCart(product),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductImage(product, isFavorite),
              SizedBox(height: 20.h),
              _buildProductInfo(product),
              SizedBox(height: 16.h),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [_buildPrice(product), _buildStockStatus(product)],
              ),
              SizedBox(height: 14.h),
              _buildDescription(product),
              if (product.deliveryPrice > 0) ...[
                SizedBox(height: 12.h),
                Text(
                  AppLocale.text(
                    'رسوم التوصيل: ${_formatPrice(product.deliveryPrice)} SYP',
                    'Delivery fee: ${_formatPrice(product.deliveryPrice)} SYP',
                  ),
                  style: TextStyle(color: AppColors.textGray, fontSize: 13.sp),
                ),
              ],
              SizedBox(height: 32.h),
              _buildReviewsSection(product, reviews),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product, bool isFavorite) {
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
      imageWidget = AppCachedNetworkImage(
        url: product.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: () =>
            Icon(Icons.medical_services_outlined, color: _kGrey, size: 60.sp),
      );
    }
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 310.h,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
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
            onTap: () async {
              try {
                await ref
                    .read(favoritesProvider.notifier)
                    .toggle(widget.product.id, product: widget.product);
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocale.text(
                          'تعذر تحديث المفضلة: $error',
                          'Could not update favorites: $error',
                        ),
                      ),
                    ),
                  );
                }
              }
            },
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

  Widget _buildProductInfo(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.categoryName.isNotEmpty) ...[
          Text(
            product.categoryName,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
        ],
        Text(
          product.name,
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 22.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          product.brand,
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

  Widget _buildPrice(Product product) {
    return Text(
      storeUi('${_formatPrice(product.price)} SYP'),
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

  Widget _buildDescription(Product product) {
    if (product.description.trim().isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          storeUi('عن المنتج'),
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          product.description,
          style: TextStyle(
            color: AppColors.textGray,
            fontSize: 13.sp,
            height: 1.7,
          ),
        ),
      ],
    );
  }

  void _addToCart(Product product) {
    ref.read(cartProvider.notifier).addToCart(product, quantity: _quantity);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocale.text(
            'تمت إضافة $_quantity × ${product.name} إلى السلة',
            'Added $_quantity × ${product.name} to cart',
          ),
        ),
        backgroundColor: AppColors.primary,
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
              storeUi('نفد من المخزون'),
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
              AppLocale.text(
                'بقيت ${product.stock} قطع فقط',
                'Only ${product.stock} left',
              ),
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
            storeUi('متوفر في المخزون'),
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
                Icon(
                  Icons.rate_review_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 8.w),
                Text(
                  AppLocale.text(
                    'التقييمات (${product.reviewsCount})',
                    'Reviews (${product.reviewsCount})',
                  ),
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
              icon: Icon(Icons.add, size: 18),
              label: Text(
                storeUi('أضف تقييم'),
                style: TextStyle(fontSize: 13.sp),
              ),
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
                  storeUi('لا توجد تقييمات بعد'),
                  style: TextStyle(color: _kGrey, fontSize: 13.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  storeUi('كن أول من يقيم هذا المنتج'),
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
        textDirection: AppLocale.language == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              storeUi('أضف تقييمك'),
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  storeUi('التقييم'),
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
                    hintText: storeUi('اكتب تعليقك (اختياري)'),
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
                child: Text(storeUi('إلغاء')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () async {
                  if (commentC.text.trim().isEmpty) return;
                  try {
                    await ref
                        .read(reviewsProvider.notifier)
                        .addReview(
                          widget.product.id,
                          rating,
                          commentC.text.trim(),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (error) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocale.text(
                              'تعذر حفظ التقييم: $error',
                              'Could not save review: $error',
                            ),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text(storeUi('إرسال')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
