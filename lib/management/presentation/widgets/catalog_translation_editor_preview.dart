import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'catalog_translation_editor.dart';

@Preview(
  name: 'Catalog translations',
  group: 'Sales manager',
  size: Size(380, 420),
)
Widget catalogTranslationEditorPreview() => MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: CatalogTranslationEditor(
        arabic: {
          'name': TextEditingController(text: 'فرشاة أسنان'),
          'description': TextEditingController(),
        },
        english: {
          'name': TextEditingController(text: 'Toothbrush'),
          'description': TextEditingController(),
        },
        labels: const {
          'name': ('اسم المنتج', 'Product name'),
          'description': ('الوصف', 'Description'),
        },
      ),
    ),
  ),
);
