import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'refresh_visibility.dart';
import '../data/clinical_sync_policy.dart';

@Preview(
  name: 'Clinical events and 20s cooldown (no network)',
  size: Size(360, 360),
)
Widget refreshVisibilityPreview() => const _VisibilityProbe();

class _VisibilityProbe extends StatefulWidget {
  const _VisibilityProbe();
  @override
  State<_VisibilityProbe> createState() => _VisibilityProbeState();
}

class _VisibilityProbeState extends State<_VisibilityProbe> {
  bool _selected = true;
  bool _refreshEnabled = false;
  DateTime _clock = DateTime.utc(2026, 10, 8);
  late final _policy = ClinicalSyncPolicy(now: () => _clock);
  int _pulls = 0;

  void _pull({bool manual = false}) {
    if (_policy.allowPull('preview-clinical-account', manual: manual)) {
      _pulls++;
      _policy.succeeded('preview-clinical-account');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorObservers: [refreshRouteObserver],
    home: RefreshVisibility(
      active: _selected,
      onChanged: (value) => setState(() {
        _refreshEnabled = value;
        if (value) _pull();
      }),
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_refreshEnabled ? 'التحديث مفعّل' : 'التحديث متوقف'),
              Text('البيانات المحلية ظاهرة — طلبات السحب: $_pulls'),
              Switch(
                value: _selected,
                onChanged: (value) => setState(() => _selected = value),
              ),
              TextButton(
                onPressed: _refreshEnabled
                    ? () => setState(() => _pull(manual: true))
                    : null,
                child: const Text('تحديث يدوي'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _clock = _clock.add(const Duration(seconds: 20));
                }),
                child: const Text('تقدّم 20 ثانية بدون إرسال طلب'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
