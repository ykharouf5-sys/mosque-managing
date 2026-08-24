import 'dart:io';

import 'package:studentry/store/data/store_data.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/data/store_image_service.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/presentation/notification_campaign_screen.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const Color _kGrey = Color(0xFF9E9E9E);

class SalesDashboardScreen extends ConsumerStatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  ConsumerState<SalesDashboardScreen> createState() =>
      _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends ConsumerState<SalesDashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    loadStoreSnapshot();
    Future.microtask(_loadCatalog);
  }

  Future<void> _loadCatalog() async {
    await loadStoreFromApi(refresh: true);
    if (!mounted) return;
    ref
        .read(catalogProvider.notifier)
        .loadBannersAndCategories(dummyBanners, dummyCategories);
    await ref.read(catalogProvider.notifier).loadInitialProducts();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(catalogProvider);
    ref.watch(ordersProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_sectionTitles[_selectedIndex]),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.primary,
              ),
              tooltip: 'إرسال إشعار للمستخدمين',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationCampaignScreen(
                    managerType: NotificationManagerType.sales,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.textDark),
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (_) => false,
                  );
                }
              },
            ),
          ],
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textDark),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ),
        drawer: _buildSidebar(context),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _CategoriesTab(
              onDataChanged: () => ref.read(catalogProvider.notifier).refresh(),
            ),
            _ProductsTab(
              onDataChanged: () => ref.read(catalogProvider.notifier).refresh(),
            ),
            _BannersTab(
              onDataChanged: () => ref.read(catalogProvider.notifier).refresh(),
            ),
            _CouponsTab(
              onDataChanged: () => ref.read(catalogProvider.notifier).refresh(),
            ),
            _OrdersTab(
              onDataChanged: () => ref.read(ordersProvider.notifier).refresh(),
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _sectionTitles = [
    'التصنيفات',
    'المنتجات',
    'العروض',
    'الكوبونات',
    'الطلبات',
  ];

  static const List<IconData> _sectionIcons = [
    Icons.category_outlined,
    Icons.inventory_2_outlined,
    Icons.slideshow_outlined,
    Icons.discount_outlined,
    Icons.receipt_long_outlined,
  ];

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          color: AppColors.surface,
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20.w, 48.h, 20.w, 24.h),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFF0E7C8F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'لوحة تحكم المبيعات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'إدارة المتجر',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              // Menu items
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: _sectionTitles.length,
                  itemBuilder: (_, i) => _buildSidebarItem(i),
                ),
              ),
              // Footer
              Padding(
                padding: EdgeInsets.all(16.r),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('تسجيل الخروج'),
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (_) => false,
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _selectedIndex = index);
            Navigator.pop(context);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.2))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _sectionIcons[index],
                    color: isSelected ? AppColors.primary : _kGrey,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  _sectionTitles[index],
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textDark,
                    fontSize: 14.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 4.w,
                    height: 24.h,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _styledDialogButton(
  String label, {
  Color? color,
  VoidCallback? onPressed,
}) {
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      foregroundColor: color ?? AppColors.primary,
      backgroundColor: (color ?? AppColors.primary).withValues(alpha: 0.08),
    ),
    child: Text(
      label,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
    ),
  );
}

Widget _styledConfirmButton(String label, {VoidCallback? onPressed}) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textLight,
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.3),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    ),
    onPressed: onPressed,
    child: Text(
      label,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
    ),
  );
}

Future<bool?> _showDeleteConfirmDialog(
  BuildContext context,
  String title,
  String content,
) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 22,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 17.sp,
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: TextStyle(color: _kGrey, fontSize: 14.sp),
        ),
        actions: [
          _styledDialogButton(
            'إلغاء',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          _styledDialogButton(
            'حذف',
            color: Colors.red,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    ),
  );
}

