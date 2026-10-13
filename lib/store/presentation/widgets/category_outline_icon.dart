import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:studentry/utils/variable_colors.dart';

/// Small, consistent category symbols; product photography stays on products.
class CategoryOutlineIcon extends StatelessWidget {
  const CategoryOutlineIcon({
    super.key,
    required this.label,
    this.iconUrl = '',
    this.size = 28,
  });

  final String label;
  final String iconUrl;
  final double size;

  String get _shape {
    final name = label.toLowerCase();
    if (name.contains('فحص') || name.contains('exam')) {
      return '<circle cx="9" cy="7" r="4.5"/><path d="m12.2 10.2 6.3 9a1.5 1.5 0 0 1-2.4 1.7l-6.2-9"/>';
    }
    if (name.contains('ترميم') || name.contains('restor')) {
      return '<path d="m7 8 9 9m-7-11 9 9M6 9l3-3m6 12 3-3M5 5l2 2m10 10 3 3M4 14l6 6m-7 1 3-3M14 3l7 7m-3-4 3-3"/>';
    }
    if (name.contains('تعقيم') ||
        name.contains('حماية') ||
        name.contains('protect')) {
      return '<path d="M12 3 4 6v6c0 4 3 7 8 9 5-2 8-5 8-9V6zM8 12l3 3 5-6"/>';
    }
    if (name.contains('طالب') ||
        name.contains('طلاب') ||
        name.contains('student')) {
      return '<rect x="5" y="3" width="15" height="18" rx="2"/><path d="M8 3v18M3 7h4m-4 5h4m-4 5h4m5-9h5m-5 4h5m-5 4h3"/>';
    }
    if (name.contains('فم') ||
        name.contains('فرش') ||
        name.contains('oral') ||
        name.contains('brush')) {
      return '<path d="M8 10V4m3 6V3m3 7V3m3 7V4M7 10h11v2a3 3 0 0 1-3 3h-1v5a2 2 0 0 1-4 0v-5a3 3 0 0 1-3-3z"/>';
    }
    return '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>';
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final uri = Uri.tryParse(iconUrl);
    if (uri != null &&
        ['https', 'http'].contains(uri.scheme) &&
        uri.path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        iconUrl,
        width: size,
        height: size,
        semanticsLabel: label,
        colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
        placeholderBuilder: (_) => _builtIn(),
        errorBuilder: (_, _, _) => _builtIn(),
      );
    }
    return _builtIn();
  }

  Widget _builtIn() => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="#000" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">$_shape</g></svg>',
    width: size,
    height: size,
    semanticsLabel: label,
    colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
  );
}
