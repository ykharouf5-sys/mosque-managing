import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/store/presentation/store_ui.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/presentation/product_detail_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/shared/widgets/app_cached_network_image.dart';

const Color _kGrey = Color(0xFF9E9E9E);

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final products = ref.watch(catalogProvider).products;
    final favorites = ref.watch(favoritesProvider);
    final items = favorites.productIds
        .map((id) {
          for (final product in products) {
            if (product.id == id) return product;
          }
          return favorites.savedProducts[id];
        })
        .whereType<Product>()
        .toList();

    return Directionality(
      textDirection: AppLocale.language == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(storeUi('المفضلة')),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        bottomNavigationBar: AppBottomNav(selectedIndex: -1),
        body: items.isEmpty ? _buildEmpty() : _buildList(items),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, color: _kGrey, size: 64.sp),
          SizedBox(height: 16.h),
          Text(
            storeUi('لا توجد منتجات مفضلة'),
            style: TextStyle(color: _kGrey, fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            storeUi('أضف منتجات إلى المفضلة'),
            style: TextStyle(color: _kGrey, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Product> products) {
    return ListView.builder(
      padding: EdgeInsets.all(16.r),
      itemCount: products.length,
      itemBuilder: (_, i) => _buildItem(products[i]),
    );
  }

  Widget _buildItem(Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(product: product),
        ),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
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
                  width: 64.w,
                  height: 64.h,
                  child: AppCachedNetworkImage(
                    url: product.listImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: () => Container(
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
                      product.name,
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
                      product.brand.isNotEmpty
                          ? product.brand
                          : product.categoryName,
                      style: TextStyle(color: _kGrey, fontSize: 12.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      storeUi('${product.price.toStringAsFixed(0)} SYP'),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  try {
                    await ref
                        .read(favoritesProvider.notifier)
                        .toggle(product.id, product: product);
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
                child: Icon(
                  Icons.favorite,
                  color: AppColors.primary,
                  size: 24.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
