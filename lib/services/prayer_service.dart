import 'package:yaman/models/student.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/services/sync_queue_service.dart';

class PrayerService {
  final SupabaseService _supabase = SupabaseService();

  /// حفظ الصلوات للطالب مع التاريخ by delegating to SupabaseService
  Future<bool> savePrayerRecord({
    required String studentId,
    required String date,
    required List<String> prayers,
  }) async {
    try {
      await _supabase.savePrayerRecord(
        studentId: studentId,
        date: date,
        prayers: prayers,
      );
      print('✅ Prayer record saved via PrayerService for $studentId on $date');
      return true;
    } catch (e) {
      print('❌ Error saving prayer record via PrayerService: $e');
      return false;
    }
  }

  /// **New Centralized Logic**: Updates prayer, saves locally, and syncs to the cloud.
  /// This ensures a consistent and reliable data flow.
  Future<Student> updateAndSyncPrayer({
    required Student currentStudent,
    required String dateStr,
    required int prayerIndex,
    required String status,
  }) async {
    // This function now returns the updated student object.
    // This function is now fire-and-forget from the UI's perspective.
    // It tries to save to the cloud and queues the operation on failure.

    // 1. Get the current prayer map and update it.
    final prayerMap = currentStudent.getPrayerMap();
    prayerMap[dateStr] ??= List.filled(5, 'غير مكتمل');
    prayerMap[dateStr]![prayerIndex] = status;

    final studentId = currentStudent.id;
    final prayersForDate = prayerMap[dateStr]!;

    // Convert map back to two lists for Supabase.
    final updatedDates = prayerMap.keys.toList();
    final updatedPrayers = prayerMap.values.toList();
    try {
      final success = await savePrayerRecord(
        studentId: studentId,
        date: dateStr,
        prayers: prayersForDate,
      );

      if (!success) {
        print('⚠️ Cloud prayer update failed, queueing for later.');
        await SyncQueueService().addOperation('save_prayer_record', {
          'student_id': studentId,
          'date': dateStr,
          'prayers': prayersForDate,
        });
      } else {
        // Also update the main student record in Supabase for consistency
        await _supabase.updateStudentPrayers(
          studentId: studentId,
          prayers: updatedPrayers,
          prayerDates: updatedDates,
        );
      }
    } catch (e) {
      print('❌ Cloud prayer update threw an exception, queueing for later: $e');
      await SyncQueueService().addOperation('save_prayer_record', {
        'student_id': studentId,
        'date': dateStr,
        'prayers': prayersForDate,
      });
    }

    // Return the new student object so the UI can use it
    return currentStudent.copyWithPrayerMap(prayerMap);
  }

  /// جلب سجلات الصلوات للطالب خلال فترة معينة
  Future<List<Map<String, dynamic>>> getPrayerRecords({
    required String studentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // This will require a new method in SupabaseService
      return await _supabase.getPrayerRecords(
        studentId: studentId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      print('❌ Error fetching prayer records: $e');
      return [];
    }
  }

  /// جلب إحصائيات الصلوات للطالب خلال فترة
  Future<Map<String, dynamic>> getPrayerStatistics({
    required String studentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final records = await getPrayerRecords(
        studentId: studentId,
        startDate: startDate,
        endDate: endDate,
      );

      int totalDays = 0;
      int jamaahCount = 0;
      int performanceCount = 0;
      int makeupCount = 0;
      int faitaCount = 0;
      int absentCount = 0;
      Map<String, int> dailyStats = {};

      for (final record in records) {
        totalDays++;
        final prayers = List<String>.from(record['prayers'] ?? []);

        for (final prayer in prayers) {
          if (prayer == 'جماعة') jamaahCount++;
          if (prayer == 'أداء') performanceCount++;
          if (prayer == 'قضاء') makeupCount++;
          if (prayer == 'فائتة') faitaCount++;
          if (prayer == 'غياب') absentCount++;
        }

        final date = record['date'] as String;
        dailyStats[date] = prayers.where((p) => p != 'غياب').length;
      }

      final stats = {
        'totalDays': totalDays,
        'jamaah': jamaahCount,
        'performance': performanceCount,
        'makeup': makeupCount,
        'faita': faitaCount,
        'absent': absentCount,
        'averagePerDay': totalDays > 0
            ? (jamaahCount + performanceCount + makeupCount + faitaCount) /
                  totalDays
            : 0,
        'dailyStats': dailyStats,
      };

      print('📊 Prayer statistics: $stats');
      return stats;
    } catch (e) {
      print('❌ Error calculating statistics: $e');
      return {};
    }
  }

  /// التحقق من الصلوات المفقودة أو غير المكتملة
  Future<List<Map<String, dynamic>>> getIncompleteRecords({
    required String studentId,
    int daysBack = 7,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: daysBack));
      final records = await getPrayerRecords(
        studentId: studentId,
        startDate: startDate,
        endDate: DateTime.now(),
      );

      final incomplete = records.where((record) {
        final prayers = List<String>.from(record['prayers'] ?? []);
        // سجل غير مكتمل إذا كان فيه "غياب" أو فارغ
        return prayers.isEmpty || prayers.contains('غياب');
      }).toList();

      print('⚠️ Found ${incomplete.length} incomplete prayer records');
      return incomplete;
    } catch (e) {
      print('❌ Error checking incomplete records: $e');
      return [];
    }
  }
}