class _GenericListTab extends StatelessWidget {
  final String emptyIcon;
  final String emptyTitle;
  final String emptyActionLabel;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  const _GenericListTab({
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyActionLabel,
    required this.itemCount,
    required this.itemBuilder,
    required this.onAdd,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: itemCount == 0
          ? _buildEmpty(context)
          : RefreshIndicator(
              onRefresh: () async => onRefresh(),
              child: ListView.builder(
                padding: EdgeInsets.all(16.r),
                itemCount: itemCount,
                itemBuilder: itemBuilder,
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: onAdd,
        child: const Icon(Icons.add, color: AppColors.textLight),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, color: _kGrey, size: 48.sp),
          SizedBox(height: 12.h),
          Text(
            emptyTitle,
            style: TextStyle(color: _kGrey, fontSize: 14.sp),
          ),
          SizedBox(height: 12.h),
          ElevatedButton.icon(
            icon: Icon(Icons.add, size: 18.sp),
            label: Text(emptyActionLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

// ──────────────── CATEGORIES TAB ────────────────

class _CategoriesTab extends StatelessWidget {
  final VoidCallback onDataChanged;
  const _CategoriesTab({required this.onDataChanged});

  @override
  Widget build(BuildContext context) {
    return _GenericListTab(
      emptyIcon: 'category',
      emptyTitle: 'لا توجد تصنيفات',
      emptyActionLabel: 'إضافة تصنيف',
      itemCount: dummyCategories.length,
      itemBuilder: (ctx, i) => _buildCategoryCard(ctx, dummyCategories[i]),
      onAdd: () => _showCategoryDialog(context, null),
      onRefresh: onDataChanged,
    );
  }

  Widget _buildCategoryCard(BuildContext context, ProductCategory category) {
    return Dismissible(
      key: Key(category.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: AppColors.textLight,
          size: 28.sp,
        ),
      ),
      confirmDismiss: (_) => _showDeleteConfirmDialog(
        context,
        'حذف التصنيف',
        'سيتم حذف "${category.label}" وجميع منتجاته. هل أنت متأكد؟',
      ),
      onDismissed: (_) {
        deleteCategory(category.id);
        onDataChanged();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              category.iconUrl,
              width: 40.w,
              height: 40.h,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.category, color: AppColors.primary, size: 28.sp),
            ),
          ),
          title: Text(
            category.label,
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${category.productCount ?? 0} منتج',
            style: TextStyle(color: _kGrey, fontSize: 12.sp),
          ),
          trailing: Icon(Icons.edit_outlined, color: _kGrey, size: 20.sp),
          onTap: () => _showCategoryDialog(context, category),
        ),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, ProductCategory? category) {
    final nameC = TextEditingController(text: category?.label ?? '');
    final urlC = TextEditingController(text: category?.iconUrl ?? '');
    final isEdit = category != null;
    _showFormDialog(
      context: context,
      title: isEdit ? 'تعديل التصنيف' : 'إضافة تصنيف',
      icon: Icons.category_outlined,
      fields: [
        _DialogField(
          controller: nameC,
          label: 'اسم التصنيف',
          hint: 'مثال: فرش أسنان',
        ),
        _DialogField(
          controller: urlC,
          label: 'رابط الأيقونة',
          hint: 'https://...',
        ),
      ],
      onSave: () {
        if (nameC.text.trim().isEmpty) return;
        if (isEdit) {
          updateCategory(category.id, nameC.text.trim(), urlC.text.trim());
        } else {
          addCategory(nameC.text.trim(), urlC.text.trim());
        }
        onDataChanged();
      },
    );
  }
}

// ──────────────── PRODUCTS TAB ────────────────

class _ProductsTab extends StatelessWidget {
  final VoidCallback onDataChanged;
  const _ProductsTab({required this.onDataChanged});

  @override
  Widget build(BuildContext context) {
    return _GenericListTab(
      emptyIcon: 'product',
      emptyTitle: 'لا توجد منتجات',
      emptyActionLabel: 'إضافة منتج',
      itemCount: dummyProducts.length,
      itemBuilder: (ctx, i) => _buildProductCard(ctx, dummyProducts[i]),
      onAdd: () => _showProductDialog(context, null),
      onRefresh: onDataChanged,
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return Dismissible(
      key: Key(product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: AppColors.textLight,
          size: 28.sp,
        ),
      ),
      confirmDismiss: (_) => _showDeleteConfirmDialog(
        context,
        'حذف المنتج',
        'هل أنت متأكد من حذف "${product.name}"؟',
      ),
      onDismissed: (_) {
        deleteProduct(product.id);
        onDataChanged();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48.w,
              height: 48.h,
              child:
                  product.imageUrl.startsWith('/') ||
                      product.imageUrl.contains(':\\')
                  ? Image.file(
                      File(product.imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.primarySurface,
                        child: Icon(
                          Icons.image,
                          color: AppColors.primary,
                          size: 24.sp,
                        ),
                      ),
                    )
                  : Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.primarySurface,
                        child: Icon(
                          Icons.image,
                          color: AppColors.primary,
                          size: 24.sp,
                        ),
                      ),
                    ),
            ),
          ),
          title: Text(
            product.name,
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${product.price.toStringAsFixed(0)} ر.س - ${product.categoryName}',
            style: TextStyle(color: _kGrey, fontSize: 12.sp),
          ),
          trailing: Icon(Icons.edit_outlined, color: _kGrey, size: 20.sp),
          onTap: () => _showProductDialog(context, product),
        ),
      ),
    );
  }

  void _showProductDialog(BuildContext context, Product? product) {
    final nameC = TextEditingController(text: product?.name ?? '');
    final brandC = TextEditingController(text: product?.brand ?? '');
    final descC = TextEditingController(text: product?.description ?? '');
    final priceC = TextEditingController(
      text: product != null ? product.price.toStringAsFixed(0) : '',
    );
    final stockC = TextEditingController(
      text: product != null ? product.stock.toString() : '0',
    );
    final isEdit = product != null;
    String? imagePath = product?.imageUrl;
    String? selectedCategoryId = product?.categoryId;
    String? selectedAcademicYear = product?.academicYear;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    isEdit ? 'تعديل المنتج' : 'إضافة منتج',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 17.sp,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final uploaded = await StoreImageService.pickAndUpload(
                          kind: 'product',
                        );
                        if (uploaded != null) {
                          setDialogState(() => imagePath = uploaded);
                        }
                      },
                      child: Container(
                        width: 120.w,
                        height: 120.h,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: () {
                          final p = imagePath;
                          if (p != null && p.isNotEmpty) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: p.startsWith('/') || p.contains(':\\')
                                  ? Image.file(File(p), fit: BoxFit.cover)
                                  : Image.network(p, fit: BoxFit.cover),
                            );
                          }
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.primary,
                                size: 32.sp,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'إضافة صورة',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          );
                        }(),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _styledTextField(
                      controller: nameC,
                      label: 'اسم المنتج',
                      hint: 'مثال: فرشاة أسنان كهربائية',
                    ),
                    SizedBox(height: 12.h),
                    _styledTextField(
                      controller: priceC,
                      label: 'السعر (ر.س)',
                      hint: 'مثال: 49.99',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 12.h),
                    _styledTextField(
                      controller: brandC,
                      label: 'الماركة',
                      hint: 'مثال: NSK PANA-MAX',
                    ),
                    SizedBox(height: 12.h),
                    _styledTextField(
                      controller: descC,
                      label: 'الوصف',
                      hint: 'وصف المنتج...',
                      maxLines: 3,
                    ),
                    SizedBox(height: 12.h),
                    _styledTextField(
                      controller: stockC,
                      label: 'المخزون (عدد القطع)',
                      hint: 'مثال: 50',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId,
                      decoration: _inputDecoration('التصنيف'),
                      items: dummyCategories
                          .map(
                            (cat) => DropdownMenuItem(
                              value: cat.id,
                              child: Text(cat.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedCategoryId = v),
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAcademicYear,
                      decoration: _inputDecoration('السنة الدراسية (للطلاب)'),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('الكل - بدون تصنيف'),
                        ),
                        DropdownMenuItem(
                          value: 'الأولى',
                          child: Text('السنة الأولى'),
                        ),
                        DropdownMenuItem(
                          value: 'الثانية',
                          child: Text('السنة الثانية'),
                        ),
                        DropdownMenuItem(
                          value: 'الثالثة',
                          child: Text('السنة الثالثة'),
                        ),
                        DropdownMenuItem(
                          value: 'الرابعة',
                          child: Text('السنة الرابعة'),
                        ),
                        DropdownMenuItem(
                          value: 'الخامسة',
                          child: Text('السنة الخامسة'),
                        ),
                        DropdownMenuItem(
                          value: 'السادسة',
                          child: Text('السنة السادسة'),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedAcademicYear = v),
                    ),
                  ],
                ),
              ),
              actions: [
                _styledDialogButton(
                  'إلغاء',
                  onPressed: () => Navigator.pop(ctx),
                ),
                _styledConfirmButton(
                  isEdit ? 'حفظ' : 'إضافة',
                  onPressed: () {
                    final name = nameC.text.trim();
                    final price = double.tryParse(priceC.text.trim());
                    final stock = int.tryParse(stockC.text.trim()) ?? 0;
                    if (name.isEmpty ||
                        price == null ||
                        selectedCategoryId == null) {
                      return;
                    }
                    final cat = dummyCategories
                        .where((c) => c.id == selectedCategoryId)
                        .firstOrNull;
                    if (cat == null) return;
                    if (isEdit) {
                      updateProduct(
                        product.id,
                        name,
                        descC.text.trim(),
                        price,
                        imagePath ?? '',
                        cat.id,
                        cat.label,
                        brand: brandC.text.trim(),
                        stock: stock,
                        academicYear: selectedAcademicYear,
                      );
                    } else {
                      addProduct(
                        name,
                        descC.text.trim(),
                        price,
                        imagePath ?? '',
                        cat.id,
                        cat.label,
                        brand: brandC.text.trim(),
                        stock: stock,
                        academicYear: selectedAcademicYear,
                      );
                    }
                    Navigator.pop(ctx);
                    onDataChanged();
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ──────────────── BANNERS TAB ────────────────

class _BannersTab extends StatelessWidget {
  final VoidCallback onDataChanged;
  const _BannersTab({required this.onDataChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: dummyBanners.isEmpty
          ? _buildEmpty(context)
          : RefreshIndicator(
              onRefresh: () async => onDataChanged(),
              child: ListView.builder(
                padding: EdgeInsets.all(16.r),
                itemCount: dummyBanners.length,
                itemBuilder: (_, i) =>
                    _buildBannerCard(context, dummyBanners[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.textLight),
        onPressed: () => _showBannerDialog(context, null),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.slideshow_outlined, color: _kGrey, size: 48.sp),
          SizedBox(height: 12.h),
          Text(
            'لا توجد عروض',
            style: TextStyle(color: _kGrey, fontSize: 14.sp),
          ),
          SizedBox(height: 12.h),
          ElevatedButton.icon(
            icon: Icon(Icons.add, size: 18.sp),
            label: const Text('إضافة عرض'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () => _showBannerDialog(context, null),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerCard(BuildContext context, PromoBanner banner) {
    return Dismissible(
      key: Key(banner.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: AppColors.textLight,
          size: 28.sp,
        ),
      ),
      confirmDismiss: (_) => _showDeleteConfirmDialog(
        context,
        'حذف العرض',
        'هل أنت متأكد من حذف "${banner.title}"؟',
      ),
      onDismissed: (_) {
        deleteBanner(banner.id);
        onDataChanged();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          leading: Container(
            width: 56.w,
            height: 56.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF0E7C8F)],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                banner.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.image, color: AppColors.textLight, size: 28.sp),
              ),
            ),
          ),
          title: Text(
            banner.title,
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${banner.subtitle} • ${banner.discountText}',
            style: TextStyle(color: _kGrey, fontSize: 12.sp),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.notifications_active,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                  onPressed: () => _confirmSendNotification(context, banner),
                  tooltip: 'إرسال إشعار',
                  constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
                  padding: EdgeInsets.zero,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(Icons.edit_outlined, color: _kGrey, size: 20.sp),
            ],
          ),
          onTap: () => _showBannerDialog(context, banner),
        ),
      ),
    );
  }

  void _confirmSendNotification(BuildContext context, PromoBanner banner) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'إرسال إشعار',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 17.sp,
                ),
              ),
            ],
          ),
          content: Text(
            'سيتم إرسال إشعار لجميع المستخدمين حول:\n"${banner.title}"؟',
          ),
          actions: [
            _styledDialogButton('إلغاء', onPressed: () => Navigator.pop(ctx)),
            _styledConfirmButton(
              'إرسال',
              onPressed: () {
                Navigator.pop(ctx);
                _sendOfferNotification(
                  context,
                  banner.title,
                  banner.subtitle,
                  banner.imageUrl,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendOfferNotification(
    BuildContext context,
    String title,
    String body,
    String imageUrl,
  ) async {
    try {
      await ApiClient.instance.post(
        '/notification-campaigns',
        body: {
          'category': 'marketing',
          'audience': 'students',
          'title': title,
          'body': body,
          if (imageUrl.isNotEmpty) 'image_url': imageUrl,
          'action_route': '/store',
        },
        maxRetries: 0,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تمت جدولة الإشعار للإرسال على دفعات'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر جدولة الإشعار')));
    }
  }

  void _showBannerDialog(BuildContext context, PromoBanner? banner) {
    final titleC = TextEditingController(text: banner?.title ?? '');
    final subtitleC = TextEditingController(text: banner?.subtitle ?? '');
    final discountC = TextEditingController(text: banner?.discountText ?? '');
    final ctaC = TextEditingController(text: banner?.ctaText ?? '');
    final routeC = TextEditingController(
      text: banner?.actionRoute ?? '/promo-detail',
    );
    final isEdit = banner != null;
    String? imagePath = banner?.imageUrl;
    String? selectedProductId = banner?.productId;
    String? selectedCategoryId = banner?.categoryId;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.slideshow_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    isEdit ? 'تعديل العرض' : 'إضافة عرض',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 17.sp,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final uploaded = await StoreImageService.pickAndUpload(
                          kind: 'banner',
                        );
                        if (uploaded != null) {
                          setDialogState(() => imagePath = uploaded);
                        }
                      },
                      child: Container(
                        width: 120.w,
                        height: 120.h,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: () {
                          final p = imagePath;
                          if (p != null && p.isNotEmpty) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: p.startsWith('/') || p.contains(':\\')
                                  ? Image.file(File(p), fit: BoxFit.cover)
                                  : Image.network(p, fit: BoxFit.cover),
                            );
                          }
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.primary,
                                size: 32.sp,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'إضافة صورة',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          );
                        }(),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _styledTextField(
                      controller: titleC,
                      label: 'العنوان',
                      hint: 'مثال: خصم خاص',
                    ),
                    SizedBox(height: 12.h),
                    _styledTextField(
                      controller: subtitleC,
                      label: 'النص الفرعي',
                      hint: 'مثال: على أدوات العناية',
                    ),
                    SizedBox(height: 12.h),
                    _styledTextField(
                      controller: discountC,
                      label: 'نص الخصم',
                      hint: 'مثال: خصم 30%',
                    ),
                    SizedBox(height: 12.h),
                    _styledTextField(
                      controller: ctaC,
                      label: 'نص الزر',
                      hint: 'مثال: تسوق الآن',
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId,
                      decoration: _inputDecoration('الفئة (اختياري)'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('بدون فئة'),
                        ),
                        ...dummyCategories.map(
                          (cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Text(cat.label),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedCategoryId = v),
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      initialValue: selectedProductId,
                      decoration: _inputDecoration('المنتج (اختياري)'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('بدون منتج'),
                        ),
                        ...dummyProducts.map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedProductId = v),
                    ),
                    SizedBox(height: 12.h),
                    if (selectedProductId == null && selectedCategoryId == null)
                      _styledTextField(
                        controller: routeC,
                        label: 'رابط الإجراء',
                        hint: 'مثال: /promo-detail',
                      ),
                  ],
                ),
              ),
              actions: [
                _styledDialogButton(
                  'إلغاء',
                  onPressed: () => Navigator.pop(ctx),
                ),
                _styledConfirmButton(
                  isEdit ? 'حفظ' : 'إضافة',
                  onPressed: () {
                    if (titleC.text.trim().isEmpty) return;
                    if (isEdit) {
                      updateBanner(
                        banner.id,
                        titleC.text.trim(),
                        subtitleC.text.trim(),
                        discountC.text.trim(),
                        imagePath ?? '',
                        ctaC.text.trim(),
                        routeC.text.trim(),
                        productId: selectedProductId,
                        categoryId: selectedCategoryId,
                      );
                    } else {
                      addBanner(
                        titleC.text.trim(),
                        subtitleC.text.trim(),
                        discountC.text.trim(),
                        imagePath ?? '',
                        ctaC.text.trim(),
                        routeC.text.trim(),
                        productId: selectedProductId,
                        categoryId: selectedCategoryId,
                      );
                    }
                    Navigator.pop(ctx);
                    onDataChanged();
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ──────────────── COUPONS TAB ────────────────

class _CouponsTab extends StatelessWidget {
  final VoidCallback onDataChanged;
  const _CouponsTab({required this.onDataChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: dummyCoupons.isEmpty
          ? _buildEmpty(context)
          : RefreshIndicator(
              onRefresh: () async => onDataChanged(),
              child: ListView.builder(
                padding: EdgeInsets.all(16.r),
                itemCount: dummyCoupons.length,
                itemBuilder: (_, i) =>
                    _buildCouponCard(context, dummyCoupons[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.textLight),
        onPressed: () => _showCouponDialog(context, null),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.discount_outlined, color: _kGrey, size: 48.sp),
          SizedBox(height: 12.h),
          Text(
            'لا توجد كوبونات',
            style: TextStyle(color: _kGrey, fontSize: 14.sp),
          ),
          SizedBox(height: 12.h),
          ElevatedButton.icon(
            icon: Icon(Icons.add, size: 18.sp),
            label: const Text('إضافة كوبون'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () => _showCouponDialog(context, null),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(BuildContext context, Coupon coupon) {
    final expired =
        coupon.expiresAt != null && coupon.expiresAt!.isBefore(DateTime.now());
    return Dismissible(
      key: Key(coupon.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: AppColors.textLight,
          size: 28.sp,
        ),
      ),
      confirmDismiss: (_) => _showDeleteConfirmDialog(
        context,
        'حذف الكوبون',
        'هل أنت متأكد من حذف "${coupon.code}"؟',
      ),
      onDismissed: (_) {
        deleteCoupon(coupon.id);
        onDataChanged();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (expired || !coupon.isActive)
                ? Colors.red.withValues(alpha: 0.2)
                : AppColors.divider.withValues(alpha: 0.5),
          ),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          leading: Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              color: expired || !coupon.isActive
                  ? Colors.red.withValues(alpha: 0.1)
                  : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.discount_outlined,
              color: expired || !coupon.isActive
                  ? Colors.red
                  : AppColors.primary,
              size: 24.sp,
            ),
          ),
          title: Row(
            children: [
              Text(
                coupon.code,
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(width: 8.w),
              if (expired || !coupon.isActive)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    expired ? 'منتهي' : 'معطل',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4.h),
              Text(
                coupon.description,
                style: TextStyle(color: _kGrey, fontSize: 12.sp),
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      coupon.discountType == 'percentage'
                          ? '${coupon.discountValue.toStringAsFixed(0)}%'
                          : '${coupon.discountValue.toStringAsFixed(0)} ر.س',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (coupon.minPurchase != null) ...[
                    SizedBox(width: 8.w),
                    Text(
                      'أقل فاتورة: ${coupon.minPurchase!.toStringAsFixed(0)} ر.س',
                      style: TextStyle(color: _kGrey, fontSize: 10.sp),
                    ),
                  ],
                  if (coupon.expiresAt != null) ...[
                    SizedBox(width: 8.w),
                    Text(
                      'حتى: ${coupon.expiresAt!.day}/${coupon.expiresAt!.month}',
                      style: TextStyle(color: _kGrey, fontSize: 10.sp),
                    ),
                  ],
                ],
              ),
              if (coupon.categoryId != null || coupon.productId != null) ...[
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.category_outlined, size: 12.sp, color: _kGrey),
                    SizedBox(width: 4.w),
                    Text(
                      coupon.categoryId != null
                          ? (dummyCategories
                                    .where((c) => c.id == coupon.categoryId)
                                    .firstOrNull
                                    ?.label ??
                                'فئة')
                          : (dummyProducts
                                    .where((p) => p.id == coupon.productId)
                                    .firstOrNull
                                    ?.name ??
                                'منتج'),
                      style: TextStyle(color: _kGrey, fontSize: 10.sp),
                    ),
                  ],
                ),
              ],
            ],
          ),
          trailing: Icon(Icons.edit_outlined, color: _kGrey, size: 20.sp),
          onTap: () => _showCouponDialog(context, coupon),
        ),
      ),
    );
  }

  void _showCouponDialog(BuildContext context, Coupon? coupon) {
    final codeC = TextEditingController(text: coupon?.code ?? '');
    final descC = TextEditingController(text: coupon?.description ?? '');
    final valueC = TextEditingController(
      text: coupon != null ? coupon.discountValue.toStringAsFixed(0) : '',
    );
    final existingMin = coupon?.minPurchase;
    final minC = TextEditingController(
      text: existingMin != null ? existingMin.toStringAsFixed(0) : '',
    );
    final isEdit = coupon != null;
    String discountType = coupon?.discountType ?? 'percentage';
    DateTime? expiresAt = coupon?.expiresAt;
    bool isActive = coupon?.isActive ?? true;
    String? selectedCategoryId = coupon?.categoryId;
    String? selectedProductId = coupon?.productId;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 20.h,
              ),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.discount_outlined,
                      color: AppColors.primary,
                      size: 22.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    isEdit ? 'تعديل الكوبون' : 'إضافة كوبون',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 17.sp,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _styledTextField(
                      controller: codeC,
                      label: 'كود الكوبون',
                      hint: 'مثال: SAVE20',
                    ),
                    SizedBox(height: 12.h),
                    _styledTextField(
                      controller: descC,
                      label: 'الوصف',
                      hint: 'مثال: خصم 20% على المشتريات',
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: _styledTextField(
                            controller: valueC,
                            label: 'قيمة الخصم',
                            hint: 'مثال: 20',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: discountType,
                            decoration: _inputDecoration('نوع الخصم'),
                            items: const [
                              DropdownMenuItem(
                                value: 'percentage',
                                child: Text('نسبة %'),
                              ),
                              DropdownMenuItem(
                                value: 'fixed',
                                child: Text('قيمة ثابتة'),
                              ),
                            ],
                            onChanged: (v) =>
                                setDialogState(() => discountType = v!),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    _styledTextField(
                      controller: minC,
                      label: 'أقل فاتورة (اختياري)',
                      hint: 'مثال: 100',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId,
                      decoration: _inputDecoration('الفئة (اختياري)'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('جميع الفئات'),
                        ),
                        ...dummyCategories.map(
                          (cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Text(cat.label),
                          ),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() {
                        selectedCategoryId = v;
                        if (v != null) selectedProductId = null;
                      }),
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      initialValue: selectedProductId,
                      decoration: _inputDecoration('المنتج (اختياري)'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('جميع المنتجات'),
                        ),
                        ...dummyProducts.map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() {
                        selectedProductId = v;
                        if (v != null) selectedCategoryId = null;
                      }),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.divider),
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            icon: Icon(Icons.calendar_today, size: 16.sp),
                            label: Text(
                              expiresAt != null
                                  ? '${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}'
                                  : 'تاريخ الانتهاء',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    expiresAt ??
                                    DateTime.now().add(
                                      const Duration(days: 30),
                                    ),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() => expiresAt = picked);
                              }
                            },
                          ),
                        ),
                        if (isEdit) ...[
                          SizedBox(width: 10.w),
                          GestureDetector(
                            onTap: () =>
                                setDialogState(() => isActive = !isActive),
                            child: Container(
                              padding: EdgeInsets.all(10.r),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.success.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                isActive ? Icons.check_circle : Icons.block,
                                color: isActive
                                    ? AppColors.success
                                    : Colors.red,
                                size: 24.sp,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                _styledDialogButton(
                  'إلغاء',
                  onPressed: () => Navigator.pop(ctx),
                ),
                _styledConfirmButton(
                  isEdit ? 'حفظ' : 'إضافة',
                  onPressed: () {
                    if (codeC.text.trim().isEmpty ||
                        valueC.text.trim().isEmpty) {
                      return;
                    }
                    final value = double.tryParse(valueC.text.trim()) ?? 0;
                    final minVal = double.tryParse(minC.text.trim());
                    if (isEdit) {
                      updateCoupon(
                        coupon.id,
                        codeC.text.trim().toUpperCase(),
                        descC.text.trim(),
                        discountType,
                        value,
                        minPurchase: minVal,
                        expiresAt: expiresAt,
                        isActive: isActive,
                        productId: selectedProductId,
                        categoryId: selectedCategoryId,
                      );
                    } else {
                      addCoupon(
                        codeC.text.trim().toUpperCase(),
                        descC.text.trim(),
                        discountType,
                        value,
                        minPurchase: minVal,
                        expiresAt: expiresAt,
                        productId: selectedProductId,
                        categoryId: selectedCategoryId,
                      );
                    }
                    Navigator.pop(ctx);
                    onDataChanged();
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ──────────────── ORDERS TAB ────────────────

class _OrdersTab extends StatefulWidget {
  final VoidCallback onDataChanged;
  const _OrdersTab({required this.onDataChanged});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  @override
  Widget build(BuildContext context) {
    final allOrders = <Order>[];
    if (allOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, color: _kGrey, size: 48.sp),
            SizedBox(height: 12.h),
            Text(
              'لا توجد طلبات بعد',
              style: TextStyle(color: _kGrey, fontSize: 14.sp),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => widget.onDataChanged(),
      child: ListView.builder(
        padding: EdgeInsets.all(16.r),
        itemCount: allOrders.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return _buildMonthlyReportCard(context, allOrders, allOrders);
          }
          return _buildOrderCard(context, allOrders[i - 1]);
        },
      ),
    );
  }

  Widget _buildMonthlyReportCard(
    BuildContext context,
    List<Order> orders,
    List<Order> allOrders,
  ) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthOrders = orders
        .where(
          (o) =>
              o.createdAt.isAfter(monthStart) &&
              o.status != OrderStatus.cancelled,
        )
        .toList();

    final totalRevenue = monthOrders.fold<double>(
      0,
      (s, o) => s + o.totalPrice,
    );
    final totalDelivery = monthOrders.fold<double>(
      0,
      (s, o) => s + o.deliveryPrice,
    );
    final totalItems = monthOrders.fold<int>(
      0,
      (s, o) => s + o.items.fold<int>(0, (a, i) => a + i.quantity),
    );
    final avgOrder = monthOrders.isNotEmpty
        ? totalRevenue / monthOrders.length
        : 0.0;

    final statusCounts = {
      OrderStatus.pending: orders
          .where((o) => o.status == OrderStatus.pending)
          .length,
      OrderStatus.accepted: orders
          .where((o) => o.status == OrderStatus.accepted)
          .length,
      OrderStatus.preparing: orders
          .where((o) => o.status == OrderStatus.preparing)
          .length,
      OrderStatus.outForDelivery: orders
          .where((o) => o.status == OrderStatus.outForDelivery)
          .length,
      OrderStatus.delivered: orders
          .where((o) => o.status == OrderStatus.delivered)
          .length,
      OrderStatus.cancelled: orders
          .where((o) => o.status == OrderStatus.cancelled)
          .length,
    };

    final productMap = <String, int>{};
    for (final o in monthOrders) {
      for (final i in o.items) {
        productMap[i.product.name] =
            (productMap[i.product.name] ?? 0) + i.quantity;
      }
    }
    final sortedProducts = productMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        _buildMainStatsCard(
          context,
          totalRevenue,
          totalItems,
          monthOrders.length,
          avgOrder,
          totalDelivery,
        ),
        SizedBox(height: 10.h),
        _buildStatusBar(context, statusCounts, orders.length),
        SizedBox(height: 10.h),
        _buildTopProductsCard(context, sortedProducts),
        SizedBox(height: 10.h),
        _buildRevenueChart(context, orders),
      ],
    );
  }

  Widget _buildMainStatsCard(
    BuildContext context,
    double totalRevenue,
    int totalItems,
    int orderCount,
    double avgOrder,
    double totalDelivery,
  ) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(width: 14.w),
              Text(
                'إحصائيات هذا الشهر',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              _statItem(
                Icons.receipt_long,
                'الطلبات',
                '$orderCount',
                Colors.white,
              ),
              SizedBox(width: 8.w),
              _statItem(
                Icons.payments_rounded,
                'الإيرادات',
                '${totalRevenue.toStringAsFixed(0)} ر.س',
                Colors.white,
              ),
              SizedBox(width: 8.w),
              _statItem(
                Icons.inventory_2_rounded,
                'المنتجات',
                '$totalItems',
                Colors.white,
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              _statItem(
                Icons.local_shipping,
                'التوصيل',
                '${totalDelivery.toStringAsFixed(0)} ر.س',
                Colors.white70,
              ),
              SizedBox(width: 8.w),
              _statItem(
                Icons.trending_up,
                'متوسط الطلب',
                '${avgOrder.toStringAsFixed(0)} ر.س',
                Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(
    BuildContext context,
    Map<OrderStatus, int> counts,
    int total,
  ) {
    if (total == 0) return const SizedBox.shrink();
    final colors = {
      OrderStatus.pending: AppColors.pending,
      OrderStatus.accepted: AppColors.primary,
      OrderStatus.preparing: const Color(0xFF9C27B0),
      OrderStatus.outForDelivery: const Color(0xFF2196F3),
      OrderStatus.delivered: AppColors.success,
      OrderStatus.cancelled: Colors.red,
    };
    final labels = {
      OrderStatus.pending: 'بانتظار',
      OrderStatus.accepted: 'مقبول',
      OrderStatus.preparing: 'تحضير',
      OrderStatus.outForDelivery: 'توصيل',
      OrderStatus.delivered: 'تم',
      OrderStatus.cancelled: 'ملغي',
    };

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                color: AppColors.primary,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                'توزيع حالات الطلبات',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10.h,
              child: Row(
                children: OrderStatus.values.map((s) {
                  final pct = total > 0 ? counts[s]! / total : 0.0;
                  return Expanded(
                    flex: (pct * 100).round().clamp(1, 100),
                    child: Container(color: colors[s]!.withValues(alpha: 0.8)),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 4.h,
            children: OrderStatus.values.where((s) => counts[s]! > 0).map((s) {
              final pct = total > 0
                  ? (counts[s]! / total * 100).toStringAsFixed(0)
                  : '0';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8.w,
                    height: 8.h,
                    decoration: BoxDecoration(
                      color: colors[s],
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '${labels[s]}: ${counts[s]} ($pct%)',
                    style: TextStyle(color: _kGrey, fontSize: 10.sp),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(
    BuildContext context,
    List<MapEntry<String, int>> sortedProducts,
  ) {
    if (sortedProducts.isEmpty) return const SizedBox.shrink();
    final top5 = sortedProducts.take(5).toList();
    final maxQty = top5.isNotEmpty ? top5.first.value : 1;

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.production_quantity_limits,
                color: AppColors.primary,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                'أفضل 5 منتجات مبيعاً',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...top5.asMap().entries.map((entry) {
            final i = entry.key;
            final product = entry.value;
            final ratio = product.value / maxQty;
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${i + 1}.',
                        style: TextStyle(color: _kGrey, fontSize: 11.sp),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          product.key,
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 12.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${product.value}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6.h,
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            color: AppColors.divider.withValues(alpha: 0.3),
                          ),
                          FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withValues(alpha: 0.6),
                                  ],
                                ),
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
          }),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(BuildContext context, List<Order> orders) {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - (6 - i)),
    );
    final dailyRevenue = days.map((d) {
      final dayStart = DateTime(d.year, d.month, d.day);
      final dayEnd = dayStart.add(const Duration(hours: 24));
      return orders
          .where(
            (o) =>
                o.createdAt.isAfter(dayStart) &&
                o.createdAt.isBefore(dayEnd) &&
                o.status != OrderStatus.cancelled,
          )
          .fold<double>(0, (s, o) => s + o.totalPrice);
    }).toList();
    final maxRev = dailyRevenue.reduce((a, b) => a > b ? a : b);

    final dayNames = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: AppColors.primary, size: 16.sp),
              SizedBox(width: 6.w),
              Text(
                'إيرادات آخر 7 أيام',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 120.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final rev = dailyRevenue[i];
                final pct = maxRev > 0 ? rev / maxRev : 0.0;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          rev.toStringAsFixed(0),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          height: (pct * 80).clamp(4.0, 80.0).h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.5),
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(6.r),
                            ),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          dayNames[days[i].weekday == 7
                              ? 6
                              : days[i].weekday - 1],
                          style: TextStyle(color: _kGrey, fontSize: 8.sp),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.pending;
      case OrderStatus.accepted:
        return AppColors.primary;
      case OrderStatus.preparing:
        return const Color(0xFF9C27B0);
      case OrderStatus.outForDelivery:
        return const Color(0xFF2196F3);
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final statusColor = _statusColor(order.status);
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(Icons.receipt, color: statusColor, size: 20.sp),
        ),
        title: Row(
          children: [
            Text(
              'طلب #${order.id.substring(0, 8)}',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                orderStatusLabel(order.status),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${order.items.length} منتج • ${order.totalPrice.toStringAsFixed(0)} ر.س',
          style: TextStyle(color: _kGrey, fontSize: 12.sp),
        ),
        children: [
          const Divider(),
          ...order.items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    color: _kGrey.withValues(alpha: 0.5),
                    size: 14.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      item.product.name,
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 12.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${item.quantity}× ${item.totalPrice.toStringAsFixed(0)} ر.س',
                    style: TextStyle(color: _kGrey, fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 4.h),
          if (order.doctorName != null && order.doctorName!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 12.sp, color: _kGrey),
                  SizedBox(width: 4.w),
                  Text(
                    'الطبيب: ${order.doctorName}',
                    style: TextStyle(
                      color: _kGrey,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          if (order.doctorGovernorate != null &&
              order.doctorGovernorate!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Row(
                children: [
                  Icon(Icons.location_city, size: 12.sp, color: _kGrey),
                  SizedBox(width: 4.w),
                  Text(
                    'المحافظة: ${order.doctorGovernorate}',
                    style: TextStyle(color: _kGrey, fontSize: 11.sp),
                  ),
                ],
              ),
            ),
          if (order.doctorPhone != null && order.doctorPhone!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Row(
                children: [
                  Icon(Icons.phone_outlined, size: 12.sp, color: _kGrey),
                  SizedBox(width: 4.w),
                  Text(
                    'رقم: ${order.doctorPhone}',
                    style: TextStyle(color: _kGrey, fontSize: 11.sp),
                  ),
                ],
              ),
            ),
          if (order.clinicAddress != null && order.clinicAddress!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 12.sp, color: _kGrey),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      'العيادة: ${order.clinicAddress}',
                      style: TextStyle(color: _kGrey, fontSize: 11.sp),
                    ),
                  ),
                ],
              ),
            ),
          if (order.shippingAddress != null &&
              order.shippingAddress!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Text(
                'العنوان: ${order.shippingAddress}',
                style: TextStyle(color: _kGrey, fontSize: 11.sp),
              ),
            ),
          if (order.governorate != null || order.region != null)
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, size: 12.sp, color: _kGrey),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      '${order.governorate ?? ''} ${order.region ?? ''}'.trim(),
                      style: TextStyle(color: _kGrey, fontSize: 11.sp),
                    ),
                  ),
                ],
              ),
            ),
          if (order.phone != null && order.phone!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Row(
                children: [
                  Icon(Icons.phone_outlined, size: 12.sp, color: _kGrey),
                  SizedBox(width: 4.w),
                  Text(
                    'الهاتف: ${order.phone}',
                    style: TextStyle(color: _kGrey, fontSize: 11.sp),
                  ),
                ],
              ),
            ),
          if (order.paymentMethod != null)
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Row(
                children: [
                  Icon(Icons.payment_outlined, size: 12.sp, color: _kGrey),
                  SizedBox(width: 4.w),
                  Text(
                    'الدفع: ${order.paymentMethod == 'sham_cash' ? 'شام كاش' : 'دفع عند الاستلام'}',
                    style: TextStyle(color: _kGrey, fontSize: 11.sp),
                  ),
                ],
              ),
            ),
          if (order.deliveryPrice > 0)
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 12.sp,
                    color: _kGrey,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'التوصيل: ${order.deliveryPrice.toStringAsFixed(0)} ر.س',
                    style: TextStyle(color: _kGrey, fontSize: 11.sp),
                  ),
                ],
              ),
            ),
          if (order.couponCode != null &&
              order.discountAmount != null &&
              order.discountAmount! > 0)
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Row(
                children: [
                  Icon(Icons.discount_outlined, size: 12.sp, color: _kGrey),
                  SizedBox(width: 4.w),
                  Text(
                    'خصم (${order.couponCode}): ${order.discountAmount!.toStringAsFixed(0)} ر.س',
                    style: TextStyle(color: _kGrey, fontSize: 11.sp),
                  ),
                ],
              ),
            ),
          Text(
            'تاريخ: ${_formatDate(order.createdAt)}',
            style: TextStyle(color: _kGrey, fontSize: 11.sp),
          ),
          if (order.status == OrderStatus.pending) ...[
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _styledDialogButton(
                  'رفض',
                  color: Colors.red,
                  onPressed: () {
                    widget.onDataChanged();
                  },
                ),
                SizedBox(width: 8.w),
                _styledConfirmButton(
                  'قبول',
                  onPressed: () {
                    widget.onDataChanged();
                  },
                ),
              ],
            ),
          ],
          if (order.status == OrderStatus.accepted) ...[
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _styledDialogButton(
                  'قيد التحضير',
                  color: const Color(0xFF9C27B0),
                  onPressed: () {
                    widget.onDataChanged();
                  },
                ),
                SizedBox(width: 8.w),
                _styledDialogButton(
                  'إلغاء',
                  color: Colors.red,
                  onPressed: () {
                    widget.onDataChanged();
                  },
                ),
              ],
            ),
          ],
          if (order.status == OrderStatus.preparing) ...[
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _styledDialogButton(
                  'خرج للتوصيل',
                  color: const Color(0xFF2196F3),
                  onPressed: () {
                    widget.onDataChanged();
                  },
                ),
                SizedBox(width: 8.w),
                _styledDialogButton(
                  'إلغاء',
                  color: Colors.red,
                  onPressed: () {
                    widget.onDataChanged();
                  },
                ),
              ],
            ),
          ],
          if (order.status == OrderStatus.outForDelivery) ...[
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _styledDialogButton(
                  'تم التسليم',
                  color: AppColors.success,
                  onPressed: () {
                    widget.onDataChanged();
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────── SHARED DIALOG HELPERS ────────────────

class _DialogField {
  final TextEditingController controller;
  final String label, hint;
  _DialogField({
    required this.controller,
    required this.label,
    required this.hint,
  });
}

void _showFormDialog({
  required BuildContext context,
  required String title,
  required IconData icon,
  required List<_DialogField> fields,
  required VoidCallback onSave,
}) {
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22.sp),
            ),
            SizedBox(width: 10.w),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 17.sp,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: fields
              .map(
                (f) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _styledTextField(
                    controller: f.controller,
                    label: f.label,
                    hint: f.hint,
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          _styledDialogButton('إلغاء', onPressed: () => Navigator.pop(ctx)),
          _styledConfirmButton(
            'حفظ',
            onPressed: () {
              Navigator.pop(ctx);
              onSave();
            },
          ),
        ],
      ),
    ),
  );
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.primarySurface.withValues(alpha: 0.3),
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5.w),
    ),
  );
}

Widget _styledTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    decoration: _inputDecoration(label).copyWith(hintText: hint),
  );
}
