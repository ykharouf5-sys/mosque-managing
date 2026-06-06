import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/providers/students_provider.dart';
import 'package:yaman/services/prayer_service.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState
    extends ConsumerState<TeacherDashboardScreen> {
  late PrayerService _prayerService;
  String _sortBy = 'performance'; // performance, attendance, points, name
  final bool _isAscending = false;




  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 لوحة معلومات المعلم'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          PopupMenuButton(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'performance',
                child: Text('ترتيب حسب الأداء'),
              ),
              const PopupMenuItem(
                value: 'attendance',
                child: Text('ترتيب حسب الحضور'),
              ),
              const PopupMenuItem(
                value: 'points',
                child: Text('ترتيب حسب النقاط'),
              ),
              const PopupMenuItem(value: 'name', child: Text('ترتيب أبجدي')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.sort, color: Colors.white),
            ),
          ),
        ],
      ),
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text('لا توجد بيانات طلاب بعد'),
                ],
              ),
            );
          }

          // ترتيب الطلاب
          List<Student> sortedStudents = List.from(students);
          _sortStudents(sortedStudents);

          return SingleChildScrollView(
            child: Column(
              children: [
                // بطاقة الإحصائيات العامة
                _buildSummaryCard(students),
                const SizedBox(height: 16),
                // بطاقة التنبيهات المهمة
                _buildAlertsCard(sortedStudents),
                const SizedBox(height: 16),
                // قائمة الطلاب
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'جميع الطلاب (${sortedStudents.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedStudents.length,
                  itemBuilder: (context, index) {
                    return _buildStudentCard(sortedStudents[index], index);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('خطأ: $error')),
      ),
    );
  }

  void _sortStudents(List<Student> students) {
    switch (_sortBy) {
      case 'performance':
        students.sort((a, b) {
          final avgA = _calculatePerformanceAverage(a);
          final avgB = _calculatePerformanceAverage(b);
          return _isAscending ? avgA.compareTo(avgB) : avgB.compareTo(avgA);
        });
        break;
      case 'attendance':
        students.sort((a, b) {
          final attA = a.attendance.length ?? 0;
          final attB = b.attendance.length ?? 0;
          return _isAscending ? attA.compareTo(attB) : attB.compareTo(attA);
        });
        break;
      case 'points':
        students.sort((a, b) {
          final pA = a.points ?? 0;
          final pB = b.points ?? 0;
          return _isAscending ? pA.compareTo(pB) : pB.compareTo(pA);
        });
        break;
      case 'name':
        students.sort(
          (a, b) => _isAscending
              ? a.name.compareTo(b.name)
              : b.name.compareTo(a.name),
        );
        break;
    }
  }

  double _calculatePerformanceAverage(Student student) {
    if (student.prayers.isEmpty) return 0;
    int total = 0;
    int count = 0;
    for (var day in student.prayers) {
      for (var prayer in day) {
        if (prayer == 'أداء') {
          total += 2;
        } else if (prayer == 'جماعة') {
          total += 3;
        } else if (prayer == 'قضاء') {
          total += 1;
        }
        count++;
      }
        }
    return count > 0 ? total / count : 0;
  }

  Widget _buildSummaryCard(List<Student> students) {
    int totalAttendance = 0;
    int totalPoints = 0;
    int completedToday = 0;

    for (var student in students) {
      totalAttendance += student.attendance.length ?? 0;
      totalPoints += student.points ?? 0;
      if (student.prayers.isNotEmpty) {
        final lastDay = student.prayers.last;
        if (lastDay.isNotEmpty) {
          completedToday++;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص الفصل 📋',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem('👥', 'إجمالي الطلاب', students.length.toString()),
              _StatItem('✅', 'أكملوا اليوم', completedToday.toString()),
              _StatItem('⭐', 'إجمالي النقاط', totalPoints.toString()),
              _StatItem('📍', 'إجمالي الحضور', totalAttendance.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsCard(List<Student> students) {
    // البحث عن طلاب بمشاكل
    List<Student> problematicStudents = [];
    for (var student in students) {
      // تحديد: طلاب بدون صلوات اليوم
      if (student.prayers.isEmpty) {
        problematicStudents.add(student);
      } else {
        final lastDay = student.prayers.last;
        if (lastDay.isEmpty) {
          problematicStudents.add(student);
        }
      }
    }

    if (problematicStudents.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          border: Border.all(color: Colors.green, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 12),
            Text(
              'ممتاز! جميع الطلاب أكملوا صلواتهم اليوم 🎉',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '⚠️ ${problematicStudents.length} طالب لم يكملوا صلواتهم',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: problematicStudents.take(5).map((student) {
              return Chip(
                label: Text(student.name),
                backgroundColor: Colors.orange[100],
                labelStyle: TextStyle(color: Colors.orange[900]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Student student, int index) {
    final avgPerformance = _calculatePerformanceAverage(student);
    final medal = index == 0
        ? '🥇'
        : index == 1
        ? '🥈'
        : index == 2
        ? '🥉'
        : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // الترتيب أو الرقم
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: medal.isNotEmpty
                  ? Text(medal, style: const TextStyle(fontSize: 24))
                  : Text(
                      (index + 1).toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // البيانات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Badge('📞 ${student.phone ?? 'N/A'}', Colors.blue),
                    const SizedBox(width: 8),
                    _Badge('⭐ ${student.points ?? 0}', Colors.amber),
                  ],
                ),
              ],
            ),
          ),
          // الأداء
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getPerformanceColor(avgPerformance).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${avgPerformance.toStringAsFixed(1)}/3',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getPerformanceColor(avgPerformance),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${student.attendance.length ?? 0} حضور',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPerformanceColor(double performance) {
    if (performance >= 2.5) return Colors.green;
    if (performance >= 1.5) return Colors.orange;
    return Colors.red;
  }

  Widget _StatItem(String icon, String label, String value) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _Badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
