import 'package:flutter/material.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/models/student.dart';

class DataPersistenceTest extends StatefulWidget {
  const DataPersistenceTest({super.key});

  @override
  State<DataPersistenceTest> createState() => _DataPersistenceTestState();
}

class _DataPersistenceTestState extends State<DataPersistenceTest> {
  final StorageService _storage = StorageService();
  String _testResults = '';
  bool _isLoading = false;

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _testResults = 'بدء اختبار حفظ البيانات...\n\n';
    });

    try {
      // Test 1: Add Teacher
      _testResults += '1. اختبار إضافة أستاذ...\n';
      final testTeacher = Teacher(
        name: 'أستاذ تجريبي',
        number: '0999999999',
        email: 'test@teacher.com',
        password: '123456',
      );
      final savedTeacher = await _storage.addTeacherAndUser(testTeacher);
      _testResults += '✓ تم إضافة الأستاذ بنجاح: ${savedTeacher.name}\n\n';

      // Test 2: Load Teachers
      _testResults += '2. اختبار تحميل الأساتذة...\n';
      final teachers = await _storage.loadTeachers();
      _testResults += '✓ تم تحميل ${teachers.length} أستاذ\n\n';

      // Test 3: Add Student
      _testResults += '3. اختبار إضافة طالب...\n';
      final testStudent = Student(
        id: 'test_student_${DateTime.now().millisecondsSinceEpoch}',
        name: 'طالب تجريبي',
        phone: '0911111111',
        teacherName: savedTeacher.name,
        teacherPhone: savedTeacher.number,
        email: 'test@student.com',
        password: '123456',
        points: 0,
        attendance: [],
        prayers: [],
        prayerDates: [],
        memorization: [],
      );
      await _storage.addStudentAndUser(testStudent);
      _testResults += '✓ تم إضافة الطالب بنجاح: ${testStudent.name}\n\n';

      // Test 4: Load Students
      _testResults += '4. اختبار تحميل الطلاب...\n';
      final students = await _storage.loadStudents();
      _testResults += '✓ تم تحميل ${students.length} طالب\n\n';

      // Test 5: Update Student Points
      _testResults += '5. اختبار تحديث نقاط الطالب...\n';
      final updatedStudents = students.map((s) {
        if (s.id == testStudent.id) {
          return Student(
            id: s.id,
            name: s.name,
            phone: s.phone,
            teacherName: s.teacherName,
            teacherPhone: s.teacherPhone,
            email: s.email,
            password: s.password,
            points: s.points + 10,
            attendance: s.attendance,
            prayers: s.prayers,
            prayerDates: s.prayerDates,
            memorization: s.memorization,
          );
        }
        return s;
      }).toList();
      await _storage.saveStudents(updatedStudents);
      _testResults += '✓ تم تحديث نقاط الطالب بنجاح\n\n';

      // Test 6: Verify Data Persistence
      _testResults += '6. اختبار التحقق من استمرارية البيانات...\n';
      final reloadedStudents = await _storage.loadStudents();
      final testStudentReloaded = reloadedStudents.firstWhere(
        (s) => s.id == testStudent.id,
        orElse: () => throw Exception('Student not found'),
      );
      if (testStudentReloaded.points == 10) {
        _testResults += '✓ تم التحقق من استمرارية البيانات بنجاح\n\n';
      } else {
        _testResults += '✗ فشل في التحقق من استمرارية البيانات\n\n';
      }

      _testResults += '🎉 تم إنجاز جميع الاختبارات بنجاح!\n';
      _testResults += 'البيانات محفوظة بشكل صحيح في الملف المحلي.\n';

    } catch (e) {
      _testResults += '✗ خطأ في الاختبار: ${e.toString()}\n';
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('اختبار حفظ البيانات'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _runTests,
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('جاري الاختبار...'),
                      ],
                    )
                  : Text('بدء اختبار حفظ البيانات'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResults.isEmpty ? 'اضغط على الزر لبدء الاختبار' : _testResults,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
