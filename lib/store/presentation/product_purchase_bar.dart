import 'package:studentry/store/presentation/store_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:studentry/utils/variable_colors.dart';

class ProductPurchaseBar extends StatelessWidget {
  const ProductPurchaseBar({
    super.key,
    required this.quantity,
    required this.inStock,
    required this.onDecrease,
    required this.onIncrease,
    required this.onAdd,
  });

  final int quantity;
  final bool inStock;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.featureBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: storeUi('تقليل الكمية'),
                    onPressed: onDecrease,
                    icon: Icon(Icons.remove, size: 18),
                  ),
                  Text(
                    '$quantity',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    tooltip: storeUi('زيادة الكمية'),
                    onPressed: onIncrease,
                    icon: Icon(Icons.add, size: 18),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: inStock ? onAdd : null,
                  icon: Icon(inStock ? Icons.add_shopping_cart : Icons.block),
                  label: Text(storeUi(inStock ? 'أضف للسلة' : 'غير متوفر')),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@Preview(name: 'شريط شراء المنتج', group: 'المتجر', size: Size(393, 100))
Widget productPurchaseBarPreview() => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      bottomNavigationBar: ProductPurchaseBar(
        quantity: 1,
        inStock: true,
        onDecrease: () {},
        onIncrease: () {},
        onAdd: () {},
      ),
    ),
  ),
);
