import 'dart:io';

import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/presentation/product_detail_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/shared/widgets/app_cached_network_image.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/shared/providers/auth_provider.dart';

const Color _kGrey = Color(0xFF9E9E9E);

class CategoryProductsScreen extends ConsumerStatefulWidget {
  final String categoryId;
  const CategoryProductsScreen({super.key, required this.categoryId});

  @override
  ConsumerState<CategoryProductsScreen> createState() =>
      _CategoryProductsScreenState();
}

class _CategoryProductsScreenState
    extends ConsumerState<CategoryProductsScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _studentAcademicYear;

  @override
  void initState() {
    super.initState();
    _loadAcademicYear();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final catalog = ref.read(catalogProvider);
    if (!catalog.isLoadingProducts &&
        catalog.hasMoreProducts &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      ref.read(catalogProvider.notifier).loadNextProductsPage();
    }
  }

  Future<void> _loadAcademicYear() async {
    if (ref.read(authProvider).role == 'student') {
      _studentAcademicYear = null;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final role = ref.watch(authProvider).role;
    final cat = catalog.categories
        .where((c) => c.id == widget.categoryId)
        .firstOrNull;

    if (cat == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_outlined, color: _kGrey, size: 48.sp),
              SizedBox(height: 12.h),
              Text(
                'التصنيف غير موجود',
                style: TextStyle(color: _kGrey, fontSize: 14.sp),
              ),
              SizedBox(height: 12.h),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('العودة'),
              ),
            ],
          ),
        ),
      );
    }

    final catProducts = ref
        .read(catalogProvider.notifier)
        .getProductsByCategory(widget.categoryId);
    List<Product> products;
    if (role == 'student' && _studentAcademicYear != null) {
      products = catProducts
          .where(
            (p) =>
                p.academicYear == _studentAcademicYear ||
                p.academicYear == null,
          )
          .toList();
    } else {
      products = catProducts;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: const AppBottomNav(selectedIndex: 3),
        appBar: AppBar(
          title: Text(cat.label),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: products.isEmpty
            ? _buildEmptyState(cat.label)
            : _buildProductGrid(context, products, catalog),
      ),
    );
  }

  Widget _buildEmptyState(String categoryName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, color: _kGrey, size: 48.sp),
          SizedBox(height: 12.h),
          Text(
            'لا توجد منتجات في $categoryName',
            style: TextStyle(color: _kGrey, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(
    BuildContext context,
    List<Product> products,
    CatalogState catalog,
  ) {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: GridView.builder(
        controller: _scrollController,
        itemCount: products.length + (catalog.isLoadingProducts ? 1 : 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemBuilder: (_, i) {
          if (i >= products.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildProductCard(context, products[i]);
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(product: product),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child:
                      product.imageUrl.startsWith('/') ||
                          product.imageUrl.contains(':\\')
                      ? Image.file(
                          File(product.imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.primarySurface,
                            child: Icon(
                              Icons.image_outlined,
                              color: AppColors.primary,
                              size: 32.sp,
                            ),
                          ),
                        )
                      : AppCachedNetworkImage(
                          url: product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: () => Container(
                            color: AppColors.primarySurface,
                            child: Icon(
                              Icons.image_outlined,
                              color: AppColors.primary,
                              size: 32.sp,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${product.price.toStringAsFixed(0)} ر.س',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
