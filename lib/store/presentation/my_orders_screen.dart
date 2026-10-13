import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/store/presentation/store_ui.dart';
import 'dart:async';

import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/shared/widgets/refresh_visibility.dart';
import 'package:studentry/shared/data/connectivity_service.dart';
import 'package:studentry/shared/data/fcm_token_service.dart';

const Color _kGrey = Color(0xFF9E9E9E);

class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;
  StreamSubscription<void>? _pushSubscription;
  bool _visible = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    ConnectivityService.isOnline.addListener(_onConnectivity);
    _scrollController.addListener(_onScroll);
    _pushSubscription = FcmTokenService.orderChanges.listen((_) {
      _dirty = true;
      if (_visible) unawaited(_refreshSilently(force: true));
    });
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    ConnectivityService.isOnline.removeListener(_onConnectivity);
    _refreshTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onVisibility(bool active) {
    _visible = active;
    _refreshTimer?.cancel();
    if (active) {
      unawaited(_refreshSilently(force: _dirty));
      _refreshTimer = Timer.periodic(Duration(seconds: 75), (_) {
        final notifier = ref.read(ordersProvider.notifier);
        if (notifier.hasActiveOrders ||
            !notifier.lastRefreshSucceeded ||
            _dirty) {
          unawaited(_refreshSilently(force: _dirty));
        }
      });
    }
  }

  void _onConnectivity() {
    if (_visible && ConnectivityService.isOnline.value) {
      unawaited(_refreshSilently(force: _dirty));
    }
  }

  Future<void> _refreshSilently({bool force = false}) async {
    if (!mounted || !_visible || !ConnectivityService.isOnline.value) return;
    try {
      final notifier = ref.read(ordersProvider.notifier);
      await notifier.loadInitialOrders(force: force);
      if (notifier.lastRefreshSucceeded) _dirty = false;
    } catch (_) {
      // Keep the last account-scoped snapshot visible while temporarily offline.
    }
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
    if (status == OrderStatus.cancelled || status == OrderStatus.rejected) {
      return Colors.red;
    }
    return AppColors.primary;
  }

  IconData _statusIcon(OrderStatus status) {
    if (status == OrderStatus.delivered) return Icons.verified;
    if (status == OrderStatus.cancelled || status == OrderStatus.rejected) {
      return Icons.cancel_outlined;
    }
    return Icons.check_circle_outline;
  }

  String _customerStatusLabel(Order order) {
    if (order.submissionError != null) return 'تعذر إرسال الطلب';
    if (order.awaitingSync) return 'بانتظار الإرسال';
    switch (order.status) {
      case OrderStatus.pending:
        return 'تم إرسال الطلب';
      case OrderStatus.accepted:
      case OrderStatus.preparing:
      case OrderStatus.outForDelivery:
        return 'تم قبول الطلب';
      case OrderStatus.delivered:
        return 'تم التوصيل';
      case OrderStatus.rejected:
        return 'تم رفض الطلب';
      case OrderStatus.cancelled:
        return 'تم إلغاء الطلب';
    }
  }

  @override
  Widget build(BuildContext context) => RefreshVisibility(
    onChanged: _onVisibility,
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);
    final myOrders = ordersState.orders;

    return Directionality(
      textDirection: AppLocale.language == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: AppBottomNav(selectedIndex: -1),
        appBar: AppBar(
          title: Text(storeUi('طلباتي')),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: myOrders.isEmpty && !ordersState.isLoadingMore
            ? _buildEmpty()
            : RefreshIndicator(
                onRefresh: () => ref
                    .read(ordersProvider.notifier)
                    .loadInitialOrders(force: true),
                child: ListView.builder(
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
            storeUi('لا توجد طلبات'),
            style: TextStyle(color: _kGrey, fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            storeUi('قم بتسوق المنتجات من المتجر'),
            style: TextStyle(color: _kGrey, fontSize: 13.sp),
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(storeUi('تسوق الآن')),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = order.submissionError != null
        ? Colors.red
        : _statusColor(order.status);
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
        shape: Border(),
        leading: Container(
          width: 44.w,
          height: 44.h,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            order.submissionError != null
                ? Icons.error_outline
                : order.awaitingSync
                ? Icons.cloud_upload_outlined
                : _statusIcon(order.status),
            color: statusColor,
            size: 22.sp,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                AppLocale.text(
                  'طلب #${order.id.substring(0, 8)}',
                  'Order #${order.id.substring(0, 8)}',
                ),
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
                _customerStatusLabel(order),
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
              AppLocale.text(
                '${order.items.length} منتج',
                '${order.items.length} products',
              ),
              style: TextStyle(color: _kGrey, fontSize: 12.sp),
            ),
            Spacer(),
            Text(
              storeUi('${order.totalPrice.toStringAsFixed(0)} SYP'),
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        children: [
          Divider(),
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
                    storeUi('${item.totalPrice.toStringAsFixed(0)} SYP'),
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
                AppLocale.text(
                  'تاريخ الطلب: ${_formatDate(order.createdAt)}',
                  'Order date: ${_formatDate(order.createdAt)}',
                ),
                style: TextStyle(color: _kGrey, fontSize: 11.sp),
              ),
              Text(
                AppLocale.text(
                  'المجموع: ${order.totalPrice.toStringAsFixed(0)} SYP',
                  'Total: ${order.totalPrice.toStringAsFixed(0)} SYP',
                ),
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
