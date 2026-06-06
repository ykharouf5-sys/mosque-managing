import 'package:flutter/material.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/widget/animated_background.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/utils/responsive_helper.dart';


class Tracking extends StatefulWidget {
  const Tracking({super.key});

  @override
  State<Tracking> createState() => _TrackingState();
}

class _TrackingState extends State<Tracking> {
  final StorageService _storage = StorageService();
  List<Teacher> _teachers = [];
  List<Student> _students = [];
  Teacher? _selectedTeacher;
  Map<String, bool?> _currentAttendance = {};
  bool _attendanceConfirmed = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final teachers = await _storage.loadTeachers();
      final students = await _storage.loadStudents();
      setState(() {
        _teachers = teachers;
        _students = students;
        if (_teachers.isNotEmpty) {
          _selectedTeacher = _teachers.first;
        }
      });
      print(
        'Loaded ${teachers.length} teachers and ${students.length} students for tracking',
      );
    } catch (e) {
      print('Error loading data for tracking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل البيانات: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Student> get _filteredStudents {
    if (_selectedTeacher == null) return [];
    return _students
        .where((s) => s.teacherName == _selectedTeacher!.name)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return SafeArea(
      top: false,
      bottom: true,
      child: Scaffold(
        backgroundColor: backcolor,
        appBar: AppBar(
          backgroundColor: backcolor,
          title: Text(
            "متابعة الحضور",
            style: TextStyle(
              fontSize: responsive.fontSize(22),
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.message, size: 27, color: Colors.white),
            ),
          ],
          centerTitle: true,
        ),
        body: Stack(
          children: [
            const AnimatedBackground(),
            Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  height: responsive.width(20),
                  width: responsive.width(20),
                  child: Image.asset("assets/image/logomosque.png"),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.event_available,
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "متابعة الحضور",
                    style: TextStyle(
                      fontSize: responsive.fontSize(18),
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Teacher>(
                      initialValue: _selectedTeacher,
                      isExpanded: true,
                      dropdownColor: textcolor,
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        prefixIcon: const Icon(Icons.person, color: Colors.white),
                        labelText: 'اختر الأستاذ',
                        labelStyle: const TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: regsin),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _teachers
                          .map(
                            (t) => DropdownMenuItem<Teacher>(
                              value: t,
                              child: Text(t.name, style: const TextStyle(color: Colors.white)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedTeacher = v;
                          _currentAttendance = {};
                          _attendanceConfirmed = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: textcolor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    itemCount: _filteredStudents.length,
                    itemBuilder: (context, index) {
                      final s = _filteredStudents[index];
                      
                      // Check if already marked today
                      final today = DateTime.now();
                      final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
                      final bool isMarkedToday = s.attendanceDates.contains(todayStr);

                      final attendanceStatus =
                          _currentAttendance[s.id] ??
                          (s.attendance.isNotEmpty ? s.attendance.last : null);
                          
                      Color cardColor = Colors.blueGrey[900]!;
                      if (_attendanceConfirmed || isMarkedToday) {
                        cardColor = regsin.withOpacity(0.8);
                      } else if (attendanceStatus == true) {
                        cardColor = Colors.green[300]!;
                      } else if (attendanceStatus == false) {
                        cardColor = Colors.red[300]!;
                      }
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  s.name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: responsive.fontSize(16),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  'نقاط: ${s.points}',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: responsive.fontSize(14),
                                    ),
                                  ),
                                if (isMarkedToday)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'تم تسجيل الحضور اليوم',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Radio<bool>(
                                          value: true,
                                          groupValue: attendanceStatus,
                                          activeColor: Colors.white,
                                          onChanged: (_attendanceConfirmed || isMarkedToday)
                                              ? null
                                              : (val) {
                                                  setState(() {
                                                    _currentAttendance[s.id] =
                                                        val;
                                                  });
                                                },
                                        ),
                                        const Text(
                                          'حضور',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      children: [
                                        Radio<bool>(
                                          value: false,
                                          groupValue: attendanceStatus,
                                          activeColor: Colors.redAccent,
                                          onChanged: (_attendanceConfirmed || isMarkedToday)
                                              ? null
                                              : (val) {
                                                  setState(() {
                                                    _currentAttendance[s.id] =
                                                        val;
                                                  });
                                                },
                                        ),
                                        const Text(
                                          'غياب',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            try {
              if (_currentAttendance.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('لم يتم تحديد حالة الحضور لأي طالب'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              bool hasChanges = false;
              final today = DateTime.now();
              final todayStr =
                  "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

              for (var s in _filteredStudents) {
                final present = _currentAttendance[s.id];
                if (present == null) continue;

                final idx = _students.indexWhere((x) => x.id == s.id);
                if (idx == -1) continue;

                int dailyPointsAdded = s.dailyPointsAdded;
                bool isNewDay = s.lastPointsDate != todayStr;
                if (isNewDay) {
                  dailyPointsAdded = 0;
                }

                int pointsToAdd = 0;
                if (isNewDay) {
                  pointsToAdd += 20;
                  dailyPointsAdded += 20;
                }

                // Restriction: Check attendanceDates
                bool alreadyMarkedToday = s.attendanceDates.contains(todayStr);

                bool addAttendance = !alreadyMarkedToday;

                if (addAttendance && present) {
                  pointsToAdd += 10;
                  dailyPointsAdded += 10;
                }

                if (pointsToAdd > 0 || addAttendance) {
                  final updated = Student(
                    id: s.id,
                    name: s.name,
                    phone: s.phone,
                    teacherName: s.teacherName,
                    teacherPhone: s.teacherPhone,
                    email: s.email,
                    password: s.password,
                    points: s.points + pointsToAdd,
                    attendance: addAttendance
                        ? [...s.attendance, present]
                        : s.attendance,
                    attendanceDates: addAttendance 
                        ? [...s.attendanceDates, todayStr]
                        : s.attendanceDates,
                    prayers: s.prayers,
                    prayerDates: s.prayerDates,
                    memorization: s.memorization,
                    dailyPointsAdded: dailyPointsAdded,
                    lastPointsDate: todayStr,
                  );
                  _students[idx] = updated;
                  hasChanges = true;
                }
              }

              if (hasChanges) {
                await _storage.saveStudents(_students);
                print(
                  'Attendance saved successfully for ${_currentAttendance.length} students',
                );

                setState(() {
                  _attendanceConfirmed = true;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم تأكيد الحضور لجميع الطلاب بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('لا توجد تغييرات لحفظها'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            } catch (e) {
              print('Error saving attendance: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('خطأ في حفظ الحضور: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          label: const Text('تأكيد الحضور'),
          icon: const Icon(Icons.check),
          backgroundColor: regsin,
        ),
      ),
    );
  }
}
