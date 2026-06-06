import 'package:flutter/material.dart';
import 'package:yaman/Screen/prayer_stats_screen.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/services/prayer_service.dart';
import 'package:yaman/widget/variable.dart';
import 'dart:math' as math;

import '../services/storage_service.dart';

class PraysScreen extends StatefulWidget {
  const PraysScreen({super.key, required this.student, this.onUpdate});

  final Student student;
  // Callback to notify the parent widget (StudentInterface) of changes.
  final Function(Student)? onUpdate;

  @override
  State<PraysScreen> createState() => _PraysScreenState();
}

class _PraysScreenState extends State<PraysScreen> {
  final PrayerService _prayerService = PrayerService();
  late Student _student;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
  }

  StorageService get _storage => StorageService();

  final List<String> days = const [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  final List<String> prayers = const [
    'الفجر',
    'الظهر',
    'العصر',
    'المغرب',
    'العشاء',
  ];

  // Get current week dates (Sunday to Saturday)
  DateTime get startOfWeek {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday % 7)); // Sunday
  }

  DateTime get endOfWeek =>
      startOfWeek.add(const Duration(days: 6)); // Saturday

  // Filter prayers for current week
  List<List<String>> get currentWeekPrayers {
    final prayerMap = _student.getPrayerMap();
    final List<List<String>> weekPrayers = [];

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];

      if (prayerMap.containsKey(dateStr) && prayerMap[dateStr]!.length == 5) {
        weekPrayers.add(prayerMap[dateStr]!); // Use the map directly
      } else {
        weekPrayers.add(
          List.filled(5, 'غير مكتمل'),
        ); // Default for dates not found
      }
    }
    return weekPrayers;
  }

  void _showPrayerStatusSelector(
    BuildContext context,
    int dayIndex,
    int prayerIndex,
  ) {
    final date = startOfWeek.add(Duration(days: dayIndex));
    final dateStr = date.toIso8601String().split('T')[0];
    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0];

    // Prevent editing future days
    if (date.isAfter(today) && dateStr != todayStr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن تسجيل صلوات لأيام مستقبلية'),
          backgroundColor: Color.fromARGB(255, 214, 182, 0),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backcolor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border.all(color: regsin, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${prayers[prayerIndex]} - ${days[dayIndex]}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: ['جماعة', 'أداء', 'قضاء', 'فائتة'].map((status) {
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateSinglePrayer(
                      dayIndex,
                      prayerIndex,
                      status,
                      dateStr,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }

  Future<void> _updateSinglePrayer(
    int dayIndex,
    int prayerIndex,
    String status,
    String dateStr,
  ) async {
    // --- Start of optimistic update ---
    // 1. Get the current prayer map and update it.
    final prayerMap = _student.getPrayerMap();
    prayerMap[dateStr] ??= List.filled(5, 'غير مكتمل');
    prayerMap[dateStr]![prayerIndex] = status;

    // 2. Create the optimistic student object from the updated map.
    final optimisticStudent = _student.copyWithPrayerMap(prayerMap);

    // 5. Update UI immediately for a snappy user experience.
    if (mounted) {
      setState(() {
        _student = optimisticStudent;
      });
    }

    // --- End of optimistic update ---

    // 6. Show instant feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التغيير'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }

    // 7. Call the service to get the updated student and sync to the cloud.
    try {
      final finalUpdatedStudent = await _prayerService.updateAndSyncPrayer(
        currentStudent: _student, // Pass the original student state
        dateStr: dateStr,
        prayerIndex: prayerIndex,
        status: status,
      );

      // 8. Persist the updated student locally and update the UI state.
      await _storage.updateStudent(finalUpdatedStudent);
      if (mounted) {
        setState(() => _student = finalUpdatedStudent);
      }
      // Notify the parent widget (StudentInterface)
      widget.onUpdate?.call(finalUpdatedStudent);
    } catch (e) {
      // Handle background errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل مزامنة البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // This function is kept for the "refresh on return" from stats screen.
  Future<void> _refreshStudentFromCloud() async {
    try {
      final students = await _storage.loadStudents();
      final updatedStudent = students.firstWhere(
        (s) => s.id == _student.id,
        orElse: () => _student,
      );
      if (mounted) {
        setState(() => _student = updatedStudent);
      }
    } catch (e) {
      // Ignore errors, the current state is fine.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Scaffold(
        backgroundColor: backcolor,
        appBar: AppBar(
          backgroundColor: backcolor,
          elevation: 0,
          title: const Text(
            'سجل الصلوات الأسبوعي',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart, color: Colors.white),
              tooltip: 'عرض الإحصائيات',
              onPressed: () async {
                // Navigate to stats and wait for it to pop
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrayerStatsScreen(student: _student),
                  ),
                );
                // When returning, refresh student data as it might have been updated
                // by the teacher in the background.
                await _refreshStudentFromCloud();
              },
            ),
          ],
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            final statuses = currentWeekPrayers[index];

            return Card(
              color: Colors.white.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 15),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        '🗓 $day',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 520;
                        return isWide
                            ? Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: prayers.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final prayer = entry.value;
                                  final status = statuses[i];
                                  return GestureDetector(
                                    onTap: () => _showPrayerStatusSelector(
                                      context,
                                      index,
                                      i,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _statusBox(status, true),
                                        const SizedBox(height: 6),
                                        Text(
                                          prayer,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              )
                            : Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 8,
                                children: prayers.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final prayer = entry.value;
                                  final status = statuses[i];
                                  return GestureDetector(
                                    onTap: () => _showPrayerStatusSelector(
                                      context,
                                      index,
                                      i,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _statusBox(status, true),
                                        const SizedBox(height: 4),
                                        Text(
                                          prayer,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statusBox(String status, [bool isInteractive = false]) {
    Color color;
    IconData icon;
    switch (status) {
      case 'جماعة':
        color = Colors.greenAccent;
        icon = Icons.groups;
        break;
      case 'أداء':
        color = Colors.lightBlueAccent;
        icon = Icons.check_circle;
        break;
      case 'قضاء':
        color = Colors.orangeAccent;
        icon = Icons.timelapse;
        break;
      case 'فائتة':
        color = Colors.purpleAccent;
        icon = Icons.warning_amber_rounded;
        break;
      case 'غياب':
        color = Colors.redAccent;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.add_circle_outline; // Changed icon to indicate action
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final boxSize = math.min(screenWidth * 0.11, 56.0);
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: isInteractive ? 2 : 1),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: isInteractive ? 8 : 4,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: math.min(28, boxSize * 0.55)),
    );
  }
}
