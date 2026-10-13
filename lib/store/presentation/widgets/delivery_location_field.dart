import 'package:studentry/store/presentation/store_ui.dart';
import 'package:studentry/utils/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:studentry/utils/variable_colors.dart';

class DeliveryLocationField extends StatelessWidget {
  const DeliveryLocationField({
    super.key,
    this.controller,
    this.latitude,
    this.longitude,
    this.mapExpanded = false,
    required this.onChooseLocation,
    this.onClearLocation,
  });

  final TextEditingController? controller;
  final double? latitude;
  final double? longitude;
  final bool mapExpanded;
  final VoidCallback onChooseLocation;
  final VoidCallback? onClearLocation;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final hasPoint = latitude != null && longitude != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            textDirection: AppLocale.language == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: storeUi('تفاصيل العنوان'),
              hintText: storeUi('الشارع - المبنى - الطابق - قرب...'),
              prefixIcon: Icon(
                Icons.edit_location_outlined,
                color: AppColors.primary,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const Key('choose-delivery-location'),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  onTap: onChooseLocation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasPoint ? Icons.location_on : Icons.my_location,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            mapExpanded
                                ? 'إخفاء الخريطة'
                                : hasPoint
                                ? 'موقع التوصيل محدد — اضغط للتعديل'
                                : 'تحديد موقعي الحالي أو اختيار مكان على الخريطة',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_left,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (hasPoint && onClearLocation != null)
                IconButton(
                  tooltip: storeUi('إزالة الموقع المحدد'),
                  onPressed: onClearLocation,
                  icon: const Icon(Icons.close, size: 19),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

@Preview(name: 'Delivery address and map picker', size: Size(360, 175))
Widget deliveryLocationFieldPreview() => MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Directionality(
        textDirection: AppLocale.language == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: DeliveryLocationField(onChooseLocation: () {}),
      ),
    ),
  ),
);
