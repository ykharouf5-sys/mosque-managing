import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerTimesService {
  static final PrayerTimesService _instance = PrayerTimesService._internal();
  factory PrayerTimesService() => _instance;
  PrayerTimesService._internal();

  // Aladhan API base URL
  static const String _baseUrl = 'http://api.aladhan.com/v1';
  
  // Cache keys
  static const String _cacheKeyPrayerTimes = 'cached_prayer_times';
  static const String _cacheKeyLastUpdate = 'prayer_times_last_update';
  static const String _cacheKeyLocation = 'prayer_times_location';

  /// Get current location using GPS
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ Location services are disabled');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ Location permissions denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('⚠️ Location permissions permanently denied');
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      
      print('📍 Location obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  /// Fetch prayer times from Aladhan API
  Future<Map<String, dynamic>?> fetchPrayerTimes({
    required double latitude,
    required double longitude,
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr = '${targetDate.day}-${targetDate.month}-${targetDate.year}';
      
      final url = Uri.parse(
        '$_baseUrl/timings/$dateStr?latitude=$latitude&longitude=$longitude&method=4',
      );

      print('🌐 Fetching prayer times from API: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 200 && data['status'] == 'OK') {
          final timings = data['data']['timings'] as Map<String, dynamic>;
          
          // Extract the 5 main prayers
          final prayerTimes = {
            'Fajr': timings['Fajr'],
            'Dhuhr': timings['Dhuhr'],
            'Asr': timings['Asr'],
            'Maghrib': timings['Maghrib'],
            'Isha': timings['Isha'],
          };

          print('✅ Prayer times fetched successfully: $prayerTimes');
          
          // Cache the results
          await _cachePrayerTimes(prayerTimes, latitude, longitude);
          
          return prayerTimes;
        }
      }
      
      print('❌ Failed to fetch prayer times: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error fetching prayer times: $e');
      return null;
    }
  }

  /// Get today's prayer times (from cache or API)
  Future<Map<String, dynamic>?> getTodayPrayerTimes({
    double? latitude,
    double? longitude,
  }) async {
    // Try to get from cache first
    final cached = await _getCachedPrayerTimes();
    if (cached != null && _isCacheValid()) {
      print('✅ Using cached prayer times');
      return cached;
    }

    // If no coordinates provided, try to get current location
    if (latitude == null || longitude == null) {
      final position = await getCurrentLocation();
      if (position == null) {
        // Fallback to Damascus, Syria coordinates
        latitude = 33.5138;
        longitude = 36.2765;
        print('⚠️ Using default location (Damascus)');
      } else {
        latitude = position.latitude;
        longitude = position.longitude;
      }
    }

    // Fetch from API
    return await fetchPrayerTimes(
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Cache prayer times locally
  Future<void> _cachePrayerTimes(
    Map<String, dynamic> prayerTimes,
    double latitude,
    double longitude,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyPrayerTimes, json.encode(prayerTimes));
      await prefs.setString(_cacheKeyLastUpdate, DateTime.now().toIso8601String());
      await prefs.setString(_cacheKeyLocation, '$latitude,$longitude');
      print('💾 Prayer times cached');
    } catch (e) {
      print('❌ Error caching prayer times: $e');
    }
  }

  /// Get cached prayer times
  Future<Map<String, dynamic>?> _getCachedPrayerTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cacheKeyPrayerTimes);
      if (cachedStr != null) {
        return Map<String, dynamic>.from(json.decode(cachedStr));
      }
    } catch (e) {
      print('❌ Error reading cached prayer times: $e');
    }
    return null;
  }

  /// Check if cache is still valid (same day)
  bool _isCacheValid() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        final lastUpdateStr = prefs.getString(_cacheKeyLastUpdate);
        if (lastUpdateStr != null) {
          final lastUpdate = DateTime.parse(lastUpdateStr);
          final now = DateTime.now();
          
          // Cache is valid if it's the same day
          return lastUpdate.year == now.year &&
                 lastUpdate.month == now.month &&
                 lastUpdate.day == now.day;
        }
      });
    } catch (e) {
      print('❌ Error checking cache validity: $e');
    }
    return false;
  }

  /// Convert prayer time string (HH:mm) to DateTime for today
  DateTime _prayerTimeToDateTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1].split(' ')[0]); // Remove timezone if present
    
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  /// Get prayer times as DateTime objects for scheduling
  Future<Map<String, DateTime>?> getTodayPrayerTimesAsDateTime() async {
    final prayerTimes = await getTodayPrayerTimes();
    if (prayerTimes == null) return null;

    try {
      return {
        'Fajr': _prayerTimeToDateTime(prayerTimes['Fajr']),
        'Dhuhr': _prayerTimeToDateTime(prayerTimes['Dhuhr']),
        'Asr': _prayerTimeToDateTime(prayerTimes['Asr']),
        'Maghrib': _prayerTimeToDateTime(prayerTimes['Maghrib']),
        'Isha': _prayerTimeToDateTime(prayerTimes['Isha']),
      };
    } catch (e) {
      print('❌ Error converting prayer times to DateTime: $e');
      return null;
    }
  }

  /// Schedule daily update at midnight
  Future<void> scheduleDailyUpdate() async {
    // This will be called from a background task or alarm
    // For now, it's a placeholder for future implementation
    print('⏰ Scheduling daily prayer times update');
    
    // Calculate time until next midnight
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);
    
    print('⏰ Next update in ${duration.inHours} hours');
    
    // TODO: Implement actual background task scheduling
    // This could use WorkManager (Android) or Background Fetch (iOS)
  }

  /// Clear cached prayer times
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyPrayerTimes);
      await prefs.remove(_cacheKeyLastUpdate);
      await prefs.remove(_cacheKeyLocation);
      print('🗑️ Prayer times cache cleared');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }
}
