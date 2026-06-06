import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/services/storage_service.dart';

class TeachersNotifier extends AsyncNotifier<List<Teacher>> {
  final StorageService _storage = StorageService();
  StreamSubscription<List<Teacher>>? _subscription;

  @override
  Future<List<Teacher>> build() async {
    final teachers = await _storage.loadTeachers();
    
    // Listen to storage updates
    _subscription?.cancel();
    _subscription = _storage.teachersStream.listen((updatedTeachers) {
      state = AsyncValue.data(updatedTeachers);
    });
    ref.onDispose(() {
      _subscription?.cancel();
    });

    return teachers;
  }
  

  Future<void> addTeacher(Teacher teacher) async {
    state = const AsyncValue.loading();
    try {
      await _storage.addTeacherAndUser(teacher);
      final refreshed = await _storage.loadTeachers();
      state = AsyncValue.data(refreshed);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateTeacher(Teacher teacher) async {
    state = const AsyncValue.loading();
    try {
      final current = state.value ?? await future;
      final updated = current
          .map((t) => t.id == teacher.id ? teacher : t)
          .toList();
      await _storage.saveTeachers(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteTeacher(String teacherId) async {
    state = const AsyncValue.loading();
    try {
      final current = state.value ?? await future;
      final updated = current.where((t) => t.id != teacherId).toList();
      await _storage.saveTeachers(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final refreshed = await _storage.loadTeachers();
      state = AsyncValue.data(refreshed);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final teachersProvider = AsyncNotifierProvider<TeachersNotifier, List<Teacher>>(
  TeachersNotifier.new,
);