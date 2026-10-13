import 'package:flutter/material.dart';

/// Controllers live in the parent dialog, so switching tabs cannot discard drafts.
class CatalogTranslationEditor extends StatefulWidget {
  const CatalogTranslationEditor({
    super.key,
    required this.arabic,
    required this.english,
    required this.labels,
  });
  final Map<String, TextEditingController> arabic;
  final Map<String, TextEditingController> english;
  final Map<String, (String, String)> labels;

  @override
  State<CatalogTranslationEditor> createState() =>
      _CatalogTranslationEditorState();
}

class _CatalogTranslationEditorState extends State<CatalogTranslationEditor> {
  String locale = 'ar';
  @override
  Widget build(BuildContext context) {
    final controllers = locale == 'ar' ? widget.arabic : widget.english;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ar', label: Text('العربية')),
            ButtonSegment(value: 'en', label: Text('English')),
          ],
          selected: {locale},
          onSelectionChanged: (selection) =>
              setState(() => locale = selection.single),
        ),
        const SizedBox(height: 12),
        Directionality(
          textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in widget.labels.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    key: ValueKey('$locale:${entry.key}'),
                    controller: controllers[entry.key],
                    maxLines: entry.key == 'description' ? 3 : 1,
                    decoration: InputDecoration(
                      labelText: locale == 'ar'
                          ? entry.value.$1
                          : entry.value.$2,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Text(
          'الإنجليزية اختيارية؛ النص الناقص يظهر بالعربية. / Missing English uses Arabic.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

Map<String, dynamic> editorTranslations(
  Map<String, TextEditingController> ar,
  Map<String, TextEditingController> en,
) => {
  'ar': {for (final entry in ar.entries) entry.key: entry.value.text.trim()},
  'en': en.values.every((controller) => controller.text.trim().isEmpty)
      ? null
      : {for (final entry in en.entries) entry.key: entry.value.text.trim()},
};
