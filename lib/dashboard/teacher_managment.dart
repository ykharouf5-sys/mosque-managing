import 'package:flutter/material.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/widget/teachercards.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/dashboard/teacher_detail.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/widget/animated_background.dart';
import 'package:yaman/Screen/Chat_screen.dart';
import 'package:yaman/services/connectivity_service.dart';
import 'package:yaman/utils/responsive_helper.dart';



class Tmanagment extends StatefulWidget {
  const Tmanagment({super.key});

  @override
  State<Tmanagment> createState() => _TmanagmentState();
}

class _TmanagmentState extends State<Tmanagment> {
  //   // List<Widget> teacher = [];
  //   // List<Widget> za3tar = [];
  final StorageService _storage = StorageService();
  final SupabaseService _supabase = SupabaseService();
  List<Teacher> teachers = [];
  List<Student> students = [];
  bool _isSyncing = false;
  String? _syncMessage;
  bool _isLoading = true;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    // Let the stream handle loading and updates
    _setupRealtimeSync();
  }

  void _setupRealtimeSync() {
    // Subscribe to the StorageService stream, which is the single source of truth
    _storage.teachersStream.listen((updatedTeachers) {
      if (!mounted) return;
      setState(() {
        teachers = updatedTeachers;
        _isLoading = false; // Data has arrived
      });
    });

    // Initial load
    _loadTeachers();
    _loadStudents();
  }

  Future<void> _loadTeachers() async {
    // This will load from cache first, then sync from cloud in the background
    // The stream listener will handle the UI update.
    final initialTeachers = await _storage.loadTeachers();
    setState(() {
      teachers = initialTeachers;
      _isLoading = false;
    });
  }

  Future<void> _loadStudents() async {
    final loaded = await _storage.loadStudents();
    setState(() {
      students = loaded;
    });
  }

  Future<void> _saveTeachers() async {
    await _storage.saveTeachers(teachers);
  }

  Future<void> _loadMoreTeachers() async {
    final more = await _supabase.loadTeachers(
      limit: _pageSize,
      offset: teachers.length,
    );
    if (more.isNotEmpty) {
      final combined = [...teachers, ...more];
      await _storage.saveTeachers(combined);
      setState(() {
        teachers = combined;
      });
    }
  }
  //   Future<String> _getFilePath() async {
  //     final dir = await getApplicationDocumentsDirectory();
  //     return '${dir.path}/teacher.json';
  //   }

  //   Future<void> saveTeachers(List<Map<String, dynamic>> teachers) async {
  //     final filePath = await _getFilePath();
  //     final file = File(filePath);
  //     String jsonString = jsonEncode(teachers);
  //     await file.writeAsString(jsonString);
  //   }

  //   Future<List<Map<String, dynamic>>> loadTeachers() async {
  //     final filePath = await _getFilePath();
  //     final file = File(filePath);

  //     if (await file.exists()) {
  //       String jsonString = await file.readAsString();
  //       List decoded = jsonDecode(jsonString);
  //       return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  //     } else {
  //       return []; // إذا ما في ملف لسا
  //     }
  //   }
  Future<void> _addTeacherDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController numberController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('إضافة أستاذ جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(labelText: 'الاسم'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: numberController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(labelText: 'رقم الموبايل'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(labelText: 'الإيميل'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(labelText: 'كلمة السر'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
            TextButton(
              onPressed: _isSyncing
                  ? null
                  : () async {
                      final String name = nameController.text.trim();
                      final String number = numberController.text.trim();
                      final String email = emailController.text.trim();
                      final String password = passwordController.text.trim();
                      if (name.isNotEmpty &&
                          number.isNotEmpty &&
                          email.isNotEmpty &&
                          password.isNotEmpty) {
                        setState(() {
                          _isSyncing = true;
                          _syncMessage = 'جاري حفظ الأستاذ...';
                        });

                        try {
                          final newTeacher = Teacher(
                            name: name,
                            number: number,
                            email: email,
                            password: password,
                          );
                          final savedTeacher = await _storage.addTeacherAndUser(
                            newTeacher,
                          );

                          // Update UI status immediately
                          setState(() {
                            // No need to add manually, stream handles it
                            if (savedTeacher.id?.startsWith('temp_') == true) {
                                _syncMessage = 'تم الحفظ محلياً (Offline). سيتم المزامنة لاحقاً.';
                            } else {
                                _syncMessage = 'تم حفظ الأستاذ بنجاح!';
                            }
                            _isSyncing = false;
                          });

                          // Clear message after 2 seconds
                          if (mounted) {
                            Future.delayed(Duration(seconds: 2), () {
                              if (mounted) {
                                setState(() {
                                  _syncMessage = null;
                                });
                              }
                            });
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          print('Error adding teacher: $e');

                          // Show error in dialog or snackbar
                          setState(() {
                            // Remove "Exception: " prefix if present
                            final msg = e.toString().replaceAll(
                              'Exception: ',
                              '',
                            );
                            _syncMessage = msg;
                            _isSyncing = false;
                          });

                          // Clear message after 3 seconds
                          Future.delayed(Duration(seconds: 3), () {
                            if (mounted) {
                              setState(() {
                                _syncMessage = null;
                              });
                            }
                          });
                        }
                      }
                    },
              child: _isSyncing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('إضافة'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editTeacherDialog(int index) async {
    final Teacher teacher = teachers[index];
    final TextEditingController nameController = TextEditingController(
      text: teacher.name,
    );
    final TextEditingController numberController = TextEditingController(
      text: teacher.number,
    );
    final TextEditingController emailController = TextEditingController(
      text: teacher.email,
    );
    final TextEditingController passwordController = TextEditingController(
      text: teacher.password,
    );
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تعديل بيانات الأستاذ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: numberController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(labelText: 'رقم الموبايل'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(labelText: 'الإيميل'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(labelText: 'كلمة السر'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
            TextButton(
              onPressed: _isSyncing
                  ? null
                  : () async {
                      final String name = nameController.text.trim();
                      final String number = numberController.text.trim();
                      final String email = emailController.text.trim();
                      final String password = passwordController.text.trim();

                      // التحقق من أن الحقول المطلوبة ليست فارغة
                      if (name.isEmpty || number.isEmpty || email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يرجى ملء الاسم والرقم والإيميل'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setState(() {
                        _isSyncing = true;
                        _syncMessage = 'جاري تحديث بيانات الأستاذ...';
                      });

                      // إغلاق مربع الحوار فوراً لتجربة مستخدم أفضل
                      Navigator.pop(context);

                      try {
                        // 1. إنشاء كائن الأستاذ المحدث للجدول
                        final updatedTeacherForDb = teacher.copyWith(
                          name: name,
                          number: number,
                          email: email,
                          password: password.isNotEmpty ? password : teacher.password,
                        );

                        // 2. تحديث سجل الأستاذ في قاعدة البيانات المحلية والسحابية
                        await _storage.updateTeacher(updatedTeacherForDb);

                        // 3. تحديث بيانات المصادقة (الإيميل/كلمة المرور) عبر الدالة السحابية
                        bool authUpdateNeeded = email != teacher.email || password.isNotEmpty;
                        bool isRealAccount = teacher.id != null && !teacher.id!.startsWith('temp_');

                        if (authUpdateNeeded) {
                          if (isRealAccount) {
                            try {
                              await _supabase.updateAuthUserById(
                                teacher.id!,
                                email: email,
                                password: password.isNotEmpty ? password : null,
                              );
                            } catch (authError) {
                              print('⚠️ Auth update failed for teacher but data was saved: $authError');
                              if (mounted) {
                                setState(() {
                                  _syncMessage = 'تم حفظ البيانات مع تعذر تحديث بيانات الدخول';
                                });
                              }
                            }
                          } else {
                            print('ℹ️ Skipping Auth update for offline teacher (temp_ ID)');
                          }
                        }

                        // 4. تحديث واجهة المستخدم بالبيانات الجديدة
                        if (mounted) {
                          setState(() {
                            teachers[index] = updatedTeacherForDb;
                            _syncMessage = 'تم تحديث بيانات الأستاذ بنجاح!';
                          });
                        }
                      } catch (e) {
                        print('Error updating teacher: $e');
                        if (mounted) {
                          setState(() {
                            _syncMessage =
                                'خطأ: ${e.toString().replaceAll("Exception: ", "")}';
                          });
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isSyncing = false);
                          // إخفاء رسالة الحالة بعد 3 ثوانٍ
                          Future.delayed(const Duration(seconds: 3), () {
                            if (mounted) setState(() => _syncMessage = null);
                          });
                        }
                      }
                    },
              child: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTeacher(int index) async {
    final Teacher teacher = teachers[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف الأستاذ ${teacher.name}؟\n\n'
          '⚠️ تنبيه: سيتم حذف جميع الطلاب المرتبطين به تلقائياً من قاعدة البيانات (CASCADE DELETE).',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        setState(() {
          _isSyncing = true;
          _syncMessage = 'جاري حذف الأستاذ...';
        });

        if (teacher.id != null) {
          // Delete the teacher - CASCADE DELETE will automatically remove associated students
          await _storage.deleteTeacher(teacher.id!);

          // Delete the associated user from local db
          await _storage.deleteTeacherUser(teacher.id!);

          // Update UI - remove teacher and refresh students list
          setState(() {
            teachers.removeWhere((t) => t.id == teacher.id);
            // Reload students to reflect CASCADE DELETE
            _loadStudents();
            _syncMessage = 'تم حذف الأستاذ وطلابه بنجاح!';
            _isSyncing = false;
          });
        } else {
          throw Exception('معرف الأستاذ غير موجود');
        }

        // Clear message after 2 seconds
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _syncMessage = null;
            });
          }
        });
      } catch (e) {
        print('Error deleting teacher: $e');
        setState(() {
          _syncMessage = 'خطأ في حذف الأستاذ: ${e.toString()}';
          _isSyncing = false;
        });

        // Clear message after 3 seconds
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _syncMessage = null;
            });
          }
        });
      }
    }
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
          iconTheme: IconThemeData(color: Colors.white),
          backgroundColor: backcolor,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "إدارة الأساتذة",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.fontSize(22),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
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
          actions: [
            IconButton(
              onPressed: () async {
                setState(() {
                  _isSyncing = true;
                  _syncMessage = 'جاري مزامنة البيانات...';
                });

                try {
                  // 1. Force Push Local -> Cloud
                  setState(() {
                    _syncMessage = 'جاري رفع البيانات للسحابة...';
                  });
                  await _storage.forceSync(
                    syncTeachers: true,
                    syncStudents: false,
                    syncMessages: false,
                  );

                  // 2. Pull Cloud -> Local
                  setState(() {
                    _syncMessage = 'جاري استقبال التحديثات...';
                  });
                  final cloudTeachers = await _supabase.loadTeachers();

                  if (cloudTeachers.isNotEmpty) {
                    setState(() {
                      teachers = cloudTeachers;
                      _syncMessage =
                          'تمت المزامنة الكاملة (${cloudTeachers.length} أستاذ) بنجاح!';
                      _isSyncing = false;
                    });
                    await _storage.saveTeachers(cloudTeachers);
                  } else {
                    setState(() {
                      _syncMessage = 'المزامنة ناجحة (لا توجد بيانات جديدة)';
                      _isSyncing = false;
                    });
                  }
                } catch (e) {
                  final errorStr = e.toString().toLowerCase();
                  bool isNetworkError =
                      errorStr.contains('network') ||
                      errorStr.contains('socket') ||
                      errorStr.contains('connection') ||
                      errorStr.contains('مشكلة في الاتصال');

                  setState(() {
                    if (isNetworkError) {
                      _syncMessage =
                          'لا يوجد إنترنت. تم حفظ البيانات محلياً بأمان ✅';
                      // Optional: Add a yellow warning icon or similar if we had UI for it
                    } else {
                      _syncMessage = 'تنبيه: ${e.toString()}';
                    }
                    _isSyncing = false;
                  });
                }

                // Clear message after 3 seconds
                Future.delayed(Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() {
                      _syncMessage = null;
                    });
                  }
                });
              },
              icon: Icon(Icons.sync, size: 27, color: Colors.white),
            ),
            IconButton(
              onPressed: () {
                // This button from the dashboard should open a list of chats,
                // but for now, let's assume it's for general purpose or a placeholder.
                // To make it functional, we need a screen to list all teachers/students to chat with.
                // For demonstration, let's navigate to a chat screen without specific users,
                // which will rely on the improved ChatScreen logic to handle it.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      studentId: '', // No specific student
                      studentName: '',
                      teacherId: '', // No specific teacher
                      teacherName: 'محادثات', // Title for the screen
                      isTeacher: false, // Assuming admin is not a teacher
                    ),
                  ),
                );
              },
              icon: Icon(Icons.forum, size: 27, color: Colors.white),
            ),
          ],
          centerTitle: true,
        ),
        body: Stack(
          children: [
            const AnimatedBackground(),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    SizedBox(
                      height: responsive.width(18),
                      width: responsive.width(18),
                      child: Image.asset("assets/image/logomosque.png"),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _addTeacherDialog,
                          icon: Icon(Icons.add, size: 30, color: regsin),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "إدارة الأساتذة",
                          style: TextStyle(
                            fontSize: responsive.fontSize(24),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.manage_accounts,
                          color: Colors.white,
                          size: 30,
                        ),
                      ],
                    ),
                    Text(
                      'قائمة الأساتذة المسجلين',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    if (_syncMessage != null)
                      Container(
                        padding: EdgeInsets.all(8),
                        margin: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _syncMessage!.contains('خطأ')
                              ? Colors.red.withValues(alpha: 0.8)
                              : _syncMessage!.contains('Offline')
                                  ? Colors.orange.withValues(alpha: 0.9)
                                  : Colors.green.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (_isSyncing)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              Icon(
                                _syncMessage!.contains('خطأ')
                                    ? Icons.error
                                    : Icons.check_circle,
                                color: Colors.white,
                                size: 16,
                              ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _syncMessage!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 10),
                    // هنا بنبني الكروت بناءً على الـ teachers List
                    if (_isLoading)
                      Column(
                        children: List.generate(
                          6,
                          (i) => Container(
                            height: 84,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: textcolor.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: teachers.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final Teacher teacher = entry.value;
                          return CardTeacher(
                            key: ValueKey(
                              teacher.id ?? teacher.email,
                            ), // Use ID for better key
                            name: teacher.name,
                            number: teacher.number,
                            studentCount: students
                                .where((s) => s.teacherName == teacher.name)
                                .length,
                            onpressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TeacherDetailScreen(teacher: teacher),
                                ),
                              );
                            },
                            // Add Edit and Delete buttons
                            onEdit: () => _editTeacherDialog(index),
                            onDelete: () => _deleteTeacher(index),
                          );
                        }).toList(),
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
