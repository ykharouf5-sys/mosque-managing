import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:studentry/shared/widgets/pagination_controls.dart';

@Preview(name: 'أزرار الصفحات', group: 'مشترك', size: Size(393, 100))
Widget paginationControlsPreview() {
  return const MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: PaginationControls(
            currentPage: 2,
            lastPage: 8,
            loading: false,
          ),
        ),
      ),
    ),
  );
}
