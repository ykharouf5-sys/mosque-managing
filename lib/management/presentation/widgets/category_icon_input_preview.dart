import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:studentry/management/presentation/widgets/category_icon_input.dart';

@Preview(name: 'أيقونة تصنيف اختيارية', group: 'المبيعات', size: Size(393, 280))
Widget categoryIconInputPreview() {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: CategoryIconInput(
            controller: TextEditingController(),
            onPick: () async => null,
          ),
        ),
      ),
    ),
  );
}
