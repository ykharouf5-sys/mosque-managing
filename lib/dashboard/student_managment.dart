import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/services/connectivity_service.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/students/StudentInterface.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yaman/widget/animated_background.dart';
import 'package:yaman/utils/responsive_helper.dart';
import 'package:yaman/widget/teachercards.dart';
import 'package:yaman/widget/studentcards.dart';


class StudentManagment extends StatefulWidget {
  const StudentManagment({super.key});

  @override
  State<StudentManagment> createState() => _StudentManagmentState();
}

class _StudentManagmentState extends State<StudentManagment>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final SupabaseService _supabase = SupabaseService();
  List<Teacher> _teachers = [];
  List<Student> _students = [];
  List<Student> _filteredStudents = [];
  late AnimationController _controller;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  final int _pageSize = 20;

  StreamSubscription? _studentSubscription;
  StreamSubscription? _teacherSubscription;

  @override
  void initState() {
    super.initState();
    _loadAll(); // Initial data load
    _listenToDataChanges(); // Listen to central storage stream
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _controller.forward();
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.removeListener(_filterStudents);
    _searchController.dispose();
    _studentSubscription?.cancel();
    _teacherSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      // Set loading state
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      
      // Load initial data. The stream will keep it updated after this.
      final teachers = await _storage.loadTeachers(forceRefresh: true);
      final students = await _storage.loadStudents(forceRefresh: true);
      
      if (mounted) {
        setState(() {
          _teachers = teachers;
          _students = students;
          _filterStudents(); // Apply search filter if any
          _isLoading = false;
        });
        print(
          'Loaded ${teachers.length} teachers and ${students.length} students',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('Error loading data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Centralized stream listener
  void _listenToDataChanges() {
    _studentSubscription = _storage.studentsStream.listen((students) {
      if (mounted) {
        setState(() {
          _students = students;
          _filterStudents(); // Re-apply search filter
        });
      }
    });

    _teacherSubscription = _storage.teachersStream.listen((teachers) {
      if (mounted) {
        setState(() {
          _teachers = teachers;
        });
      }
    });
  }

  Future<void> _loadMoreStudents() async {
    final more = await _supabase.loadStudents(
      limit: _pageSize,
      offset: _students.length,
    );
    if (more.isNotEmpty) {
      final combined = [..._students, ...more];
      await _storage.saveStudents(combined);
      setState(() {
        _students = _filteredStudents =
            combined; // This updates the master list
        _filterStudents(); // This updates the displayed list
      });
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = List.from(_students);
      } else {
        _filteredStudents = _students.where((student) {
          return student.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _addStudentDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedTeacherName = _teachers.isNotEmpty
        ? _teachers.first.name
        : null;
    String? selectedTeacherPhone = _teachers.isNotEmpty
        ? _teachers.first.number
        : null;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('إضافة طالب جديد'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_teachers.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedTeacherName,
                        decoration: const InputDecoration(
                          labelText: 'اختر الأستاذ',
                        ),
                        items: _teachers
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.name,
                                child: Text(
                                  t.name,
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          selectedTeacherName = v;
                          selectedTeacherPhone = _teachers
                              .firstWhere((t) => t.name == v)
                              .number;
                        },
                      )
                    else
                      const Text(
                        'يجب إضافة أستاذ أولاً',
                        textDirection: TextDirection.rtl,
                      ),
                    TextField(
                      controller: nameController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطالب',
                      ),
                    ),
                    TextField(
                      controller: phoneController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                      ),
                    ),
                    TextField(
                      controller: emailController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'الإيميل'),
                    ),
                    TextField(
                      controller: passwordController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'كلمة السر'),
                      obscureText: true,
                    ),
                    if (isLoading)
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (selectedTeacherName == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يجب اختيار أستاذ'),
                              ),
                            );
                            return;
                          }

                          try {
                            setDialogState(() {
                              isLoading = true;
                            });

                            final studentToCreate = Student(
                              id: '', // Will be generated
                              name: nameController.text.trim(),
                              phone: phoneController.text.trim(),
                              teacherName: selectedTeacherName ?? '',
                              teacherPhone: selectedTeacherPhone ?? '',
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                              points: 0,
                              attendance: [],
                              prayers: [],
                              prayerDates: [],
                              memorization: [],
                            );

                            final createdStudent = await _storage
                                .addStudentAndUser(studentToCreate);

                            setState(() {
                              _students.add(createdStudent);
                              _filterStudents();
                            });

                            setDialogState(() {
                              isLoading = false;
                            });

                            Navigator.pop(context);

                            if (createdStudent.id.startsWith('temp_')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'تم الحفظ محلياً (Offline). سيتم المزامنة عند توفر الإنترنت.'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم إضافة الطالب بنجاح (Cloud)'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'خطأ في إضافة الطالب: ${e.toString()}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: Text('إضافة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editStudentDialog(Student student) async {
    final nameController = TextEditingController(text: student.name);
    final phoneController = TextEditingController(text: student.phone);
    final emailController = TextEditingController(text: student.email);
    final passwordController = TextEditingController(text: student.password);
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('تعديل بيانات الطالب: ${student.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'اسم الطالب'),
                    ),
                    TextField(
                      controller: phoneController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                    ),
                    TextField(
                      controller: emailController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'الإيميل'),
                    ),
                    TextField(
                      controller: passwordController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'كلمة السر الجديدة (اختياري)'),
                      obscureText: true,
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          try {
                            setDialogState(() => isLoading = true);

                            final updatedStudent = student.copyWith(
                              name: nameController.text.trim(),
                              phone: phoneController.text.trim(),
                              email: emailController.text.trim(),
                              password: passwordController.text.isNotEmpty 
                                  ? passwordController.text.trim() 
                                  : student.password,
                            );

                            // 1. Update identifying data (Local & Cloud Table)
                            await _storage.updateStudent(updatedStudent);
                            
                            // 2. Update Auth User if email/password changed AND it's a real account (not offline temp ID)
                            bool authUpdateNeeded = updatedStudent.email != student.email || passwordController.text.isNotEmpty;
                            bool isRealAccount = !student.id.startsWith('temp_');

                            if (authUpdateNeeded) {
                              if (isRealAccount) {
                                try {
                                  await _supabase.updateAuthUserById(
                                    student.id,
                                    email: updatedStudent.email,
                                    password: passwordController.text.isNotEmpty ? updatedStudent.password : null,
                                  );
                                } catch (authError) {
                                  print('⚠️ Auth update failed but data was saved: $authError');
                                  // Don't fail the whole operation if only Auth linking failed (Edge Function might be down)
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('تم حفظ البيانات ولكن تعذر تحديث بيانات الدخول تلقائياً: $authError'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                }
                              } else {
                                print('ℹ️ Skipping Auth update for offline student (temp_ ID)');
                              }
                            }

                            await _loadAll();
                            if (mounted) {
                              setDialogState(() => isLoading = false);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم تحديث بيانات الطالب بنجاح'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() => isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ في التحديث: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الطالب ${student.name}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _storage.deleteStudent(student.id);
        // Also delete from auth users if possible (depends on your Supabase permissions/setup)
        // For now we assume StorageService handles the data deletion
        await _loadAll();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الطالب بنجاح'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحذف: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showTransferStudentDialog(Student student) async {
    String? selectedTeacherId;
    String? selectedTeacherName;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('نقل الطالب: ${student.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'اختر الأستاذ الجديد:',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTeacherId,
                      decoration: const InputDecoration(
                        labelText: 'الأستاذ',
                        border: OutlineInputBorder(),
                      ),
                      items: _teachers
                          .where((t) => t.id != student.teacherId) // Exclude current teacher
                          .map((teacher) {
                        return DropdownMenuItem<String>(
                          value: teacher.id,
                          child: Text(teacher.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedTeacherId = value;
                          selectedTeacherName = _teachers
                              .firstWhere((t) => t.id == value)
                              .name;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedTeacherName != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'سيتم نقل الطالب من "${student.teacherName}" إلى "$selectedTeacherName"',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: selectedTeacherId == null
                      ? null
                      : () async {
                          try {
                            Navigator.pop(context);
                            
                            // Show loading indicator
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('جاري نقل الطالب...'),
                                  ],
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );

                            // Perform transfer using StorageService
                            final newTeacher = _teachers.firstWhere(
                              (t) => t.id == selectedTeacherId,
                            );
                            
                            final updatedStudent = student.copyWith(
                              teacherId: selectedTeacherId,
                              teacherName: newTeacher.name,
                              teacherPhone: newTeacher.number,
                            );

                            await _storage.updateStudent(updatedStudent);

                            // Refresh students list
                            await _loadAll();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تم نقل الطالب ${student.name} إلى الأستاذ $selectedTeacherName بنجاح!',
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('خطأ في نقل الطالب: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                  child: const Text('نقل'),
                ),
              ],
            );
          },
        );
      },
    );
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
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن طالب...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                )
              : const Text(
                  'إدارة الطلاب',
                  style: TextStyle(color: Colors.white),
                ),
          backgroundColor: backcolor,
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                  }
                });
              },
            ),
            if (!_isSearching)
              StreamBuilder<bool>(
                stream: ConnectivityService().connectivityStream,
                builder: (context, snap) {
                  final online = snap.data ?? true;
                  return Tooltip(
                    message: online ? 'متصل' : 'غير متصل',
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: online ? Colors.greenAccent : Colors.redAccent,
                    ),
                  );
                },
              ),
          ],
        ),
        body: Stack(
          children: [
            const AnimatedBackground(),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _controller,
                        curve: Curves.easeOut,
                      ),
                      child: Card(
                        color: textcolor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Icon(
                                    Icons.person,
                                    color: Colors.amber,
                                    size: 32,
                                  ),
                                    Text(
                                      'الأساتذة',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: responsive.fontSize(14),
                                      ),
                                    ),
                                    Text(
                                      '${_teachers.length}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: responsive.fontSize(18),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              Column(
                                children: [
                                  Icon(
                                    Icons.school,
                                    color: Colors.lightBlueAccent,
                                    size: 32,
                                  ),
                                    Text(
                                      'الطلاب',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: responsive.fontSize(14),
                                      ),
                                    ),
                                    Text(
                                      '${_students.length}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: responsive.fontSize(18),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      textDirection: TextDirection.rtl,
                      'قائمة الأساتذة:',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: responsive.fontSize(16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_isLoading
                        ? List.generate(
                            3,
                            (i) => Shimmer.fromColors(
                              baseColor: textcolor.withValues(alpha: 0.25),
                              highlightColor: textcolor.withValues(alpha: 0.4),
                              child: Container(
                                height: 72,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: textcolor.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          )
                        : _teachers.asMap().entries.map((entry) {
                            final int i = entry.key;
                            final Teacher t = entry.value;
                            return SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0.2, 0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _controller,
                                      curve: Interval(
                                        i * 0.08,
                                        1,
                                        curve: Curves.easeOut,
                                      ),
                                    ),
                                  ),
                              child: Card(
                                color: textcolor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.amber,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    t.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'رقم الهاتف: ${t.number}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })),
                    const SizedBox(height: 18),
                    Text(
                      textDirection: TextDirection.rtl,
                      'قائمة الطلاب:',
                      style: TextStyle(
                        color: Colors.lightBlueAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_isLoading
                        ? List.generate(
                            6,
                            (i) => Shimmer.fromColors(
                              baseColor: textcolor.withValues(alpha: 0.25),
                              highlightColor: textcolor.withValues(alpha: 0.4),
                              child: Container(
                                height: 72,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: textcolor.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          )
                        : _filteredStudents.asMap().entries.map((entry) {
                            final int i = entry.key;
                            final Student s = entry.value;
                            return SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0.2, 0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _controller,
                                      curve: Interval(
                                        i * 0.06,
                                        1,
                                        curve: Curves.easeOut,
                                      ),
                                    ),
                                  ),
                              child: Card(
                                color: textcolor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.lightBlueAccent,
                                    child: Icon(
                                      Icons.school,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    s.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'نقاط: ${s.points}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 22),
                                        tooltip: 'تعديل الطالب',
                                        onPressed: () => _editStudentDialog(s),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.swap_horiz, color: Colors.amber, size: 24),
                                        tooltip: 'نقل الطالب',
                                        onPressed: () {
                                          _showTransferStudentDialog(s);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
                                        tooltip: 'حذف الطالب',
                                        onPressed: () => _deleteStudent(s),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StudentInterface(student: s),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          })),
                    if (!_isLoading && !_isSearching)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: TextButton(
                          onPressed: _loadMoreStudents,
                          child: const Text('تحميل المزيد'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
