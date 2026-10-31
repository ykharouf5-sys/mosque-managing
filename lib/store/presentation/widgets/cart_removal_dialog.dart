import 'package:flutter/material.dart';
import 'package:studentry/utils/app_locale.dart';

Future<bool> showCartRemovalConfirmation(
  BuildContext context,
  String productName,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppLocale.text('إزالة المنتج من السلة', 'Remove product from cart'),
        ),
        content: Text(
          AppLocale.text(
            'هل تريد إزالة «$productName» من السلة؟',
            'Remove “$productName” from your cart?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocale.text('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocale.text('تأكيد', 'Confirm')),
          ),
        ],
      ),
    ) ??
    false;
