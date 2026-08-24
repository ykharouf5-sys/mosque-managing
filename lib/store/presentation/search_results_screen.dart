import 'dart:io';

import 'package:dentalcare/shared/widgets/app_bottom_nav.dart';
import 'package:dentalcare/store/data/store_models.dart';
import 'package:dentalcare/store/presentation/product_detail_screen.dart';
import 'package:dentalcare/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dentalcare/store/presentation/providers/store_providers.dart';
import 'package:dentalcare/shared/providers/auth_provider.dart';

const Color _kGrey = Color(0xFF9E9E9E);

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;
  const SearchResultsScreen({super.key, required this.query});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late TextEditingController _searchController;
  late List<Product> _results;
  String? _studentAcademicYear;

  @override
  void initState() {
    super.initState();
    _loadAcademicYear();
    _searchController = TextEditingController(text: widget.query);
  }

  Future<void> _loadAcademicYear() async {
    if (ref.read(authProvider).role == 'student') {
      _studentAcademicYear = null;
    }
    _filter(widget.query);
  }

  List<Product> _allProducts(List<Product> products, String? role) {
    if (role == 'student' && _studentAcademicYear != null) {
      return ref
          .read(catalogProvider.notifier)
          .getProductsByAcademicYear(_studentAcademicYear);
    }
    return products;
  }

  void _filter(String query) {
    final catalog = ref.read(catalogProvider);
    final role = ref.read(authProvider).role;
    final allProducts = _allProducts(catalog.products, role);
    final q = query.trim().toLowerCase();
    setState(() {
      _results = q.isEmpty
          ? List.from(allProducts)
          : allProducts.where((p) => p.name.toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: const AppBottomNav(selectedIndex: 3),
        body: Column(
          children: [
            _buildSearchBar(),
            if (_results.isEmpty)
              Expanded(child: _buildEmptyState())
            else
              Expanded(child: _buildProductGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8.h,
        left: 16.w,
        right: 16.w,
        bottom: 8.h,
      ),
      color: AppColors.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _filter,
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  hintStyle: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 13.sp,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
                    onPressed: () => _filter(_searchController.text),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, color: _kGrey, size: 48.sp),
          SizedBox(height: 12.h),
          Text(
            'لا توجد نتائج لـ "${widget.query}"',
            style: TextStyle(color: _kGrey, fontSize: 14.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'جرب البحث بكلمة أخرى',
            style: TextStyle(color: _kGrey, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: GridView.builder(
        itemCount: _results.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemBuilder: (_, i) => _buildProductCard(_results[i]),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
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
                  child: product.imageUrl.isEmpty
                      ? Container(
                          color: AppColors.primarySurface,
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.primary,
                            size: 32.sp,
                          ),
                        )
                      : product.imageUrl.startsWith('/') ||
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
                      : Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
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
