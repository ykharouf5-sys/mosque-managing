import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';

const Color _kGrey = Color(0xFF9E9E9E);

class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() async {
      try {
        await ref.read(ordersProvider.notifier).loadInitialOrders();
      } catch (_) {
        // Keep locally queued/cached orders visible while offline.
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final ordersNotifier = ref.read(ordersProvider.notifier);
    final ordersState = ref.read(ordersProvider);
    if (!ordersState.isLoadingMore &&
        ordersState.hasMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      ordersNotifier.loadNextOrdersPage();
    }
  }

  Color _statusColor(OrderStatus status) {
    if (status == OrderStatus.delivered) return AppColors.success;
    if (status == OrderStatus.cancelled) return Colors.red;
    return AppColors.primary;
  }

  IconData _statusIcon(OrderStatus status) {
    if (status == OrderStatus.delivered) return Icons.verified;
    if (status == OrderStatus.cancelled) return Icons.cancel_outlined;
    return Icons.check_circle_outline;
  }

  String _customerStatusLabel(OrderStatus status) {
    if (status == OrderStatus.delivered) return 'تم التوصيل';
    if (status == OrderStatus.cancelled) return 'لم يتم التوصيل';
    return 'تم الطلب';
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);
    final myOrders = ordersState.orders;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: const AppBottomNav(selectedIndex: -1),
        appBar: AppBar(
          title: const Text('طلباتي'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: myOrders.isEmpty && !ordersState.isLoadingMore
            ? _buildEmpty()
            : ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16.r),
                itemCount:
                    myOrders.length + (ordersState.isLoadingMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= myOrders.length) {
                    return Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }
                  return _buildOrderCard(myOrders[i]);
                },
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, color: _kGrey, size: 64.sp),
          SizedBox(height: 16.h),
          Text(
            'لا توجد طلبات',
            style: TextStyle(color: _kGrey, fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'قم بتسوق المنتجات من المتجر',
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

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = _statusColor(order.status);
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        shape: const Border(),
        leading: Container(
          width: 44.w,
          height: 44.h,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _statusIcon(order.status),
            color: statusColor,
            size: 22.sp,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'طلب #${order.id.substring(0, 8)}',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _customerStatusLabel(order.status),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              '${order.items.length} منتج',
              style: TextStyle(color: _kGrey, fontSize: 12.sp),
            ),
            const Spacer(),
            Text(
              '${order.totalPrice.toStringAsFixed(0)} ر.س',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        children: [
          const Divider(),
          SizedBox(height: 4.h),
          ...order.items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    color: _kGrey.withValues(alpha: 0.5),
                    size: 16.sp,
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
                    '${item.quantity}×',
                    style: TextStyle(color: _kGrey, fontSize: 12.sp),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '${item.totalPrice.toStringAsFixed(0)} ر.س',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تاريخ الطلب: ${_formatDate(order.createdAt)}',
                style: TextStyle(color: _kGrey, fontSize: 11.sp),
              ),
              Text(
                'المجموع: ${order.totalPrice.toStringAsFixed(0)} ر.س',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
