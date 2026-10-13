import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/store/presentation/store_ui.dart';
import 'dart:io';

import 'dart:async';

import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/shared/widgets/app_drawer.dart';
import 'package:studentry/store/data/catalog_refresh_schedule.dart';
import 'package:studentry/store/data/store_models.dart';

import 'package:studentry/store/presentation/all_categories_screen.dart';
import 'package:studentry/store/presentation/product_detail_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/store/presentation/widgets/category_outline_icon.dart';
import 'package:studentry/store/presentation/widgets/store_promo_card.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/widgets/app_cached_network_image.dart';
import 'package:studentry/shared/utils/search_debouncer.dart';
import 'package:studentry/shared/widgets/pagination_controls.dart';
import 'package:studentry/shared/widgets/refresh_visibility.dart';
import 'package:studentry/shared/data/connectivity_service.dart';

const Color _kGrey = Color(0xFF9E9E9E);
const Color kFieldBg = Color(0xFFF4F9FA);
const Color kFieldBorder = Color(0xFFE0E0E0);

class StoreScreen extends ConsumerStatefulWidget {
  final bool embedded;
  final bool active;

  const StoreScreen({super.key, this.embedded = false, this.active = true});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  int _currentBannerIndex = 0;
  bool _showSearch = false;
  final _bannerController = PageController();
  final _searchController = TextEditingController();
  final SearchDebouncer _searchDebouncer = SearchDebouncer();
  String? _studentAcademicYear;
  Timer? _catalogTimer;
  Future<void>? _catalogRefresh;
  bool _isInitialCatalogLoading = true;
  bool _initialCatalogFailed = false;
  bool _visible = false;
  bool _needsPageMetadata = true;
  final _refreshSchedule = CatalogRefreshSchedule();
  late final Future<void> _catalogSetup;

  @override
  void initState() {
    super.initState();
    ConnectivityService.isOnline.addListener(_onConnectivity);
    _loadAcademicYear();
    _isInitialCatalogLoading = true;
    _catalogSetup = Future.microtask(() async {
      if (!mounted) return;
      final loaded = ref
          .read(catalogProvider.notifier)
          .restoreSnapshot(academicYear: _studentAcademicYear);
      _needsPageMetadata = !ref
          .read(catalogProvider.notifier)
          .hasCachedPagination;
      if (mounted &&
          loaded &&
          ref.read(catalogProvider.notifier).hasCachedProductPage) {
        setState(() => _isInitialCatalogLoading = false);
      }
      await _refreshSchedule.prepare(AuthService().userId);
    });
  }

  void _onVisibility(bool active) {
    _visible = active;
    _catalogTimer?.cancel();
    if (active) {
      unawaited(_resumeCatalogUpdates());
    }
  }

  void _onConnectivity() {
    if (_visible && ConnectivityService.isOnline.value) {
      unawaited(_resumeCatalogUpdates());
    }
  }

  Future<void> _resumeCatalogUpdates() async {
    await _catalogSetup;
    if (!mounted || !_visible) return;
    await _refreshSchedule.prepare(AuthService().userId);
    if (!mounted || !_visible) return;
    if (_isInitialCatalogLoading || _needsPageMetadata) {
      await _refreshCatalog(); // A first installation cannot wait for a batch.
    }
    _scheduleCatalogRefresh();
  }

  Future<void> _refreshCatalog({bool force = false}) {
    if (!mounted || !_visible) {
      return Future.value();
    }
    if (!ConnectivityService.isOnline.value) {
      if (_isInitialCatalogLoading && !_initialCatalogFailed) {
        setState(() => _initialCatalogFailed = true);
      }
      return Future.value();
    }
    final active = _catalogRefresh;
    if (active != null) return active;
    late final Future<void> refresh;
    refresh = _performCatalogRefresh(force: force).whenComplete(() {
      if (identical(_catalogRefresh, refresh)) _catalogRefresh = null;
    });
    _catalogRefresh = refresh;
    return refresh;
  }

