import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'app_theme.dart';
import 'variable_colors.dart';

@Preview(
  name: 'Studentry surfaces — phone',
  group: 'Brand',
  size: Size(390, 760),
)
@Preview(
  name: 'Studentry surfaces — tablet',
  group: 'Brand',
  size: Size(720, 760),
)
Widget brandPalettePreview() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light(fontFamily: 'Arial'),
  home: const Directionality(
    textDirection: TextDirection.rtl,
    child: BrandPalettePreview(),
  ),
);

/// Pure Material preview: no authentication, network, or native dependencies.
class BrandPalettePreview extends StatefulWidget {
  const BrandPalettePreview({super.key});

  @override
  State<BrandPalettePreview> createState() => _BrandPalettePreviewState();
}

class _BrandPalettePreviewState extends State<BrandPalettePreview> {
  bool study = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Studentry')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'معك من أول محاضرة لآخر موعد',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          children: [
            FilterChip(
              label: const Text('المواعيد'),
              selected: !study,
              onSelected: (_) => setState(() => study = false),
            ),
            FilterChip(
              label: const Text('الدراسة'),
              selected: study,
              onSelected: (_) => setState(() => study = true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  study
                      ? Icons.menu_book_outlined
                      : Icons.calendar_month_outlined,
                  color: AppColors.primaryDark,
                  size: 30,
                ),
                const SizedBox(height: 12),
                Text(
                  study ? 'المحاضرات وملفات PDF' : 'المواعيد وملفات المرضى',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تفاصيل واضحة، وكاردز بيضاء على خلفية هادئة.',
                  style: TextStyle(color: AppColors.textGray, height: 1.7),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حساب واحد على الويب والتطبيق',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'الملفات والمواعيد والدراسة في مساحة واحدة.',
                  style: TextStyle(color: AppColors.textGray, height: 1.7),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => setState(() => study = !study),
              icon: const Icon(Icons.check),
              label: const Text('استكشف'),
            ),
            OutlinedButton(
              onPressed: () => setState(() => study = !study),
              child: const Text('متابعة'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const TextField(
          decoration: InputDecoration(
            labelText: 'البحث',
            hintText: 'اسم المريض أو المادة',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ],
    ),
  );
}
