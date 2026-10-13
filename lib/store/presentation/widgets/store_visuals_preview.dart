import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:studentry/store/data/store_models.dart';
import 'category_outline_icon.dart';
import 'store_promo_card.dart';

void storePreviewTap() {}

@Preview(
  name: 'Compact Arabic store banner',
  group: 'Store',
  size: Size(360, 190),
)
Widget storeBannerPreview() => const Directionality(
  textDirection: TextDirection.rtl,
  child: StorePromoCard(
    banner: PromoBanner(
      id: 'preview',
      title: 'جهّز أدوات التدريب',
      subtitle: 'أدوات فحص لطلاب طب الأسنان',
      discountText: 'مستلزمات الدراسة',
      imageUrl: '',
      ctaText: 'استكشف المنتجات',
      actionRoute: '/category-products',
    ),
    image: ColoredBox(
      color: Color(0xFFB7E0E3),
      child: Center(child: CategoryOutlineIcon(label: 'أدوات الفحص', size: 64)),
    ),
    onTap: storePreviewTap,
  ),
);

@Preview(name: 'Outline category symbols', group: 'Store', size: Size(360, 64))
Widget storeCategoryIconsPreview() => const Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    CategoryOutlineIcon(label: 'أدوات الفحص'),
    CategoryOutlineIcon(label: 'مواد الترميم'),
    CategoryOutlineIcon(label: 'التعقيم والحماية'),
    CategoryOutlineIcon(label: 'العناية الفموية'),
    CategoryOutlineIcon(label: 'مستلزمات الطلاب'),
  ],
);
