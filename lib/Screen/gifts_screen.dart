import 'package:flutter/material.dart';
import 'dart:async';
import 'package:yaman/models/student.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/widget/animated_background.dart';
import 'package:yaman/widget/variable.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  final StorageService _storage = StorageService();
  List<Student> _allStudents = [];
  List<Teacher> _teachers = [];
  List<Student> _filteredStudents = [];
  Teacher? _selectedTeacher;
  bool _isLoading = true;
  String? _feedbackMessage;
  bool _isError = false;
  Timer? _debounce;

  // A map to hold local point changes before saving
  final Map<String, int> _pointChanges = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });
    try {
      final students = await _storage.loadStudents();
      final teachers = await _storage.loadTeachers();
      setState(() {
        _allStudents = students;
        _teachers = teachers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _feedbackMessage = 'خطأ في تحميل الطلاب: $e';
        _isError = true;
      });
    }
  }

  void _onTeacherSelected(Teacher? teacher) {
    setState(() {
      _selectedTeacher = teacher;
      if (teacher == null) {
        _filteredStudents = [];
      } else {
        _filteredStudents = _allStudents
            .where((s) => s.teacherName == teacher.name)
            .toList();
        // Sort by points to determine medals
        _filteredStudents.sort((a, b) => b.points.compareTo(a.points));
      }
    });
  }

  void _updatePoints(Student student, int amount) {
    setState(() {
      // Get current points from the student object
      int currentPoints = student.points;
      // Get pending changes for this student, if any
      int pendingChange = _pointChanges[student.id] ?? 0;
      // Calculate new total pending change
      int newTotalChange = pendingChange + amount;

      // Ensure points don't go below zero
      if ((currentPoints + newTotalChange) < 0) {
        // If trying to subtract more points than available, just set change to make points zero
        _pointChanges[student.id] = -currentPoints;
      } else {
        _pointChanges[student.id] = newTotalChange;
      }

      // Auto-save with debounce
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(seconds: 3), () {
        if (_pointChanges.isNotEmpty) _saveAllChanges();
      });
    });
  }

  Future<void> _saveAllChanges() async {
    if (_pointChanges.isEmpty) {
      _showFeedback('لا توجد تغييرات لحفظها', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _feedbackMessage = 'جاري حفظ النقاط...';
    });

    try {
      final updatedStudents = _allStudents.map((student) {
        if (_pointChanges.containsKey(student.id)) {
          final change = _pointChanges[student.id]!;
          return student.copyWith(points: student.points + change);
        }
        return student;
      }).toList();

      await _storage.saveStudents(updatedStudents);

      setState(() {
        _allStudents = updatedStudents;
        _pointChanges.clear();
        _isLoading = false;
      });
      _showFeedback('تم حفظ النقاط تلقائياً بنجاح!', isError: false);
    } catch (e) {
      _showFeedback('خطأ في حفظ النقاط: $e', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showFeedback(String message, {required bool isError}) {
    setState(() {
      _feedbackMessage = message;
      _isError = isError;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _feedbackMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backcolor,
      appBar: AppBar(
        title: const Text(
          'منح النقاط والمكافآت',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: backcolor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              onPressed: _saveAllChanges,
              tooltip: 'حفظ كل التغييرات',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadInitialData();
              _onTeacherSelected(null);
            },
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SizedBox(
                      height: 75,
                      width: 75,
                      child: Image.asset("assets/image/logomosque.png"),
                    ),
                    const SizedBox(height: 16),
                    if (_teachers.isNotEmpty)
                      DropdownButtonFormField<Teacher>(
                        initialValue: _selectedTeacher,
                        hint: const Text(
                          'اختر الأستاذ لعرض طلابه',
                          style: TextStyle(color: Colors.white70),
                        ),
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: textcolor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        dropdownColor: textcolor,
                        style: const TextStyle(color: Colors.white),
                        items: _teachers.map((Teacher teacher) {
                          return DropdownMenuItem<Teacher>(
                            value: teacher,
                            child: Text(teacher.name),
                          );
                        }).toList(),
                        onChanged: _onTeacherSelected,
                      ),
                  ],
                ),
              ),
              if (_feedbackMessage != null)
                Container(
                  color: _isError
                      ? Colors.red.withOpacity(0.8)
                      : Colors.green.withOpacity(0.8),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _isError ? Icons.error : Icons.check_circle,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _feedbackMessage!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedTeacher == null
                    ? const Center(
                        child: Text(
                          'يرجى اختيار أستاذ أولاً',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      )
                    : _filteredStudents.isEmpty
                    ? const Center(
                        child: Text(
                          'لا يوجد طلاب لهذا الأستاذ',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          final pendingChange = _pointChanges[student.id] ?? 0;
                          final displayPoints = student.points + pendingChange;

                          return Card(
                            color: textcolor,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: regsin,
                                    child: Text(
                                      displayPoints.toString(),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        if (index == 0)
                                          const Text(
                                            '🥇',
                                            style: TextStyle(fontSize: 20),
                                          )
                                        else if (index == 1)
                                          const Text(
                                            '🥈',
                                            style: TextStyle(fontSize: 20),
                                          )
                                        else if (index == 2)
                                          const Text(
                                            '🥉',
                                            style: TextStyle(fontSize: 20),
                                          ),
                                        if (index < 3) const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            student.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Point modification buttons
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => _updatePoints(student, -1),
                                  ),
                                  Text(
                                    pendingChange.toString(),
                                    style: TextStyle(
                                      color: pendingChange > 0
                                          ? Colors.greenAccent
                                          : pendingChange < 0
                                          ? Colors.redAccent
                                          : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.greenAccent,
                                    ),
                                    onPressed: () => _updatePoints(student, 1),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
