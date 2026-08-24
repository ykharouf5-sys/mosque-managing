import 'package:dentalcare/shared/widgets/app_bottom_nav.dart';
import 'package:dentalcare/store/data/store_models.dart';
import 'package:dentalcare/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dentalcare/store/presentation/providers/store_providers.dart';

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

  IconData _statusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.accepted:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.inventory_2;
      case OrderStatus.outForDelivery:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.verified;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  static const List<OrderStatus> _timelineSteps = [
    OrderStatus.pending,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  static const Map<OrderStatus, String> _timelineLabels = {
    OrderStatus.pending: 'قيد الانتظار',
    OrderStatus.accepted: 'تم القبول',
    OrderStatus.preparing: 'قيد التحضير',
    OrderStatus.outForDelivery: 'خرج للتوصيل',
    OrderStatus.delivered: 'تم التسليم',
  };

  static const Map<OrderStatus, IconData> _timelineIcons = {
    OrderStatus.pending: Icons.schedule,
    OrderStatus.accepted: Icons.check_circle_outline,
    OrderStatus.preparing: Icons.inventory_2,
    OrderStatus.outForDelivery: Icons.local_shipping,
    OrderStatus.delivered: Icons.verified,
  };

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
    final isCancelled = order.status == OrderStatus.cancelled;
    final currentStepIdx = _timelineSteps.indexOf(order.status);

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
          _buildTimeline(order, currentStepIdx, isCancelled),
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

  Widget _buildTimeline(Order order, int currentStepIdx, bool isCancelled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تتبع الطلب',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12.h),
        ...List.generate(_timelineSteps.length, (i) {
          final step = _timelineSteps[i];
          final isCompleted = i <= currentStepIdx && !isCancelled;
          final isCurrent = i == currentStepIdx && !isCancelled;
          final isLast = i == _timelineSteps.length - 1;
          final icon = _timelineIcons[step]!;
          final label = _timelineLabels[step]!;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28.w,
                  child: Column(
                    children: [
                      Container(
                        width: isCurrent ? 22.w : 18.w,
                        height: isCurrent ? 22.h : 18.h,
                        decoration: BoxDecoration(
                          color: isCancelled
                              ? (i == 0
                                    ? Colors.red
                                    : _kGrey.withValues(alpha: 0.3))
                              : (isCompleted
                                    ? _statusColor(step)
                                    : _kGrey.withValues(alpha: 0.3)),
                          shape: BoxShape.circle,
                        ),
                        child: isCompleted && !isCancelled
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 10.sp,
                              )
                            : Icon(icon, color: Colors.white, size: 10.sp),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2.w,
                            color: isCancelled
                                ? (i == 0
                                      ? Colors.red.withValues(alpha: 0.4)
                                      : _kGrey.withValues(alpha: 0.2))
                                : (isCompleted
                                      ? _statusColor(
                                          step,
                                        ).withValues(alpha: 0.4)
                                      : _kGrey.withValues(alpha: 0.2)),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isCancelled
                              ? (i == 0 ? Colors.red : _kGrey)
                              : (isCompleted ? AppColors.textDark : _kGrey),
                          fontSize: isCurrent ? 13.sp : 12.sp,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (isCurrent && !isCancelled)
                        Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Text(
                            order.status == OrderStatus.pending
                                ? 'بانتظار المراجعة'
                                : 'تمت هذه الخطوة',
                            style: TextStyle(
                              color: _statusColor(order.status),
                              fontSize: 10.sp,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        if (isCancelled)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Row(
              children: [
                Icon(Icons.cancel, color: Colors.red, size: 16.sp),
                SizedBox(width: 6.w),
                Text(
                  'تم إلغاء الطلب',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
