import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:yaman/models/student.dart';
import 'package:yaman/services/prayer_service.dart';
import 'package:yaman/widget/variable.dart';

class PrayerStatsScreen extends StatefulWidget {
  const PrayerStatsScreen({super.key, required this.student});

  final Student student;

  @override
  State<PrayerStatsScreen> createState() => _PrayerStatsScreenState();
}

class _PrayerStatsScreenState extends State<PrayerStatsScreen> {
  final PrayerService _prayerService = PrayerService();

  late Future<Map<String, dynamic>> _statsFuture;
  int selectedDaysBack = 7; // Default: last 7 days

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: selectedDaysBack));

    setState(() {
      _statsFuture = _calculateHybridStats(startDate, endDate);
    });
  }

  Future<Map<String, dynamic>> _calculateHybridStats(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // 1. Fetch Remote Data
      final remoteRecords = await _prayerService.getPrayerRecords(
        studentId: widget.student.id,
        startDate: startDate,
        endDate: endDate,
      );

      // 2. Prepare Local Data (Current Week)
      Map<String, List<String>> localRecordsMap = {};

      // Only include local data if it falls within the requested range
      for (int i = 0; i < widget.student.prayerDates.length; i++) {
        final dateStr = widget.student.prayerDates[i];
        final date = DateTime.parse(dateStr);

        // Check if date is within range
        // We use !isBefore(start) and !isAfter(end) to include boundaries
        // normalize to YYYY-MM-DD for comparison
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final end = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
        ).add(const Duration(days: 1)); // End of day

        if (date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            date.isBefore(end)) {
          if (i < widget.student.prayers.length) {
            localRecordsMap[dateStr] = widget.student.prayers[i];
          }
        }
      }

      // 3. Merge: Start with Remote, overwrite with Local
      // Convert remote List to Map for easy merging
      Map<String, List<String>> mergedMap = {};

      for (var record in remoteRecords) {
        final date = record['date'] as String;
        final prayers = List<String>.from(record['prayers'] ?? []);
        mergedMap[date] = prayers; // Remote data first
      }

      // Overwrite with local (most recent truth)
      localRecordsMap.forEach((date, prayers) {
        mergedMap[date] = prayers;
      });

      // 4. Calculate Stats from Merged Data
      int totalDays = 0;
      int jamaahCount = 0;
      int performanceCount = 0;
      int makeupCount = 0;
      int faitaCount = 0;
      int absentCount = 0;
      Map<String, int> dailyStats = {};

      mergedMap.forEach((date, prayers) {
        totalDays++;

        for (final prayer in prayers) {
          if (prayer == 'جماعة') jamaahCount++;
          if (prayer == 'أداء') performanceCount++;
          if (prayer == 'قضاء') makeupCount++;
          if (prayer == 'فائتة') faitaCount++;
          if (prayer == 'غياب') absentCount++;
        }

        dailyStats[date] = prayers.where((p) => p != 'غياب').length;
      });

      final stats = {
        'totalDays': totalDays,
        'jamaah': jamaahCount,
        'performance': performanceCount,
        'makeup': makeupCount,
        'faita': faitaCount, // key for Faita
        'absent': absentCount,
        'averagePerDay': totalDays > 0
            ? (jamaahCount + performanceCount + makeupCount + faitaCount) /
                  totalDays
            : 0,
        'dailyStats': dailyStats,
      };

      return stats;
    } catch (e) {
      print('❌ Error calculating hybrid stats: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: backcolor,
        title: Text(
          'إحصائيات الصلوات - ${widget.student.name}',
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: backcolor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // فترة زمنية مخصصة
              Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: textcolor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PeriodButton('أسبوع', 7, selectedDaysBack == 7),
                        const SizedBox(width: 8),
                        _PeriodButton('شهر', 30, selectedDaysBack == 30),
                        const SizedBox(width: 8),
                        _PeriodButton('3 أشهر', 90, selectedDaysBack == 90),
                        const SizedBox(width: 8),
                        _PeriodButton('سنة', 365, selectedDaysBack == 365),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // إحصائيات ديناميكية
              FutureBuilder<Map<String, dynamic>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(regsin),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 64,
                            color: Colors.white30,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'لا توجد بيانات صلوات',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final stats = snapshot.data!;
                  final totalDays = (stats['totalDays'] ?? 0) is int
                      ? (stats['totalDays'] as int)
                      : int.tryParse('${stats['totalDays']}') ?? 0;
                  final jamaah = (stats['jamaah'] ?? 0) is int
                      ? (stats['jamaah'] as int)
                      : int.tryParse('${stats['jamaah']}') ?? 0;
                  final performance = (stats['performance'] ?? 0) is int
                      ? (stats['performance'] as int)
                      : int.tryParse('${stats['performance']}') ?? 0;
                  final makeup = (stats['makeup'] ?? 0) is int
                      ? (stats['makeup'] as int)
                      : int.tryParse('${stats['makeup']}') ?? 0;
                  final absent = (stats['absent'] ?? 0) is int
                      ? (stats['absent'] as int)
                      : int.tryParse('${stats['absent']}') ?? 0;
                  final avgPerDay = stats['averagePerDay'] is num
                      ? (stats['averagePerDay'] as num).toDouble()
                      : double.tryParse('${stats['averagePerDay']}') ?? 0.0;

                  return Column(
                    children: [
                      // الإحصائيات العامة
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _StatBox(
                            title: 'الأيام المتابعة',
                            value: totalDays.toString(),
                            icon: Icons.calendar_today,
                            color: Colors.blue,
                          ),
                          _StatBox(
                            title: 'جماعة',
                            value: jamaah.toString(),
                            icon: Icons.people,
                            color: Colors.green,
                          ),
                          _StatBox(
                            title: 'أداء',
                            value: performance.toString(),
                            icon: Icons.check_circle,
                            color: Colors.orange,
                          ),
                          _StatBox(
                            title: 'قضاء',
                            value: makeup.toString(),
                            icon: Icons.history,
                            color: Colors.purple,
                          ),
                          _StatBox(
                            title: 'فائتة',
                            value: (stats['faita'] ?? 0).toString(),
                            icon: Icons.warning_amber_rounded,
                            color: Colors.redAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // متوسط الصلوات
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: textcolor,
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [textcolor, textcolor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'متوسط الصلوات يومياً',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                                Text(
                                  avgPerDay.toStringAsFixed(2),
                                  style: TextStyle(
                                    color: regsin,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: math.min(avgPerDay / 5.0, 1.0),
                                minHeight: 8,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation(
                                  avgPerDay >= 4.5
                                      ? Colors.green
                                      : avgPerDay >= 3
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // رسم بياني الصلوات
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: textcolor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'توزيع أنواع الصلوات',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: PieChart(
                                PieChartData(
                                  sections: [
                                    PieChartSectionData(
                                      color: Colors.green,
                                      value: jamaah.toDouble(),
                                      title: 'جماعة\n$jamaah',
                                      radius: 60,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      color: Colors.orange,
                                      value: performance.toDouble(),
                                      title: 'أداء\n$performance',
                                      radius: 60,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      color: Colors.purple,
                                      value: makeup.toDouble(),
                                      title: 'قضاء\n$makeup',
                                      radius: 60,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if ((stats['faita'] ?? 0) > 0)
                                      PieChartSectionData(
                                        color: Colors.redAccent,
                                        value: (stats['faita'] ?? 0).toDouble(),
                                        title: 'فائتة\n${stats['faita']}',
                                        radius: 60,
                                        titleStyle: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    if (absent > 0)
                                      PieChartSectionData(
                                        color: Colors.red,
                                        value: absent.toDouble(),
                                        title: 'غياب\n$absent',
                                        radius: 60,
                                        titleStyle: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                  centerSpaceRadius: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // تقييم الأداء
                      _PerformanceCard(
                        jamaah: jamaah,
                        performance: performance,
                        makeup: makeup,
                        faita: (stats['faita'] ?? 0) as int,
                        absent: absent,
                        totalDays: totalDays,
                        avgPerDay: avgPerDay,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  InkWell _PeriodButton(String label, int days, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedDaysBack = days;
          _loadStats();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade700 : Colors.white,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: textcolor,
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [textcolor, textcolor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final int jamaah;
  final int performance;
  final int makeup;
  final int faita;
  final int absent;
  final int totalDays;
  final double avgPerDay;

  const _PerformanceCard({
    required this.jamaah,
    required this.performance,
    required this.makeup,
    required this.faita,
    required this.absent,
    required this.totalDays,
    required this.avgPerDay,
  });

  @override
  Widget build(BuildContext context) {
    final completedPrayers = jamaah + performance + makeup + faita;
    final allPrayers = completedPrayers + absent;
    final completionPercentage = allPrayers > 0
        ? (completedPrayers / allPrayers * 100)
        : 0.0;

    String getGrade() {
      if (avgPerDay >= 4.5) return 'ممتاز';
      if (avgPerDay >= 4) return 'جيد جداً';
      if (avgPerDay >= 3) return 'جيد';
      if (avgPerDay >= 2) return 'مقبول';
      return 'يحتاج متابعة';
    }

    Color getGradeColor() {
      if (avgPerDay >= 4.5) return Colors.green;
      if (avgPerDay >= 4) return Colors.lightGreen;
      if (avgPerDay >= 3) return Colors.orange;
      if (avgPerDay >= 2) return Colors.deepOrange;
      return Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: textcolor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'التقييم العام',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: getGradeColor().withOpacity(0.2),
                  border: Border.all(color: getGradeColor()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  getGrade(),
                  style: TextStyle(
                    color: getGradeColor(),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              Text(
                'نسبة الإتمام',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${completionPercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: regsin,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: math.min(completionPercentage / 100, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(getGradeColor()),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'الملاحظات:',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          Text(
            _getRecommendation(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  String _getRecommendation() {
    if (avgPerDay >= 4.5) {
      return '🌟 أداء متميز جداً! استمر على هذا الأداء الرائع.';
    } else if (avgPerDay >= 4) {
      return '👍 أداء جيد جداً، لكن حاول تحسين نسبة الصلوات في جماعة.';
    } else if (avgPerDay >= 3) {
      return '📈 أداء جيد، لا تنسَ المواظبة على الصلوات في الجماعة.';
    } else if (avgPerDay >= 2) {
      return '⚠️ الأداء مقبول، لكن نحتاج لمتابعة أكثر لتحسينه.';
    } else {
      return '❌ يحتاج متابعة مكثفة، حاول المحاولة أكثر في المرات القادمة.';
    }
  }
}
