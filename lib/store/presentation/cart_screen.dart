import 'dart:io';

import 'package:dentalcare/shared/widgets/app_bottom_nav.dart';
import 'package:dentalcare/store/data/store_models.dart';
import 'package:dentalcare/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dentalcare/store/presentation/providers/store_providers.dart';

const Color _kGrey = Color(0xFF9E9E9E);

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _couponC = TextEditingController();
  final TextEditingController _addressC = TextEditingController();
  final TextEditingController _notesC = TextEditingController();

  @override
  void dispose() {
    _couponC.dispose();
    _addressC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _removeCoupon() {
    ref.read(cartProvider.notifier).removeCoupon();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartItems = cart.items;
    final cartTotal = cart.total;
    final appliedCoupon = cart.appliedCoupon;
    final discountAmount = cart.discountAmount;
    final discountedTotal = cart.discountedTotal;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: const AppBottomNav(selectedIndex: 3),
        appBar: AppBar(
          title: const Text('سلة المشتريات'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/my-orders'),
              child: Text(
                'طلباتي',
                style: TextStyle(color: AppColors.primary, fontSize: 13.sp),
              ),
            ),
          ],
        ),
        body: cartItems.isEmpty
            ? _buildEmptyCart()
            : _buildCartContent(
                cartItems,
                appliedCoupon,
                discountAmount,
                discountedTotal,
                cartTotal,
              ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, color: _kGrey, size: 64.sp),
          SizedBox(height: 16.h),
          Text(
            'السلة فارغة',
            style: TextStyle(color: _kGrey, fontSize: 18.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'أضف منتجات من المتجر',
            style: TextStyle(color: _kGrey, fontSize: 13.sp),
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('تسوق الآن'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(
    List<CartItem> cartItems,
    Coupon? appliedCoupon,
    double discountAmount,
    double discountedTotal,
    double cartTotal,
  ) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16.r),
            itemCount: cartItems.length,
            itemBuilder: (_, i) => _buildCartItemCard(
              cartItems[i],
              appliedCoupon,
              discountAmount,
              discountedTotal,
              cartTotal,
            ),
          ),
        ),
        _buildBottomBar(
          appliedCoupon,
          discountAmount,
          discountedTotal,
          cartTotal,
        ),
      ],
    );
  }

  Widget _buildCartItemCard(
    CartItem item,
    Coupon? appliedCoupon,
    double discountAmount,
    double discountedTotal,
    double cartTotal,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72.w,
                height: 72.h,
                child:
                    item.product.imageUrl.startsWith('/') ||
                        item.product.imageUrl.contains(':\\')
                    ? Image.file(
                        File(item.product.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.primarySurface,
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.primary,
                            size: 28.sp,
                          ),
                        ),
                      )
                    : Image.network(
                        item.product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.primarySurface,
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.primary,
                            size: 28.sp,
                          ),
                        ),
                      ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${item.product.price.toStringAsFixed(0)} ر.س',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      _buildQuantityButton(
                        icon: Icons.remove,
                        onTap: () {
                          if (item.quantity <= 1) {
                            ref
                                .read(cartProvider.notifier)
                                .removeFromCart(item.product.id);
                          } else {
                            ref
                                .read(cartProvider.notifier)
                                .updateQuantity(
                                  item.product.id,
                                  item.quantity - 1,
                                );
                          }
                        },
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        '${item.quantity}',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      _buildQuantityButton(
                        icon: Icons.add,
                        onTap: () {
                          ref
                              .read(cartProvider.notifier)
                              .updateQuantity(
                                item.product.id,
                                item.quantity + 1,
                              );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => ref
                  .read(cartProvider.notifier)
                  .removeFromCart(item.product.id),
              child: Padding(
                padding: EdgeInsets.only(right: 4.w),
                child: Icon(Icons.close, color: _kGrey, size: 20.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30.w,
        height: 30.h,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18.sp),
      ),
    );
  }

  Widget _buildBottomBar(
    Coupon? appliedCoupon,
    double discountAmount,
    double discountedTotal,
    double cartTotal,
  ) {
    final hasDiscount = appliedCoupon != null && discountAmount > 0;
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (appliedCoupon != null)
              Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'كود الخصم ${appliedCoupon.code}',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _removeCoupon,
                      child: Icon(Icons.close, color: _kGrey, size: 18.sp),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'المجموع',
                        style: TextStyle(color: _kGrey, fontSize: 12.sp),
                      ),
                      SizedBox(height: 4.h),
                      if (hasDiscount)
                        Row(
                          children: [
                            Text(
                              '${cartTotal.toStringAsFixed(0)} ر.س',
                              style: TextStyle(
                                color: _kGrey,
                                fontSize: 16.sp,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              '-${discountAmount.toStringAsFixed(0)} ر.س',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: hasDiscount ? 2.h : 0),
                      Text(
                        '${(hasDiscount ? discountedTotal : cartTotal).toStringAsFixed(0)} ر.س',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    padding: EdgeInsets.symmetric(
                      horizontal: 32.w,
                      vertical: 16.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/order-confirmation'),
                  child: Text('إتمام الطلب', style: TextStyle(fontSize: 15.sp)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
