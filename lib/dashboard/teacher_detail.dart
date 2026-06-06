import 'package:flutter/material.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/widget/studencard.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/widget/variable.dart';

class TeacherDetailScreen extends StatefulWidget {
  const TeacherDetailScreen({super.key, required this.teacher});

  final Teacher teacher;

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  final StorageService _storage = StorageService();
  final SupabaseService _supabase = SupabaseService();
  List<Student> _allStudents = [];

  List<Student> get _teacherStudents =>
      _allStudents.where((s) => s.teacherName == widget.teacher.name).toList();

  @override
  void initState() {
    super.initState();
    // Listen to the central StorageService stream
    _storage.studentsStream.listen((students) {
      if (!mounted) return;
      setState(() {
        _allStudents = students;
      });
    });
    // Initial load
    _load();
  }

  Future<void> _load() async {
    final list = await _storage.loadStudents();
    setState(() {
      _allStudents = list;
    });
  }

  Future<void> _save() async {
    await _storage.saveStudents(_allStudents);
  }

  Future<void> _addStudentDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة طالب جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'رقم موبايل الطالب',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'الإيميل'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'كلمة السر'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                final String name = nameController.text.trim();
                final String phone = phoneController.text.trim();
                final String email = emailController.text.trim();
                final String password = passwordController.text.trim();
                if (name.isEmpty || email.isEmpty || password.isEmpty) return;
                final newStudent = Student(
                  id: 'stu_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  phone: phone,
                  teacherName: widget.teacher.name,
                  teacherPhone: widget.teacher.number,
                  email: email,
                  password: password,
                  points: 0,
                  attendance: const [],
                  prayers: [],
                  prayerDates: [],
                  memorization: [],
                );
                // Add student to UI immediately for responsiveness
                setState(() {
                  _allStudents.add(newStudent);
                });
                await _storage.addStudentAndUser(newStudent);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Scaffold(
        backgroundColor: backcolor,
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: _addStudentDialog,
              icon: Icon(Icons.add, size: 30, color: regsin),
            ),
          ],
          centerTitle: true,
          backgroundColor: backcolor,
          title: Text(
            'الأستاذ: ${widget.teacher.name}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: textcolor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'الاسم: ${widget.teacher.name}',
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'رقم الموبايل: ${widget.teacher.number}',
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Center(
                  child: Text(
                    'طلاب الأستاذ',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                Column(
                  children: _teacherStudents.map((s) {
                    return StudentCard(
                      key: ValueKey(s.id),
                      names: s.name,
                      numbers: s.phone,
                      onpressed: () {},
                      onEdit: () async {
                        // تعديل اسم/نقاط
                        final nameCtrl = TextEditingController(text: s.name);
                        final pointsCtrl = TextEditingController(
                          text: s.points.toString(),
                        );
                        await showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('تعديل بيانات الطالب'),
                              content: Directionality(
                                textDirection: TextDirection.rtl,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: nameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'اسم الطالب',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: pointsCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'النقاط',
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
                                TextButton(
                                  onPressed: () async {
                                    final name = nameCtrl.text.trim();
                                    final points =
                                        int.tryParse(pointsCtrl.text.trim()) ??
                                        s.points;
                                    final idx = _allStudents.indexWhere(
                                      (x) => x.id == s.id,
                                    );
                                    if (idx != -1 && name.isNotEmpty) {
                                      _allStudents[idx] = Student(
                                        id: s.id,
                                        name: name,
                                        phone: s.phone,
                                        teacherName: s.teacherName,
                                        teacherPhone: s.teacherPhone,
                                        email: s.email,
                                        password: s.password,
                                        points: points,
                                        attendance: s.attendance,
                                        prayers: s.prayers,
                                        prayerDates: s.prayerDates,
                                        memorization: s.memorization,
                                      );
                                      await _save();
                                    }
                                    if (mounted) Navigator.pop(context);
                                  },
                                  child: const Text('حفظ'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDelete: () async {
                        _allStudents.removeWhere((x) => x.id == s.id);
                        await _save();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
