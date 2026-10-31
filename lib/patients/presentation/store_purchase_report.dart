import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/utils/variable_colors.dart';

bool isConfirmedPurchase(Order order) =>
    !order.awaitingSync &&
    const {
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    }.contains(order.status);

/// Reads all pages for this account; does not mistake a partially loaded order
/// list for the whole report and never persists another account's response.
final storePurchaseReportProvider = FutureProvider.autoDispose<List<Order>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (!auth.isLoggedIn) return [];
  final generation = AuthService().sessionGeneration;
  final result = <Order>[];
  var page = 0;
  while (true) {
    final response = await StoreApiService.fetchOrderPage(page, 50);
    if (generation != AuthService().sessionGeneration) {
      throw StateError('Account changed');
    }
    result.addAll(
      response.rows.map(
        (row) => Order.fromJson(StoreApiService.rowToOrderMap(row)),
      ),
    );
    if (!response.hasMore) break;
    page++;
  }
  return result.where((order) => order.userId == auth.userId).toList();
});

class StorePurchaseReport extends ConsumerStatefulWidget {
  const StorePurchaseReport({super.key});
  @override
  ConsumerState<StorePurchaseReport> createState() =>
      _StorePurchaseReportState();
}

class _StorePurchaseReportState extends ConsumerState<StorePurchaseReport> {
  int _period = 1;
  String _money(num value) =>
      '${NumberFormat('#,##0.##', 'ar').format(value)} ل.س';
  bool _inPeriod(Order order) {
    final date = order.createdAt.toLocal();
    final now = DateTime.now();
    return _period == 2 ||
        date.year == now.year &&
            date.month == now.month &&
            (_period == 1 || date.day == now.day);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(storePurchaseReportProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(storePurchaseReportProvider);
        await ref.read(storePurchaseReportProvider.future);
      },
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, stack) => ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'تعذر تحميل المشتريات. تحقق من الاتصال؛ لا تُعرض قيمة صفرية عند فشل التحميل.',
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(storePurchaseReportProvider),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
        data: (all) {
          final period = all.where(_inPeriod).toList();
          final orders = period.where(isConfirmedPurchase).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final total = orders.fold(0.0, (sum, o) => sum + o.totalPrice);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('اليوم')),
                  ButtonSegment(value: 1, label: Text('هذا الشهر')),
                  ButtonSegment(value: 2, label: Text('الكل')),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6F7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: .20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إجمالي مشتريات المتجر المؤكدة',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _money(total),
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('${orders.length} طلب مؤكد · حسب تاريخ إنشاء الطلب'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'قيمة الطلبات المقبولة وقيد التحضير والتوصيل والمسلّمة، بما فيها التوصيل وبعد الخصم. تأكيد الطلب لا يثبت تسديد المبلغ.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGray,
                  height: 1.6,
                ),
              ),
              if (period.length != orders.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${period.length - orders.length} طلب غير مؤكد أو ملغي أو مرفوض، خارج الإجمالي.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              if (orders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 42,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 12),
                      Text('لا توجد مشتريات مؤكدة في هذه الفترة'),
                    ],
                  ),
                ),
              for (final order in orders)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      _money(order.totalPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    subtitle: Text(
                      '${DateFormat('yyyy/MM/dd – HH:mm').format(order.createdAt.toLocal())}\n${orderStatusLabel(order.status)}',
                      style: const TextStyle(height: 1.6),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.product.name,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('× ${item.quantity}'),
                              const SizedBox(width: 12),
                              Text(_money(item.product.price * item.quantity)),
                            ],
                          ),
                        ),
                      const Divider(),
                      if (order.discountAmount != null &&
                          order.discountAmount! > 0)
                        _row('الخصم', _money(order.discountAmount!)),
                      _row('التوصيل', _money(order.deliveryPrice)),
                      _row('إجمالي الطلب', _money(order.totalPrice)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(title)),
        Text(value),
      ],
    ),
  );
}
