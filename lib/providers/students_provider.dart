import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/services/storage_service.dart';

class StudentsNotifier extends AsyncNotifier<List<Student>> {
  final StorageService _storage = StorageService();
  StreamSubscription<List<Student>>? _subscription;

  @override
  Future<List<Student>> build() async {
    final students = await _storage.loadStudents();
    
    // Listen to storage updates
    _subscription?.cancel();
    _subscription = _storage.studentsStream.listen((updatedStudents) {
      state = AsyncValue.data(updatedStudents);
    });
    // ensure we cancel subscription when provider is disposed
    ref.onDispose(() {
      _subscription?.cancel();
    });
    
    return students;
  }
  

  Future<void> addStudent(Student student) async {
    state = const AsyncValue.loading();
    try {
      await _storage.addStudentAndUser(student);
      final refreshed = await _storage.loadStudents();
      state = AsyncValue.data(refreshed);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateStudent(Student student) async {
    state = const AsyncValue.loading();
    try {
      final current = state.value ?? await future;
      final updated = current
          .map((s) => s.id == student.id ? student : s)
          .toList();
      await _storage.saveStudents(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteStudent(String studentId) async {
    state = const AsyncValue.loading();
    try {
      final current = state.value ?? await future;
      final updated = current.where((s) => s.id != studentId).toList();
      await _storage.saveStudents(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateAttendance(String studentId, List<bool> attendance) async {
    state = const AsyncValue.loading();
    try {
      final current = state.value ?? await future;
      final updated = current.map((s) {
        if (s.id == studentId) {
          return Student(
            id: s.id,
            name: s.name,
            phone: s.phone,
            teacherId: s.teacherId,
            teacherName: s.teacherName,
            teacherPhone: s.teacherPhone,
            email: s.email,
            password: s.password,
            points: s.points,
            attendance: attendance,
            prayers: s.prayers,
            prayerDates: s.prayerDates,
            memorization: s.memorization,
            dailyPointsAdded: s.dailyPointsAdded,
            lastPointsDate: s.lastPointsDate,
          );
        }
        return s;
      }).toList();
      await _storage.saveStudents(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updatePoints(String studentId, int delta) async {
    state = const AsyncValue.loading();
    try {
      final current = state.value ?? await future;
      final updated = current.map((s) {
        if (s.id == studentId) {
          return Student(
            id: s.id,
            name: s.name,
            phone: s.phone,
            teacherId: s.teacherId,
            teacherName: s.teacherName,
            teacherPhone: s.teacherPhone,
            email: s.email,
            password: s.password,
            points: s.points + delta,
            attendance: s.attendance,
            prayers: s.prayers,
            prayerDates: s.prayerDates,
            memorization: s.memorization,
            dailyPointsAdded: s.dailyPointsAdded,
            lastPointsDate: s.lastPointsDate,
          );
        }
        return s;
      }).toList();
      await _storage.saveStudents(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Transfer a student to a new teacher
  /// Updates both teacher_id and teacher_name/teacher_phone
  Future<void> transferStudent(String studentId, String newTeacherId) async {
    state = const AsyncValue.loading();
    try {
      final current = state.value ?? await future;
      
      // Load teachers to get the new teacher's details
      final teachers = await _storage.loadTeachers();
      final newTeacher = teachers.firstWhere(
        (t) => t.id == newTeacherId,
        orElse: () => throw Exception('Teacher with ID $newTeacherId not found'),
      );
      
      final updated = current.map((s) {
        if (s.id == studentId) {
          return Student(
            id: s.id,
            name: s.name,
            phone: s.phone,
            teacherId: newTeacherId,
            teacherName: newTeacher.name,
            teacherPhone: newTeacher.number,
            email: s.email,
            password: s.password,
            points: s.points,
            attendance: s.attendance,
            prayers: s.prayers,
            prayerDates: s.prayerDates,
            memorization: s.memorization,
            dailyPointsAdded: s.dailyPointsAdded,
            lastPointsDate: s.lastPointsDate,
          );
        }
        return s;
      }).toList();
      
      await _storage.saveStudents(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final refreshed = await _storage.loadStudents();
      state = AsyncValue.data(refreshed);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final studentsProvider = AsyncNotifierProvider<StudentsNotifier, List<Student>>(
  StudentsNotifier.new,
);