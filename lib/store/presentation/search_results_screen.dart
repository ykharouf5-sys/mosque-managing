import 'package:studentry/utils/app_input_formatters.dart';
import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/store/data/catalog_translations.dart';
import 'package:studentry/store/presentation/store_ui.dart';
import 'dart:io';

import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/shared/widgets/pagination_controls.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/utils/search_debouncer.dart';
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

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;
  const SearchResultsScreen({super.key, required this.query});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late TextEditingController _searchController;
  final SearchDebouncer _searchDebouncer = SearchDebouncer();
  List<Product> _results = [];
  String? _studentAcademicYear;
  bool _isLoading = false;
  int _page = 1;
  int _lastPage = 1;
  int _searchGeneration = 0;
  static const int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    _loadAcademicYear();
  }

  Future<void> _loadAcademicYear() async {
    final auth = AuthService();
    if (auth.role == 'student') {
      _studentAcademicYear = auth.academicYear;
    }
    await _search(widget.query);
  }

  Future<void> _search(String query) async {
    final generation = ++_searchGeneration;
    setState(() {
      _isLoading = true;
      _results = [];
    });
    await _loadPage(query.trim(), generation, page: 1);
  }

  void _scheduleSearch(String query) {
    _searchDebouncer.schedule(() => _search(query));
  }

  void _submitSearch(String query) {
    _searchDebouncer.runNow(() => _search(query));
  }

  Future<void> _loadPage(
    String query,
    int generation, {
    required int page,
  }) async {
    if (_isLoading && page != 1) return;
    if (mounted) setState(() => _isLoading = true);
    try {
      final result = await StoreApiService.fetchProductPage(
        page,
        _pageSize,
        search: query,
        academicYear: _studentAcademicYear,
      );
      if (!mounted || generation != _searchGeneration) return;
      final categoryNames = {
        for (final category in ref.read(catalogProvider).categories)
          category.id: category.label,
      };
      final products = result.rows
          .map((row) {
            final item = StoreApiService.rowToProductMap(row);
            return Product(
              id: item['id'] as String,
              name: item['name'] as String,
              translations: parseCatalogCopy(item['translations']),
              categoryTranslations:
                  ref
                      .read(catalogProvider)
                      .categories
                      .where((c) => c.id == item['categoryId'])
                      .firstOrNull
                      ?.translations ??
                  const {},
              brand: item['brand'] as String? ?? '',
              description: item['description'] as String? ?? '',
              imageUrl: item['imageUrl'] as String? ?? '',
              thumbnailUrl: item['thumbnailUrl'] as String?,
              physicalStock: (item['physicalStock'] as num?)?.toInt(),
              categoryId: item['categoryId'] as String? ?? '',
              categoryName: categoryNames[item['categoryId']] ?? '',
              price: (item['price'] as num?)?.toDouble() ?? 0,
              rating: (item['rating'] as num?)?.toDouble() ?? 0,
              reviewsCount: (item['reviewsCount'] as num?)?.toInt() ?? 0,
              stock: (item['stock'] as num?)?.toInt() ?? 0,
              createdAt:
                  DateTime.tryParse(item['createdAt'] as String? ?? '') ??
                  DateTime.now(),
              academicYear: item['academicYear'] as String?,
              deliveryPrice: (item['deliveryPrice'] as num?)?.toDouble() ?? 0,
            );
          })
          .toList(growable: false);
      setState(() {
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _results = products;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && generation == _searchGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchGeneration++;
    _searchDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Directionality(
      textDirection: AppLocale.language == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: AppBottomNav(selectedIndex: 3),
        body: Column(
          children: [
            _buildSearchBar(),
            if (_results.isEmpty && _isLoading)
              Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_results.isEmpty)
              Expanded(child: _buildEmptyState())
            else ...[
              Expanded(child: _buildProductGrid()),
              _buildPaginationControls(),
            ],
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
            icon: Icon(Icons.arrow_back, color: AppColors.textDark),
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
                inputFormatters: AppInputFormatters.text(200),
                textAlignVertical: TextAlignVertical.center,
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _scheduleSearch,
                onSubmitted: _submitSearch,
                decoration: InputDecoration(
                  hintText: storeUi('ابحث عن منتج...'),
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
                    onPressed: () => _submitSearch(_searchController.text),
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
            AppLocale.text(
              'لا توجد نتائج لـ "${_searchController.text.trim()}"',
              'No results for "${_searchController.text.trim()}"',
            ),
            style: TextStyle(color: _kGrey, fontSize: 14.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            storeUi('جرب البحث بكلمة أخرى'),
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
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemBuilder: (_, i) => _buildProductCard(_results[i]),
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
          loading: _isLoading,
          onPrevious: _page > 1
              ? () => _loadPage(
                  _searchController.text.trim(),
                  _searchGeneration,
                  page: _page - 1,
                )
              : null,
          onNext: _page < _lastPage
              ? () => _loadPage(
                  _searchController.text.trim(),
                  _searchGeneration,
                  page: _page + 1,
                )
              : null,
        ),
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  width: double.infinity,
                  child: product.listImageUrl.isEmpty
                      ? Container(
                          color: AppColors.primarySurface,
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.primary,
                            size: 32.sp,
                          ),
                        )
                      : product.listImageUrl.startsWith('/') ||
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
