import 'package:studentry/store/presentation/store_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:studentry/utils/variable_colors.dart';

class DeliveryPoint {
  DeliveryPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);

  String get mapUrl =>
      'https://maps.google.com/?q=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
}

/// Compact, inline map for checkout. Manual selection works without GPS access.
class DeliveryLocationMap extends StatefulWidget {
  const DeliveryLocationMap({
    super.key,
    this.initialPoint,
    required this.onConfirm,
  });

  final DeliveryPoint? initialPoint;
  final ValueChanged<DeliveryPoint> onConfirm;

  @override
  State<DeliveryLocationMap> createState() => _DeliveryLocationMapState();
}

class _DeliveryLocationMapState extends State<DeliveryLocationMap> {
  static const _fallback = LatLng(33.5138, 36.2765);
  final _controller = MapController();
  DeliveryPoint? _selected;
  bool _locating = false;
  String? _hint;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPoint;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialPoint == null) _useCurrentLocation();
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _hint = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() => _hint = 'شغّل الموقع من الجهاز أو اختر نقطة يدوياً.');
        final open = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(storeUi('تشغيل الموقع')),
            content: Text(
              storeUi(
                'لتحديد موقعك الحالي، شغّل خدمة الموقع. يمكنك أيضاً الضغط على الخريطة لاختيار مكان آخر.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(storeUi('اختيار يدوي')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(storeUi('فتح الإعدادات')),
              ),
            ],
          ),
        );
        if (open == true) await Geolocator.openLocationSettings();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(
            () => _hint =
                'إذن الموقع مرفوض من إعدادات التطبيق. اختر نقطة يدوياً.',
          );
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _hint = 'لم يُسمح بالموقع. اختر نقطة يدوياً.');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final point = DeliveryPoint(position.latitude, position.longitude);
      setState(() {
        _selected = point;
        _hint = null;
      });
      _controller.move(point.latLng, 16);
    } catch (_) {
      if (mounted) {
        setState(() => _hint = 'تعذر تحديد موقعك. اختر نقطة يدوياً.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 230,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _selected?.latLng ?? _fallback,
                    initialZoom: _selected == null ? 11 : 16,
                    onTap: (_, point) => setState(() {
                      _selected = DeliveryPoint(
                        point.latitude,
                        point.longitude,
                      );
                      _hint = null;
                    }),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'io.studentry.app',
                    ),
                    if (_selected != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selected!.latLng,
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.location_pin,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: FloatingActionButton.small(
                    heroTag: 'inline-delivery-location',
                    onPressed: _locating ? null : _useCurrentLocation,
                    tooltip: storeUi('موقعي الحالي'),
                    child: _locating
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.my_location),
                  ),
                ),
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        '© OpenStreetMap contributors',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                Text(
                  _hint ??
                      'اضغط على الخريطة لتثبيت النقطة أو اختر موقعي الحالي.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selected == null
                        ? null
                        : () => widget.onConfirm(_selected!),
                    icon: Icon(Icons.check),
                    label: Text(storeUi('تأكيد المكان')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
