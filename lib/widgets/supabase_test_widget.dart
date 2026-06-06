import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaman/services/supabase_service.dart';

class SupabaseTestWidget extends StatefulWidget {
  const SupabaseTestWidget({super.key});

  @override
  _SupabaseTestWidgetState createState() => _SupabaseTestWidgetState();
}

class _SupabaseTestWidgetState extends State<SupabaseTestWidget> {
  final SupabaseService _service = SupabaseService();
  String _testResults = 'لم يتم تشغيل أي اختبار بعد';

  void _runTests() async {
    setState(() {
      _testResults = 'جاري تشغيل الاختبارات...\n';
    });

    // اختبار تحميل الطلاب
    try {
      final students = await _service.loadStudents();
      setState(() {
        _testResults += '✅ تحميل الطلاب: تم تحميل ${students.length} طالب\n';
      });
    } catch (e) {
      setState(() {
        _testResults += '❌ تحميل الطلاب: خطأ - $e\n';
      });
    }

    // اختبار تحميل المعلمين
    try {
      final teachers = await _service.loadTeachers();
      setState(() {
        _testResults += '✅ تحميل المعلمين: تم تحميل ${teachers.length} معلم\n';
      });
    } catch (e) {
      setState(() {
        _testResults += '❌ تحميل المعلمين: خطأ - $e\n';
      });
    }

    // اختبار تحميل الرسائل
    try {
      final messages = await _service.loadMessages();
      setState(() {
        _testResults += '✅ تحميل الرسائل: تم تحميل ${messages.length} رسالة\n';
      });
    } catch (e) {
      setState(() {
        _testResults += '❌ تحميل الرسائل: خطأ - $e\n';
      });
    }

    // اختبار تسجيل الدخول
    try {
      final result = await _service.signIn('student@yaman.com', '123456');
      if (result != null) {
        setState(() {
          _testResults += '✅ تسجيل الدخول: نجح - دور: ${result['role']}\n';
        });
      } else {
        setState(() {
          _testResults += '❌ تسجيل الدخول: فشل\n';
        });
      }
    } catch (e) {
      setState(() {
        _testResults += '❌ تسجيل الدخول: خطأ - $e\n';
      });
    }

    // اختبار إنشاء حساب جديد
    try {
      final signUpResult = await _service.signUp('test${DateTime.now().millisecondsSinceEpoch}@yaman.com', '123456', 'student', name: 'Test Student', phone: '123456789', teacherName: 'Test Teacher', teacherPhone: '987654321');
      if (signUpResult != null) {
        setState(() {
          _testResults += '✅ إنشاء حساب: نجح - دور: ${signUpResult['role']}\n';
        });
      } else {
        setState(() {
          _testResults += '❌ إنشاء حساب: فشل\n';
        });
      }
    } catch (e) {
      setState(() {
        _testResults += '❌ إنشاء حساب: خطأ - $e\n';
      });
    }

    // اختبار حالة تسجيل الدخول
    try {
      final isSignedIn = await _service.isUserSignedIn();
      setState(() {
        _testResults += '✅ حالة تسجيل الدخول: ${isSignedIn ? 'متصل' : 'غير متصل'}\n';
      });
    } catch (e) {
      setState(() {
        _testResults += '❌ حالة تسجيل الدخول: خطأ - $e\n';
      });
    }

    // اختبار الإضافة المباشرة (تشخيص دقيق)
    try {
      final dummyId = 'test_direct_${DateTime.now().millisecondsSinceEpoch}';
      final dummyData = {
        'id': dummyId,
        'name': 'Dingnostic Student',
        'email': '$dummyId@test.com',
        'password': 'password',
        'points': 0,
        'teacherName': 'Test Teacher', // Check case sensitivity
        'teacherPhone': '123456',
        // Minimal fields
      };
      
      // Accessing client directly to bypass Service wrapper and see RAW error
      await Supabase.instance.client.from('students').insert(dummyData);
      
      setState(() {
        _testResults += '✅ الإضافة المباشرة (Direct Insert): نجح!\n';
      });
    } catch (e) {
      setState(() {
         // Print FULL error
        _testResults += '❌ الإضافة المباشرة فشلت (RAW ERROR): $e\n';
      });
    }

    setState(() {
      _testResults += '\nتم الانتهاء من الاختبارات!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار Supabase'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _runTests,
              child: const Text('تشغيل اختبارات Supabase'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _testResults,
                  style: const TextStyle(fontSize: 14, fontFamily: 'Courier'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
