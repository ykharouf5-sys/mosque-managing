import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/store/presentation/store_ui.dart';
import 'dart:io';

import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/shared/widgets/pagination_controls.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/store/presentation/product_detail_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/shared/widgets/app_cached_network_image.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';

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
  List<Product> _products = [];
  String? _studentAcademicYear;
  int _page = 1;
  int _lastPage = 1;
  int _requestGeneration = 0;
  bool _loading = true;
  static const int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _loadAcademicYear();
  }

  @override
  void dispose() {
    _requestGeneration++;
    super.dispose();
  }

  Future<void> _loadAcademicYear() async {
    final auth = AuthService();
    if (auth.role == 'student') {
      _studentAcademicYear = auth.academicYear;
    }
    await _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    if (page < 1 || (_lastPage > 0 && page > _lastPage)) return;
    final generation = ++_requestGeneration;
    if (mounted) setState(() => _loading = true);
    try {
      final result = await StoreApiService.fetchProductPage(
        page,
        _pageSize,
        categoryId: widget.categoryId,
        academicYear: _studentAcademicYear,
      );
      if (!mounted || generation != _requestGeneration) return;
      final categoryNames = {
        for (final category in ref.read(catalogProvider).categories)
          category.id: category.label,
      };
      final products = result.rows
          .map((row) {
            final item = StoreApiService.rowToProductMap(row);
            item['categoryName'] = categoryNames[item['categoryId']] ?? '';
            return Product.fromJson(item);
          })
          .toList(growable: false);
      setState(() {
        _products = products;
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final catalog = ref.watch(catalogProvider);
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
                storeUi('التصنيف غير موجود'),
                style: TextStyle(color: _kGrey, fontSize: 14.sp),
              ),
              SizedBox(height: 12.h),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(storeUi('العودة')),
              ),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: AppLocale.language == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: AppBottomNav(selectedIndex: 3),
        appBar: AppBar(
          title: Text(cat.label),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _loading && _products.isEmpty
            ? Center(child: CircularProgressIndicator())
            : _products.isEmpty
            ? _buildEmptyState(cat.label)
            : Column(
                children: [
                  Expanded(child: _buildProductGrid(context, _products)),
                  _buildPaginationControls(),
                ],
              ),
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
            AppLocale.text(
              'لا توجد منتجات في $categoryName',
              'No products in $categoryName',
            ),
            style: TextStyle(color: _kGrey, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(BuildContext context, List<Product> products) {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: GridView.builder(
        itemCount: products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemBuilder: (_, i) => _buildProductCard(context, products[i]),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
        child: PaginationControls(
          currentPage: _page,
          lastPage: _lastPage,
          loading: _loading,
          onPrevious: _page > 1 ? () => _loadPage(_page - 1) : null,
          onNext: _page < _lastPage ? () => _loadPage(_page + 1) : null,
        ),
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  width: double.infinity,
                  child:
                      product.listImageUrl.startsWith('/') ||
                          product.listImageUrl.contains(':\\')
                      ? Image.file(
                          File(product.listImageUrl),
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
                          url: product.listImageUrl,
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
                    storeUi('${product.price.toStringAsFixed(0)} SYP'),
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
