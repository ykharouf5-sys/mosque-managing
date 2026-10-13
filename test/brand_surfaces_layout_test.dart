import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/utils/app_theme.dart';
import 'package:studentry/utils/brand_palette_preview.dart';

void main() {
  setUpAll(() async {
    final arabic = FontLoader('BrandReview');
    for (final weight in ['Regular', 'Bold']) {
      final bytes = File(
        'assets/fonts/NotoNaskhArabic-$weight.ttf',
      ).readAsBytesSync();
      arabic.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await arabic.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      Future.value(await rootBundle.load('fonts/MaterialIcons-Regular.otf')),
    );
    await icons.load();
  });
  for (final width in [320.0, 390.0, 720.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('brand surfaces fit $width px at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(fontFamily: 'BrandReview'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              ),
              home: const BrandPalettePreview(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(FilterChip).last);
        await tester.pumpAndSettle();
        expect(
          tester.widget<FilterChip>(find.byType(FilterChip).last).selected,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory('build/brand-review')
              ..createSync(recursive: true);
            File(
              '${directory.path}/android-${width.toInt()}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
