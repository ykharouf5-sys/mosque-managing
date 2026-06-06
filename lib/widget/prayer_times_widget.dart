import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhan/adhan.dart';
import 'package:yaman/widget/variable.dart';

import 'package:geolocator/geolocator.dart';

class PrayerTimesWidget extends StatefulWidget {
  const PrayerTimesWidget({super.key});

  @override
  State<PrayerTimesWidget> createState() => _PrayerTimesWidgetState();
}

class _PrayerTimesWidgetState extends State<PrayerTimesWidget> {
  late Timer _timer;
  late DateTime _now;
  PrayerTimes? _prayerTimes;
  bool _isLocationLoaded = false;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _initLocationAndTimes();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
          if (_now.hour == 0 && _now.minute == 0 && _now.second == 0) {
            _initLocationAndTimes();
          }
        });
      }
    });
  }

  Future<void> _initLocationAndTimes() async {
    try {
      Position position = await _determinePosition();
      _updatePrayerTimes(position.latitude, position.longitude);
    } catch (e) {
      // Fallback to Mecca if location fails
      _updatePrayerTimes(21.4225, 39.8262);
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Location permissions are denied');
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    } 

    return await Geolocator.getCurrentPosition();
  }

  void _updatePrayerTimes(double lat, double lng) {
    final coordinates = Coordinates(lat, lng);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;

    setState(() {
      _prayerTimes = PrayerTimes.today(coordinates, params);
      _isLocationLoaded = true;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    return DateFormat('hh:mm:ss a').format(time);
  }

  String _formatPrayerTime(DateTime? time) {
    if (time == null) return '--:--';
    return DateFormat('hh:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocationLoaded || _prayerTimes == null) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 10),
            Text('جاري تحديد الموقع...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Real-time Clock
          Text(
            _formatTime(_now),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(_now),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 20),
          // Prayer Times Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPrayerItem('الفجر', _prayerTimes!.fajr),
              _buildPrayerItem('الظهر', _prayerTimes!.dhuhr),
              _buildPrayerItem('العصر', _prayerTimes!.asr),
              _buildPrayerItem('المغرب', _prayerTimes!.maghrib),
              _buildPrayerItem('العشاء', _prayerTimes!.isha),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerItem(String name, DateTime time) {
    final bool isNext = _prayerTimes?.nextPrayer() == _getPrayerByName(name);
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            color: isNext ? regsin : Colors.white70,
            fontSize: 12,
            fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isNext ? regsin.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isNext ? Border.all(color: regsin) : null,
          ),
          child: Text(
            _formatPrayerTime(time),
            style: TextStyle(
              color: isNext ? regsin : Colors.white,
              fontSize: 14,
              fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Prayer _getPrayerByName(String name) {
    switch (name) {
      case 'الفجر': return Prayer.fajr;
      case 'الظهر': return Prayer.dhuhr;
      case 'العصر': return Prayer.asr;
      case 'المغرب': return Prayer.maghrib;
      case 'العشاء': return Prayer.isha;
      default: return Prayer.none;
    }
  }
}
