import 'dart:io';

import 'dart:async';
import 'dart:math';

import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/shared/widgets/app_drawer.dart';
import 'package:studentry/shared/data/api_config.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/data/store_data.dart';
import 'package:studentry/store/presentation/all_categories_screen.dart';
import 'package:studentry/store/presentation/product_detail_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/shared/providers/auth_provider.dart';

const Color _kGrey = Color(0xFF9E9E9E);
const Color kFieldBg = Color(0xFFF4F9FA);
const Color kFieldBorder = Color(0xFFE0E0E0);
const Color kBannerEnd = Color(0xFF0E7C8F);

class StoreScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const StoreScreen({super.key, this.embedded = false});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  int _currentBannerIndex = 0;
  bool _showSearch = false;
  final _bannerController = PageController();
  final _searchController = TextEditingController();
  String? _studentAcademicYear;
  Timer? _catalogTimer;
  bool _isInitialCatalogLoading = true;
  bool _initialCatalogFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAcademicYear();
    final hasSnapshot = loadStoreSnapshot();
    _isInitialCatalogLoading = !hasSnapshot;
    Future.microtask(() {
      ref
          .read(catalogProvider.notifier)
          .loadCachedSnapshot(storeBanners, storeCategories);
      _refreshCatalog();
    });
    _scheduleCatalogRefresh();
  }

  Future<void> _refreshCatalog() async {
    final loaded = await loadStoreFromApi(refresh: true);
    if (!mounted) return;
    if (!loaded) {
      if (_isInitialCatalogLoading) {
        setState(() => _initialCatalogFailed = true);
      }
      return;
    }
    ref
        .read(catalogProvider.notifier)
        .loadBannersAndCategories(storeBanners, storeCategories);
    await ref.read(catalogProvider.notifier).loadInitialProducts();
    if (mounted && (_isInitialCatalogLoading || _initialCatalogFailed)) {
      setState(() {
        _isInitialCatalogLoading = false;
        _initialCatalogFailed = false;
      });
    }
  }

  void _scheduleCatalogRefresh() {
    _catalogTimer?.cancel();
    final stagger = Duration(seconds: Random().nextInt(61));
    _catalogTimer = Timer(ApiConfig.catalogRefreshInterval + stagger, () async {
      await _refreshCatalog();
      _scheduleCatalogRefresh();
    });
  }

  Future<void> _loadAcademicYear() async {
    if (ref.read(authProvider).role == 'student') {
      _studentAcademicYear = null;
    }
  }

  List<Product> _computeDisplayProducts(List<Product> products, String? role) {
    if (role == 'student' && _studentAcademicYear != null) {
      return ref
          .read(catalogProvider.notifier)
          .getProductsByAcademicYear(_studentAcademicYear);
    }
    return products;
  }

  @override
  void dispose() {
    _catalogTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) return;
    Navigator.pushNamed(context, '/search-results', arguments: query);
  }

  @override
  Widget build(BuildContext context) {
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
      drawer: const AppDrawer(),
      drawerEnableOpenDragGesture: !widget.embedded,
      appBar: _buildAppBar(cartItemCount, favIds),
      bottomNavigationBar: widget.embedded
          ? null
          : const AppBottomNav(selectedIndex: 3),
      body: _isInitialCatalogLoading
          ? Center(
              child: _initialCatalogFailed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          color: AppColors.primary,
                          size: 44,
                        ),
                        const SizedBox(height: 12),
                        const Text('تعذر تحميل أحدث نسخة من المتجر'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() => _initialCatalogFailed = false);
                            _refreshCatalog();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refreshCatalog,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    if (_showSearch) _buildSearchBar(favIds),
                    if (_showSearch) const SizedBox(height: 16),
                    if (banners.isNotEmpty) _buildPromoBannerSlider(banners),
                    if (banners.isNotEmpty) const SizedBox(height: 20),
                    _buildCategoriesHeader(),
                    const SizedBox(height: 12),
                    categories.isEmpty
                        ? _buildEmptyCategoriesState()
                        : _buildHorizontalCategories(categories),
                    const SizedBox(height: 24),
                    if (displayProducts.isNotEmpty) ...[
                      if (role == 'student' && _studentAcademicYear != null)
                        _buildAcademicYearBanner(),
                      _buildSectionHeader('الأكثر تقييماً', Icons.star_rounded),
                      const SizedBox(height: 12),
                      _buildProductRow(
                        _sortedProducts(
                          displayProducts,
                          (a, b) => b.rating.compareTo(a.rating),
                        ).take(6).toList(),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'الأكثر مبيعاً',
                        Icons.trending_up_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildProductRow(
                        _sortedProducts(
                          displayProducts,
                          (a, b) => b.reviewsCount.compareTo(a.reviewsCount),
                        ).take(6).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
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
          icon: const Icon(Icons.menu, color: AppColors.textDark),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Text(
        'المتجر',
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
              if (!_showSearch) _searchController.clear();
            });
          },
        ),
        IconButton(
          icon: const Icon(
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
              icon: const Icon(
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
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '$cartItemCount',
                    style: const TextStyle(
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
              onSubmitted: _onSearch,
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج...',
                hintStyle: TextStyle(color: _kGrey, fontSize: 14.sp),
                suffixIcon: const Icon(Icons.search, color: AppColors.primary),
                filled: true,
                fillColor: kFieldBg,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: kFieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
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
                  const Center(
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
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${favIds.length}',
                          style: const TextStyle(
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
        SizedBox(
          height: 200.h,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _currentBannerIndex = i),
            itemBuilder: (_, i) => _buildBannerCard(banners[i]),
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, kBannerEnd],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 10,
            top: 10,
            bottom: 10,
            child: () {
              final url = banner.imageUrl;
              if (url.startsWith('/') || url.contains(':\\')) {
                return Image.file(
                  File(url),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                );
              }
              return Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              );
            }(),
          ),
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 20.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  banner.subtitle,
                  style: TextStyle(
                    color: AppColors.textLight.withValues(alpha: 0.9),
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  banner.discountText,
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 32.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                GestureDetector(
                  onTap: () {
                    if (banner.productId != null) {
                      final prod = catalog.products
                          .where((p) => p.id == banner.productId)
                          .firstOrNull;
                      if (prod != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailsScreen(product: prod),
                          ),
                        );
                        return;
                      }
                    }
                    Navigator.pushNamed(context, banner.actionRoute);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      banner.ctaText,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
            'التصنيفات',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllCategoriesScreen()),
            ),
            child: Text(
              'عرض الكل',
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
              'منتجات مقترحة لطلاب السنة $_studentAcademicYear',
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

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(product: product),
        ),
      ),
      child: Container(
        width: 140.w,
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: product.imageUrl.isEmpty
                      ? Container(
                          color: AppColors.primarySurface,
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.primary,
                            size: 28.sp,
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
                              size: 28.sp,
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
                        '${product.price.toStringAsFixed(0)} ر.س',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (product.rating > 0) ...[
                        const Icon(
                          Icons.star,
                          color: Color(0xFFFFC107),
                          size: 12,
                        ),
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
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'تعديل اسم التصنيف',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'الاسم'),
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
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  try {
                    await ref
                        .read(catalogProvider.notifier)
                        .updateCategory(
                          category.id,
                          controller.text.trim(),
                          category.iconUrl,
                        );
                  } catch (error) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('تعذر تعديل التصنيف: $error')),
                      );
                    }
                    return;
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryOptions(ProductCategory category) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
              const SizedBox(height: 16),
              Text(
                category.label,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('تعديل الاسم'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editCategoryName(category);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'حذف التصنيف',
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
                      title: const Text('تأكيد الحذف'),
                      content: Text(
                        'سيتم حذف "${category.label}" وجميع منتجاته',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('إلغاء'),
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
                                    content: Text('تعذر حذف التصنيف: $error'),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('حذف'),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            category.iconUrl.endsWith('.svg')
                ? SvgPicture.network(
                    category.iconUrl,
                    colorFilter: const ColorFilter.mode(
                      AppColors.primary,
                      BlendMode.srcIn,
                    ),
                    width: 28,
                    height: 28,
                  )
                : Image.network(
                    category.iconUrl,
                    width: 28,
                    height: 28,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.category_outlined,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
            const SizedBox(height: 8),
            Text(
              category.label,
              style: const TextStyle(color: AppColors.textDark, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 1,
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
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.category_outlined, color: _kGrey, size: 40),
            const SizedBox(height: 8),
            const Text(
              'لا توجد تصنيفات حالياً',
              style: TextStyle(color: _kGrey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