  Future<void> _performCatalogRefresh({bool force = false}) async {
    await _catalogSetup;
    if (!mounted || !_visible) return;
    final loaded = await ref
        .read(catalogProvider.notifier)
        .refreshCatalog(academicYear: _studentAcademicYear, force: force);
    if (!mounted) return;
    await _refreshSchedule.completed(success: loaded);
    if (!mounted) return;
    _scheduleCatalogRefresh();
    if (!loaded) {
      if (_isInitialCatalogLoading) {
        setState(() => _initialCatalogFailed = true);
      }
      return;
    }
    _needsPageMetadata = false;

    if (mounted && (_isInitialCatalogLoading || _initialCatalogFailed)) {
      setState(() {
        _isInitialCatalogLoading = false;
        _initialCatalogFailed = false;
      });
    }
  }

  void _scheduleCatalogRefresh() {
    _catalogTimer?.cancel();
    if (!mounted || !_visible) return;
    _catalogTimer = Timer(_refreshSchedule.delay, () async {
      await _refreshCatalog();
      if (!ConnectivityService.isOnline.value) {
        await _refreshSchedule.completed(success: false);
      }
      _scheduleCatalogRefresh();
    });
  }

  void _loadAcademicYear() {
    if (ref.read(authProvider).role == 'student') {
      _studentAcademicYear = AuthService().academicYear;
    }
  }

  List<Product> _computeDisplayProducts(List<Product> products, String? role) {
    if (role == 'student' && _studentAcademicYear != null) {
      return products
          .where(
            (p) =>
                p.academicYear == _studentAcademicYear ||
                p.academicYear == null,
          )
          .toList();
    }
    return products;
  }

