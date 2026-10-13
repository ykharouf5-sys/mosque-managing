import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/store/presentation/store_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class CodPaymentOption extends StatelessWidget {
  const CodPaymentOption({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.money_outlined, color: colors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              storeUi('دفع عند الاستلام'),
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.check_circle, color: colors.primary),
        ],
      ),
    );
  }
}

@Preview(name: 'الدفع عند الاستلام', size: Size(360, 100))
Widget codPaymentOptionPreview() => MaterialApp(
  home: Scaffold(
    body: Directionality(
      textDirection: AppLocale.language == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Padding(padding: EdgeInsets.all(16), child: CodPaymentOption()),
    ),
  ),
);
