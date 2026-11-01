import 'package:flutter/material.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/utils/variable_colors.dart';

class StorePromoCard extends StatelessWidget {
  const StorePromoCard({
    super.key,
    required this.banner,
    required this.image,
    required this.onTap,
  });

  final PromoBanner banner;
  final Widget image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: const Color(0xFFE8F5F6),
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (banner.discountText.trim().isNotEmpty) ...[
                        Text(
                          banner.discountText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                      ],
                      Flexible(
                        child: Text(
                          banner.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF163E48),
                            fontSize: 18,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (banner.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            banner.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF42616A),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          banner.ctaText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(padding: const EdgeInsets.all(6), child: image),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
