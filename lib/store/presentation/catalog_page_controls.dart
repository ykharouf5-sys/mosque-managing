import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/store/presentation/store_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

class CatalogPageControls extends StatelessWidget {
  const CatalogPageControls({
    super.key,
    required this.page,
    required this.lastPage,
    required this.loading,
    required this.onPage,
  });
  final int page, lastPage;
  final bool loading;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.all(8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton(
            onPressed: loading || page <= 1 ? null : () => onPage(page - 1),
            child: Text(storeUi('السابق')),
          ),
          Text('$page / $lastPage'),
          OutlinedButton(
            onPressed: loading || page >= lastPage
                ? null
                : () => onPage(page + 1),
            child: Text(storeUi('التالي')),
          ),
        ],
      ),
    ),
  );
}

@Preview(name: 'Catalog pagination RTL', size: Size(320, 120))
Widget catalogPaginationPreview() => MaterialApp(
  home: Directionality(
    textDirection: AppLocale.language == 'ar'
        ? TextDirection.rtl
        : TextDirection.ltr,
    child: Scaffold(
      body: CatalogPageControls(
        page: 2,
        lastPage: 5,
        loading: false,
        onPage: (_) {},
      ),
    ),
  ),
);
