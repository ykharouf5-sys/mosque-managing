import 'package:dentalcare/shared/widgets/app_bottom_nav.dart';
import 'package:dentalcare/shared/widgets/app_drawer.dart';
import 'package:dentalcare/store/data/store_models.dart';
import 'package:dentalcare/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dentalcare/store/presentation/providers/store_providers.dart';

const Color _kGrey = Color(0xFF9E9E9E);
const Color _kDivider = Color(0xFFE0E0E0);

class AllCategoriesScreen extends ConsumerStatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  ConsumerState<AllCategoriesScreen> createState() =>
      _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends ConsumerState<AllCategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final cartItemCount = ref.watch(cartProvider).itemCount;
    final categories = catalog.categories;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: const AppDrawer(),
        bottomNavigationBar: const AppBottomNav(selectedIndex: 3),
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textDark),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: Text(
            'التصنيفات',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          centerTitle: true,
          actions: [
            Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: IconButton(
                    icon: Icon(
                      Icons.shopping_cart_outlined,
                      color: AppColors.primary,
                      size: 26.sp,
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/cart'),
                  ),
                ),
                if (cartItemCount > 0)
                  Positioned(
                    right: 8.w,
                    top: 6.h,
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 18.w,
                        minHeight: 18.h,
                      ),
                      child: Text(
                        cartItemCount.toString(),
                        style: TextStyle(
                          color: AppColors.surface,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: categories.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => setState(() {}),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 16.h,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const Divider(
                        color: _kDivider,
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (_, i) => _buildCategoryRow(categories[i]),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCategoryRow(ProductCategory category) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/category-products',
        arguments: category.id,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Row(
          children: [
            category.iconUrl.endsWith('.svg')
                ? SvgPicture.network(
                    category.iconUrl,
                    colorFilter: const ColorFilter.mode(
                      AppColors.primary,
                      BlendMode.srcIn,
                    ),
                    width: 24.w,
                    height: 24.h,
                  )
                : Image.network(
                    category.iconUrl,
                    width: 24.w,
                    height: 24.h,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.category_outlined,
                      color: AppColors.primary,
                      size: 24.sp,
                    ),
                  ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (category.productCount != null)
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        '${category.productCount} منتج',
                        style: TextStyle(color: _kGrey, fontSize: 12.sp),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: _kGrey, size: 22.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, color: _kGrey, size: 48.sp),
          SizedBox(height: 12.h),
          Text(
            'لا توجد تصنيفات متاحة حالياً',
            style: TextStyle(color: _kGrey, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}
