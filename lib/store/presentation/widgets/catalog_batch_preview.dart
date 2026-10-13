import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:studentry/store/data/catalog_refresh_policy.dart';

@Preview(name: 'Two-hour catalog cohorts', size: Size(360, 240))
Widget catalogBatchPreview() => const _BatchProbe();

class _BatchProbe extends StatefulWidget {
  const _BatchProbe();
  @override
  State<_BatchProbe> createState() => _BatchProbeState();
}

class _BatchProbeState extends State<_BatchProbe> {
  int _device = 1;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.utc(2026, 10, 4, 12);
    final identity = 'preview-device-$_device';
    final minutes = CatalogRefreshPolicy.nextSlot(
      now,
      identity,
    ).difference(now).inMinutes;
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الجهاز $_device — الدفعة ${CatalogRefreshPolicy.batch(identity) + 1}/120',
              ),
              Text('التحديث القادم بعد $minutes دقيقة'),
              Slider(
                value: _device.toDouble(),
                min: 1,
                max: 170,
                divisions: 169,
                onChanged: (value) => setState(() => _device = value.round()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
