import 'dart:io';
import 'package:flutter/material.dart';
import 'package:studentry/shared/widgets/app_cached_network_image.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:studentry/utils/app_locale.dart';
import 'package:intl/intl.dart';

class StoreProductCard extends StatelessWidget {
  const StoreProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.width,
  });
  final Product product;
  final VoidCallback onTap;
  final double? width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.dividerLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: const Color(0xFFF1F8F9),
                padding: const EdgeInsets.all(8),
                child: _image(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${NumberFormat('#,##0.##').format(product.price)} ${AppLocale.text('ل.س', 'SYP')}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (product.rating > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: Color(0xFFE8AD23),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              product.rating.toStringAsFixed(1),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _image() {
    Widget fallback() => const Center(
      child: Icon(
        Icons.inventory_2_outlined,
        color: AppColors.primary,
        size: 32,
      ),
    );
    final path = product.listImageUrl;
    if (path.isEmpty) return fallback();
    if (path.startsWith('/') || path.contains(':\\')) {
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (_, error, stack) => fallback(),
      );
    }
    return AppCachedNetworkImage(
      url: path,
      fit: BoxFit.contain,
      errorBuilder: fallback,
    );
  }
}