  @override
  void dispose() {
    _catalogTimer?.cancel();
    ConnectivityService.isOnline.removeListener(_onConnectivity);
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) return;
    Navigator.pushNamed(context, '/search-results', arguments: query);
  }

  void _scheduleSearch(String query) {
    if (query.trim().isEmpty) {
      _searchDebouncer.cancel();
      return;
    }
    _searchDebouncer.schedule(() {
      if (mounted) _onSearch(query);
    });
  }

  void _submitSearch(String query) {
    _searchDebouncer.runNow(() {
      if (mounted) _onSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) => RefreshVisibility(
    active: widget.active,
    onChanged: _onVisibility,
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final role = ref.watch(authProvider).role;
    final cartItemCount = ref.watch(cartProvider).itemCount;
    final favIds = ref.watch(favoritesProvider).productIds;
    final banners = catalog.banners;
    final categories = catalog.categories;
    final products = catalog.products;
    final displayProducts = _computeDisplayProducts(products, role);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppDrawer(),
      drawerEnableOpenDragGesture: !widget.embedded,
      appBar: _buildAppBar(cartItemCount, favIds),
      bottomNavigationBar: widget.embedded
          ? null
          : AppBottomNav(selectedIndex: 3),
      body: _isInitialCatalogLoading
          ? Center(
              child: _initialCatalogFailed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          color: AppColors.primary,
                          size: 44,
                        ),
                        SizedBox(height: 12),
                        Text(storeUi('تعذر تحميل أحدث نسخة من المتجر')),
                        SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() => _initialCatalogFailed = false);
                            _refreshCatalog(force: true);
                          },
                          icon: Icon(Icons.refresh),
                          label: Text(storeUi('إعادة المحاولة')),
                        ),
                      ],
                    )
                  : CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _refreshCatalog(force: true),
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    if (_showSearch) _buildSearchBar(favIds),
                    if (_showSearch) SizedBox(height: 16),
                    if (banners.isNotEmpty) _buildPromoBannerSlider(banners),
                    if (banners.isNotEmpty) SizedBox(height: 20),
                    _buildCategoriesHeader(),
                    SizedBox(height: 12),
                    categories.isEmpty
                        ? _buildEmptyCategoriesState()
                        : _buildHorizontalCategories(categories),
                    SizedBox(height: 24),
                    if (displayProducts.isNotEmpty) ...[
                      if (role == 'student' && _studentAcademicYear != null)
                        _buildAcademicYearBanner(),
                      if (displayProducts.any((p) => p.rating > 0)) ...[
                        _buildSectionHeader('منتجات مميزة', Icons.star_rounded),
                        SizedBox(height: 12),
                        _buildProductRow(
                          _sortedProducts(
                            displayProducts.where((p) => p.rating > 0).toList(),
                            (a, b) => b.rating.compareTo(a.rating),
                          ).take(6).toList(),
                        ),
                        SizedBox(height: 24),
                      ],
                      _buildSectionHeader(
                        'استكشف المنتجات',
                        Icons.grid_view_rounded,
                      ),
                      SizedBox(height: 12),
                      _buildProductGrid(displayProducts),
                      SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: PaginationControls(
                          currentPage: catalog.currentProductPage,
                          lastPage: catalog.lastProductPage,
                          loading: catalog.isLoadingProducts,
                          onPrevious: catalog.currentProductPage > 1
                              ? () => ref
                                    .read(catalogProvider.notifier)
                                    .loadProductsPage(
                                      catalog.currentProductPage - 1,
                                    )
                              : null,
                          onNext:
                              catalog.currentProductPage <
                                  catalog.lastProductPage
                              ? () => ref
                                    .read(catalogProvider.notifier)
                                    .loadProductsPage(
                                      catalog.currentProductPage + 1,
                                    )
                              : null,
                        ),
                      ),
                      SizedBox(height: 20),
                    ] else
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          storeUi('لا توجد منتجات في هذه الصفحة حالياً.'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(int cartItemCount, Set<String> favIds) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Icon(Icons.menu, color: AppColors.textDark),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Text(
        storeUi('المتجر'),
        style: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.bold,
          fontSize: 18.sp,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            _showSearch ? Icons.close : Icons.search,
            color: AppColors.textDark,
            size: 24,
          ),
          onPressed: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchDebouncer.cancel();
                _searchController.clear();
              }
            });
          },
        ),
        IconButton(
          icon: Icon(
            Icons.favorite_outline,
            color: AppColors.textDark,
            size: 24,
          ),
          onPressed: () => Navigator.pushNamed(context, '/favorites'),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                Icons.shopping_cart_outlined,
                color: AppColors.primary,
                size: 26,
              ),
              onPressed: () => Navigator.pushNamed(context, '/cart'),
            ),
            if (cartItemCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    '$cartItemCount',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(Set<String> favIds) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _scheduleSearch,
              onSubmitted: _submitSearch,
              decoration: InputDecoration(
                hintText: storeUi('ابحث عن منتج...'),
                hintStyle: TextStyle(color: _kGrey, fontSize: 14.sp),
                suffixIcon: Icon(Icons.search, color: AppColors.primary),
                filled: true,
                fillColor: kFieldBg,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: kFieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/favorites'),
            child: Container(
              width: 46.w,
              height: 46.h,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      Icons.favorite,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  if (favIds.isNotEmpty)
                    Positioned(
                      left: 6,
                      top: 4,
                      child: Container(
                        padding: EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${favIds.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBannerSlider(List<PromoBanner> banners) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height:
                ((constraints.maxWidth - 32.w) / 2).clamp(180.0, 230.0) +
                (MediaQuery.textScalerOf(context).scale(18) - 18).clamp(
                  0.0,
                  30.0,
                ),
            child: PageView.builder(
              controller: _bannerController,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => _currentBannerIndex = i),
              itemBuilder: (_, i) => _buildBannerCard(banners[i]),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (i) => AnimatedContainer(
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 3),
              width: _currentBannerIndex == i ? 8 : 6,
              height: _currentBannerIndex == i ? 8 : 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentBannerIndex == i
                    ? AppColors.primary
                    : kFieldBorder,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCard(PromoBanner banner) {
    final catalog = ref.watch(catalogProvider);
    final url = banner.imageUrl;
    final image = url.startsWith('/') || url.contains(':\\')
        ? Image.file(
            File(url),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            errorBuilder: (_, _, _) => SizedBox.shrink(),
          )
        : AppCachedNetworkImage(
            url: url,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            errorBuilder: () => SizedBox.shrink(),
          );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: StorePromoCard(
        banner: banner,
        image: image,
        onTap: () {
          if (banner.productId != null) {
            final product = catalog.products
                .where((p) => p.id == banner.productId)
                .firstOrNull;
            if (product != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailsScreen(product: product),
                ),
              );
              return;
            }
          }
          Navigator.pushNamed(
            context,
            banner.actionRoute,
            arguments: banner.categoryId,
          );
        },
      ),
    );
  }

  Widget _buildCategoriesHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            storeUi('التصنيفات'),
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AllCategoriesScreen()),
            ),
            child: Text(
              storeUi('عرض الكل'),
              style: TextStyle(color: AppColors.primary, fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }

  List<Product> _sortedProducts(
    List<Product> source,
    int Function(Product, Product) compare,
  ) {
    final list = List<Product>.from(source);
    list.sort((a, b) => compare(a, b));
    return list;
  }

  Widget _buildAcademicYearBanner() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.school_rounded,
              color: AppColors.primary,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              AppLocale.text(
                'منتجات مقترحة لطلاب السنة $_studentAcademicYear',
                'Recommended for academic year $_studentAcademicYear',
              ),
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20.sp),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCategories(List<ProductCategory> categories) {
    return SizedBox(
      height: 100.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        itemCount: categories.length,
        itemBuilder: (_, i) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: SizedBox(
            width: 72.w,
            child: _buildCategoryItem(categories[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildProductRow(List<Product> products) {
    return SizedBox(
      height: 190.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        itemCount: products.length,
        itemBuilder: (_, i) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: _buildProductCard(products[i]),
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (_, index) =>
            _buildProductCard(products[index], wide: true),
      ),
    );
  }

  Widget _buildProductCard(Product product, {bool wide = false}) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(product: product),
        ),
      ),
      child: Container(
        width: wide ? double.infinity : 140.w,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kFieldBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                child: SizedBox(
                  width: double.infinity,
                  child: product.listImageUrl.isEmpty
                      ? Container(
                          color: AppColors.primarySurface,
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.primary,
                            size: 28.sp,
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
                              size: 28.sp,
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
                              size: 28.sp,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Text(
                        storeUi('${product.price.toStringAsFixed(0)} SYP'),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      if (product.rating > 0) ...[
                        Icon(Icons.star, color: Color(0xFFFFC107), size: 12),
                        SizedBox(width: 2.w),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: TextStyle(color: _kGrey, fontSize: 10.sp),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editCategoryName(ProductCategory category) {
    final controller = TextEditingController(text: category.label);
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.language == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            storeUi('تعديل اسم التصنيف'),
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: storeUi('الاسم')),
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
                if (controller.text.trim().isNotEmpty) {
                  try {
                    await ref
                        .read(catalogProvider.notifier)
                        .updateCategory(
                          category.id,
                          AppLocale.language == 'ar'
                              ? controller.text.trim()
                              : (category.translations['ar']?['name'] ??
                                    category.toJson()['label'] as String),
                          category.iconUrl,
                          translations: {
                            'ar': {
                              'name': AppLocale.language == 'ar'
                                  ? controller.text.trim()
                                  : (category.translations['ar']?['name'] ??
                                        category.toJson()['label']),
                            },
                            'en': AppLocale.language == 'en'
                                ? {'name': controller.text.trim()}
                                : category.translations['en'],
                          },
                        );
                  } catch (error) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocale.text(
                              'تعذر تعديل التصنيف: $error',
                              'Could not update category: $error',
                            ),
                          ),
                        ),
                      );
                    }
                    return;
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(storeUi('حفظ')),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryOptions(ProductCategory category) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kGrey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16),
              Text(
                category.label,
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: AppColors.primary),
                title: Text(storeUi('تعديل الاسم')),
                onTap: () {
                  Navigator.pop(ctx);
                  _editCategoryName(category);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  storeUi('حذف التصنيف'),
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text(storeUi('تأكيد الحذف')),
                      content: Text(
                        AppLocale.text(
                          'سيتم حذف "${category.label}" وجميع منتجاته',
                          'Delete "${category.label}" and its products?',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: Text(storeUi('إلغاء')),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: AppColors.textLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              await ref
                                  .read(catalogProvider.notifier)
                                  .deleteCategory(category.id);
                              if (dCtx.mounted) Navigator.pop(dCtx);
                            } catch (error) {
                              if (dCtx.mounted) {
                                ScaffoldMessenger.of(dCtx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocale.text(
                                        'تعذر حذف التصنيف: $error',
                                        'Could not delete category: $error',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(storeUi('حذف')),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(ProductCategory category) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/category-products',
        arguments: category.id,
      ),
      onLongPress: () => _showCategoryOptions(category),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kFieldBorder, width: 1),
        ),
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CategoryOutlineIcon(
              label: category.label,
              iconUrl: category.iconUrl,
            ),
            SizedBox(height: 8),
            Text(
              category.label,
              style: TextStyle(color: AppColors.textDark, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategoriesState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.category_outlined, color: _kGrey, size: 40),
            SizedBox(height: 8),
            Text(
              storeUi('لا توجد تصنيفات حالياً'),
              style: TextStyle(color: _kGrey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
