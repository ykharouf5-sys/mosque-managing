import 'package:flutter/material.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/widget/animated_background.dart';
import 'package:yaman/services/supabase_service.dart';

class Gifts extends StatefulWidget {
  const Gifts({super.key});

  @override
  State<Gifts> createState() => _GiftsState();
}

class _GiftsState extends State<Gifts> {
  final StorageService _storage = StorageService();
  final SupabaseService _supabase = SupabaseService();
  List<Teacher> _teachers = [];
  List<Student> _students = [];
  Teacher? _selectedTeacher;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _setupRealtimeSync();
    // Listen to local storage stream updates so UI refreshes when local data changes
    _storage.studentsStream.listen((students) {
      if (!mounted) return;
      setState(() {
        _students = students;
      });
    });

    _storage.teachersStream.listen((teachers) {
      if (!mounted) return;
      setState(() {
        _teachers = teachers;
        _teachers = teachers;
      });
    });
  }

  Future<void> _loadAll() async {
    try {
      setState(() {
        // Show loading state
      });
      
      print('🔄 Loading data for Gifts screen...');
      // Use local-first strategy for fast loading
      final teachers = await _storage.loadTeachers(forceRefresh: false);
      final students = await _storage.loadStudents(forceRefresh: false);
      
      print('📊 Loaded: ${teachers.length} teachers, ${students.length} students');
      
      setState(() {
        _teachers = teachers;
        _students = students;
        _teachers = teachers;
        _students = students;
      });
      
      print('✅ Gifts screen data loaded successfully');
      
      // If no students, try to sync from cloud
      if (_students.isEmpty) {
        print('⚠️ No students found locally, attempting cloud sync...');
        await _syncFromCloud();
      }
    } catch (e, stackTrace) {
      print('❌ Error loading data for rewards: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: ${e.toString().length > 100 ? "${e.toString().substring(0, 100)}..." : e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _setupRealtimeSync() {
    _supabase.subscribeToStudents().listen((cloudStudents) async {
      if (!mounted) return;
      if (cloudStudents.isEmpty) return;
      if (cloudStudents.length < _students.length) return;
      setState(() {
        _students = cloudStudents;
      });
      await _storage.saveStudents(cloudStudents);
    });

    _supabase.subscribeToTeachers().listen((cloudTeachers) async {
      if (!mounted) return;
      if (cloudTeachers.isEmpty) return;
      if (cloudTeachers.length < _teachers.length) return;
      setState(() {
        _teachers = cloudTeachers;
      });
      await _storage.saveTeachers(cloudTeachers);
    });

    _syncFromCloud();
  }

  Future<void> _syncFromCloud() async {
    try {
      print('🔄 Starting cloud sync in Gifts screen...');
      final cloudStudents = await _supabase.loadStudents();
      final cloudTeachers = await _supabase.loadTeachers();
      if (!mounted) return;
      
      print('📥 Cloud data: ${cloudStudents.length} students, ${cloudTeachers.length} teachers');
      print('📦 Local data: ${_students.length} students, ${_teachers.length} teachers');
      
      // Always update if cloud has data (even if less, to ensure sync)
      if (cloudStudents.isNotEmpty) {
        setState(() {
          _students = cloudStudents;
        });
        await _storage.saveStudents(cloudStudents);
        print('✅ Students synced: ${cloudStudents.length} students');
      }
      
      if (cloudTeachers.isNotEmpty) {
        setState(() {
          _teachers = cloudTeachers;
          _teachers = cloudTeachers;
        });
        await _storage.saveTeachers(cloudTeachers);
        print('✅ Teachers synced: ${cloudTeachers.length} teachers');
      }
    } catch (e) {
      print('❌ Error in _syncFromCloud: $e');
      // Don't show error to user, just log it
    }
  }

  Future<void> _addPoints(Student s, int amount) async {
    try {
      final idx = _students.indexWhere((x) => x.id == s.id);
      if (idx == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: لم يتم العثور على الطالب'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get today's date string
      final today = DateTime.now();
      final todayStr =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      // Reset dailyPointsAdded if lastPointsDate is not today
      int dailyPointsAdded = s.dailyPointsAdded;
      if (s.lastPointsDate != todayStr) {
        dailyPointsAdded = 0;
      }

      // Limit max daily points to 50
      final maxDailyPoints = 50;
      if (dailyPointsAdded + amount > maxDailyPoints) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الوصول إلى الحد الأقصى للنقاط اليومية (50 نقطة)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _students[idx] = Student(
        id: s.id,
        name: s.name,
        phone: s.phone,
        teacherName: s.teacherName,
        teacherPhone: s.teacherPhone,
        email: s.email,
        password: s.password,
        points: s.points + amount,
        attendance: s.attendance,
        prayers: s.prayers,
        prayerDates: s.prayerDates,
        memorization: s.memorization,
        dailyPointsAdded: dailyPointsAdded + amount,
        lastPointsDate: todayStr,
      );

      setState(() {});
      await _storage.saveStudents(_students);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة $amount نقطة لـ ${s.name} بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      print(
        'Added $amount points to student ${s.name}. New total: ${s.points + amount}',
      );
    } catch (e) {
      print('Error adding points: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إضافة النقاط: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Student> get _sortedStudents {
    if (_students.isEmpty) return [];
    
    List<Student> list;
    if (_selectedTeacher == null) {
      list = List<Student>.from(_students);
    } else {
      list = _students
          .where((s) => s.teacherName == _selectedTeacher!.name)
          .toList();
    }
    
    // Sort by points descending
    list.sort((a, b) => b.points.compareTo(a.points));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backcolor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: backcolor,
        title: Text(
          "منح نقاط",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, "/chatscreen");
            },
            icon: Icon(Icons.message, size: 27, color: Colors.white),
          ),
        ],
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
                width: 75,
                height: 75,
                child: Image.asset("assets/image/logomosque.png"),
              ),
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.rtl,
              child: DropdownButtonFormField<Teacher?>(
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
                items: [
                  const DropdownMenuItem<Teacher?>(
                    value: null,
                    child: Text('عرض الكل', style: TextStyle(color: Colors.white)),
                  ),
                  ..._teachers.map(
                    (t) => DropdownMenuItem<Teacher?>(
                      value: t,
                      child: Text(t.name, style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedTeacher = v),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: textcolor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Builder(
                  builder: (ctx) {
                    // Debug: print student count to console to help diagnose empty list
                    print('🔍 Gifts screen building with ${_students.length} students, selectedTeacher=${_selectedTeacher?.name}, sorted=${_sortedStudents.length}');
                    
                    if (_students.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.school, size: 64, color: Colors.white54),
                              const SizedBox(height: 16),
                              const Text(
                                'لا يوجد طلاب',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _loadAll(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('تحديث'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: regsin,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    if (_sortedStudents.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              _selectedTeacher != null
                                  ? 'لا يوجد طلاب لهذا الأستاذ'
                                  : 'لا يوجد طلاب',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                  itemCount: _sortedStudents.length,
                  itemBuilder: (context, index) {
                    final hasFiltered = _selectedTeacher != null &&
                        _students.any((s) => s.teacherName == _selectedTeacher!.name);
                    if (!hasFiltered && _selectedTeacher != null && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            'لا يوجد طلاب لهذا الأستاذ، تم عرض جميع الطلاب',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    }
                    final s = _sortedStudents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.blueGrey[900],
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (index < 3) ...[
                                    Icon(
                                      Icons.emoji_events,
                                      color: index == 0
                                          ? Colors.yellowAccent
                                          : index == 1
                                          ? Colors.grey
                                          : Colors.brown,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Text(
                                      s.name.isNotEmpty ? s.name : 'طالب ${index + 1}',
                                      textDirection: TextDirection.rtl,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  'نقاط: ${s.points}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Wrap(
                                    spacing: 25,
                                    children: [
                                      _GiftButton(
                                        label: '+5',
                                        onTap: () => _addPoints(s, 5),
                                      ),
                                      _GiftButton(
                                        label: '+10',
                                        onTap: () => _addPoints(s, 10),
                                      ),
                                      _GiftButton(
                                        label: '15',
                                        onTap: () => _addPoints(s, 15),
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
                  );
                  },
              ),
            ),
           ) ],
        ),
          ),
        ],
      ),
    );
  }
}

class _GiftButton extends StatelessWidget {
  const _GiftButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: regsin,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

extension DateOnlyCompare on DateTime {
  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

extension AttendanceExtension on Student {
  bool hasAttendedToday() {
    if (attendance.isEmpty) return false;
    // Assuming attendance list corresponds to days in order, last element is latest day
    // This is a simplification; ideally attendance should be date-mapped
    return attendance.last;
  }
}
