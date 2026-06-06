import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/models/message.dart';
import 'package:yaman/models/chat_message.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/services/connectivity_service.dart';
import 'package:yaman/services/sync_queue_service.dart';

class StorageService {
  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final SupabaseService _supabase = SupabaseService();
  static bool _infraInitialized = false;
  static const String dbFileName = 'db.json';
  Map<String, dynamic>? _dbCache;
  List<Teacher>? _teachersCache;
  List<Student>? _studentsCache;
  List<Message>? _messagesCache;
  List<ChatMessage>? _chatMessagesCache;

  // Chat Caching
  final Map<String, List<ChatMessage>> _conversationCache = {};
  final Map<String, DateTime> _conversationCacheTimestamps = {};
  static const Duration _cacheTTL = Duration(minutes: 5);
  final Map<String, Map<String, dynamic>> _metadataCache = {}; // Conversation Metadata

  // Stream controllers for real-time updates
  final _teachersController = StreamController<List<Teacher>>.broadcast();
  final _studentsController = StreamController<List<Student>>.broadcast();

  Stream<List<Teacher>> get teachersStream => _teachersController.stream;
  Stream<List<Student>> get studentsStream => _studentsController.stream;

  // To prevent race conditions during deletion
  final Set<String> _deletingTeacherIds = {};
  final Set<String> _deletingStudentIds = {};

  void clearTeachersCache() {
    _teachersCache = null;
  }

  void clearStudentsCache() {
    _studentsCache = null;
  }

  StreamSubscription<List<Teacher>>? _teachersSubscription;
  StreamSubscription<List<Student>>? _studentsSubscription;
  StreamSubscription<List<ChatMessage>>? _chatMessagesSubscription;

  get messagesStream => null;

  get chatMessagesStream => null;

  void _ensureInfra() {
    if (_infraInitialized) return;
    _infraInitialized = true;
    ConnectivityService().initialize();
    SyncQueueService().initialize();
    _setupRealtimeSubscriptions();
  }

  void _setupRealtimeSubscriptions() {
    // Subscribe to real-time updates from Supabase
    // Subscribe to real-time updates from Supabase
    _teachersSubscription?.cancel();
    _teachersSubscription = _supabase.subscribeToTeachers().listen((
      cloudTeachers,
    ) async {
      try {
        final filteredCloudTeachers = cloudTeachers.where((t) {
          return t.id != null && !_deletingTeacherIds.contains(t.id);
        }).toList();

        if (filteredCloudTeachers.isEmpty && cloudTeachers.isNotEmpty) {
          return; 
        }

        // SAFE MERGE: Update local with cloud, but keep local-only items
        final db = await _readDb(forceRefresh: true);
        final currentLocalTeachers = (db['teachers'] as List)
            .map((e) => Teacher.fromJson(e))
            .toList();
        
        final localMap = {for (var t in currentLocalTeachers) t.id: t};
        final cloudMap = {for (var t in filteredCloudTeachers) t.id: t};
        
        // Cloud overwrites local if ID matches
        localMap.addAll(cloudMap);
        
        final mergedList = localMap.values.toList();

        db['teachers'] = mergedList.map((t) => t.toJson()).toList();
        await _writeDb(db);
        _teachersCache = mergedList;
        _teachersController.add(mergedList);
        print(
          '🔄 Real-time: Teachers merged (${mergedList.length} local total)',
        );
      } catch (e) {
        print('Error in real-time teachers subscription: $e');
      }
    });

    _studentsSubscription?.cancel();
    _studentsSubscription = _supabase.subscribeToStudents().listen((
      cloudStudents,
    ) async {
      try {
        final filteredCloudStudents = cloudStudents.where((s) {
          return !_deletingStudentIds.contains(s.id);
        }).toList();

        if (filteredCloudStudents.isEmpty && cloudStudents.isNotEmpty) {
          return; 
        }

        // SAFE MERGE: Update local with cloud, but keep local-only items
        final db = await _readDb(forceRefresh: true);
        final currentLocalStudents = (db['students'] as List)
            .map((e) => Student.fromJson(e))
            .toList();

        final localMap = {for (var s in currentLocalStudents) s.id: s};
        final cloudMap = {for (var s in filteredCloudStudents) s.id: s};

        // Cloud overwrites local if ID matches
        localMap.addAll(cloudMap);

        final mergedList = localMap.values.toList();

        db['students'] = mergedList.map((s) => s.toJson()).toList();
        await _writeDb(db);
        _studentsCache = mergedList;
        _studentsController.add(mergedList);
        print(
          '🔄 Real-time: Students merged (${mergedList.length} local total)',
        );
      } catch (e) {
        print('Error in real-time students subscription: $e');
      }
    });

    _chatMessagesSubscription?.cancel();
    _chatMessagesSubscription = _supabase
        .subscribeToChatMessages(studentId: '')  // Listen to ALL chat messages
        .listen((cloudChatMessages) async {
          try {
            if (cloudChatMessages.isNotEmpty) {
              print('📨 Real-time: Received ${cloudChatMessages.length} chat messages from cloud');
              
              final db = await _readDb(forceRefresh: true);
              final currentLocalMessages = (db['chat_messages'] as List)
                  .map((e) => ChatMessage.fromJson(e))
                  .toList();
                  
              final localMap = <String, ChatMessage>{for (var m in currentLocalMessages) m.id: m};
              final cloudMap = <String, ChatMessage>{for (var m in cloudChatMessages) m.id: m};
              
              // Merge: Cloud messages overwrite local
              localMap.addAll(cloudMap);
              final mergedList = localMap.values.toList();
              
              db['chat_messages'] = mergedList
                  .map((m) => m.toJson())
                  .toList();
              await _writeDb(db);
              _chatMessagesCache = mergedList;
              
              // Update conversation caches
              for (var msg in cloudChatMessages) {
                if (_conversationCache.containsKey(msg.conversationId)) {
                  final cachedConv = _conversationCache[msg.conversationId]!;
                  final existingIndex = cachedConv.indexWhere((m) => m.id == msg.id);
                  if (existingIndex != -1) {
                    cachedConv[existingIndex] = msg;
                  } else {
                    cachedConv.add(msg);
                  }
                  _conversationCacheTimestamps[msg.conversationId] = DateTime.now();
                }
              }
              
              print(
                '✅ Real-time: ChatMessages merged (${mergedList.length} total, ${cloudChatMessages.length} new)',
              );
            }
          } catch (e) {
            print('❌ Error in real-time chat_messages subscription: $e');
          }
        });
  }

  void dispose() {
    _teachersSubscription?.cancel();
    _studentsSubscription?.cancel();
    _chatMessagesSubscription?.cancel();
    _teachersController.close();
    _studentsController.close();
  }

  Future<File> _getDbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$dbFileName');
    if (!await file.exists()) {
      await file.writeAsString(
        jsonEncode({
          'teachers': [],
          'students': [],
          'messages': [],
          'chat_messages': [],
          'users': [
            {'email': 'admin@yaman.com', 'password': 'admin', 'role': 'admin'},
            {
              'email': 'student@yaman',
              'password': '123456',
              'role': 'student',
              'studentId': 'stu_1',
            },
          ],
        }),
      );
    }
    return file;
  }

  Future<Map<String, dynamic>> _readDb({bool forceRefresh = false}) async {
    if (_dbCache != null && !forceRefresh) return _dbCache!;
    final file = await _getDbFile();
    try {
      final raw = await file.readAsString();
      _dbCache = jsonDecode(raw) as Map<String, dynamic>;

      // Auto-migration for admin credentials
      if (_dbCache!['users'] != null) {
        final users = (_dbCache!['users'] as List).cast<Map<String, dynamic>>();
        for (var i = 0; i < users.length; i++) {
          if (users[i]['role'] == 'admin' && users[i]['email'] == 'admin@yaman') {
             print('🛠️ Migrating admin email to admin@yaman.com');
             users[i]['email'] = 'admin@yaman.com';
             users[i]['password'] = 'admin';
             _writeDb(_dbCache!); // Save updated DB
          }
        }
      }

      // Ensure all keys exist to prevent crashes
      if (_dbCache!['teachers'] == null) _dbCache!['teachers'] = [];
      if (_dbCache!['students'] == null) _dbCache!['students'] = [];
      if (_dbCache!['messages'] == null) _dbCache!['messages'] = [];
      if (_dbCache!['chat_messages'] == null) _dbCache!['chat_messages'] = [];
      if (_dbCache!['users'] == null) _dbCache!['users'] = [];

      return _dbCache!;
    } catch (e) {
      print('Error reading from local storage: $e');
      _dbCache = {
        'teachers': [],
        'students': [],
        'messages': [],
        'chat_messages': [],
        'users': [
          {'email': 'admin@yaman.com', 'password': 'admin', 'role': 'admin'},
          {
            'email': 'student@yaman',
            'password': '123456',
            'role': 'student',
            'studentId': 'stu_1',
          },
        ],
      };
      return _dbCache!;
    }
  }

  Timer? _writeDebouncer;
  static const Duration _writeDelay = Duration(milliseconds: 500);

  Future<void> _writeDb(Map<String, dynamic> data) async {
    _dbCache = data;
    // Clear related caches when data changes
    _teachersCache = null;
    _studentsCache = null;
    _messagesCache = null;
    _chatMessagesCache = null;

    if (_writeDebouncer?.isActive ?? false) _writeDebouncer!.cancel();
    
    _writeDebouncer = Timer(_writeDelay, () async {
      try {
        final file = await _getDbFile();
        await file.writeAsString(jsonEncode(data));
        // print('💾 Data saved successfully to local storage (Debounced)');
      } catch (e) {
        print('Error writing to local storage: $e');
      }
    });

    return Future.value();
  }

  // Teachers
  // Teachers - Local First Strategy
  Future<List<Teacher>> loadTeachers({bool forceRefresh = false}) async {
    _ensureInfra();

    // 1. Load Local
    final db = await _readDb(forceRefresh: forceRefresh);
    final list = (db['teachers'] as List).cast<Map<String, dynamic>>();
    var localTeachers = list.map((e) => Teacher.fromJson(e)).toList();

    final uniqueMap = {for (var t in localTeachers) t.email: t};
    localTeachers = uniqueMap.values.toList();

    // 2. If we have local data, return it immediately (FAST)
    if (localTeachers.isNotEmpty && !forceRefresh) {
      _teachersCache = localTeachers;
      // Trigger background sync to update stream later
      _syncTeachersFromCloud();
      print(
        '🚀 Fast Load: Returning ${localTeachers.length} local teachers. Syncing in background...',
      );
      return localTeachers;
    }

    // 3. If Local empty or Force Refresh, Blocking Cloud Sync
    try {
      final online = await ConnectivityService().isOnline;
      if (online) {
        print('☁️ Fetching teachers from cloud (Blocking)...');
        final cloudTeachers = await _supabase.loadTeachers();

        if (cloudTeachers.isNotEmpty) {
           // SAFE MERGE: Update local with cloud, but keep local-only items (offline created)
           // We strictly use ID as the key to prevent duplicates.
           
           final db = await _readDb();
           final currentLocalList = (db['teachers'] as List).cast<Map<String, dynamic>>()
               .map((e) => Teacher.fromJson(e)).toList();

           // 1. Map Local Teachers by ID
           final localMap = {for (var t in currentLocalList) t.id: t};
           
           // 2. Map Cloud Teachers by ID
           final cloudMap = {for (var t in cloudTeachers) t.id: t};
           
           // 3. Cloud overwrites Local for matching IDs. 
           // New Cloud items are added. 
           // Local-only items are preserved (unless we have a way to know they were deleted).
           localMap.addAll(cloudMap);
           
           final merged = localMap.values.toList();

          db['teachers'] = merged.map((t) => t.toJson()).toList();
          await _writeDb(db);

          _teachersCache = merged;
          _teachersController.add(merged);
          print('✅ Blocking Sync: Loaded ${merged.length} teachers (Merged)');
          return merged;
        }
      }
    } catch (e) {
      print('⚠️ Blocking Sync failed: $e');
    }

    // Final Fallback
    _teachersCache = localTeachers;
    return localTeachers;
  }

  /// Resolve a teacher by name from local or cloud
  Future<Teacher?> getTeacherByName(String name) async {
    final teachers = await loadTeachers();
    try {
      return teachers.firstWhere((t) => t.name.trim() == name.trim());
    } catch (_) {
      return null;
    }
  }

  /// Get a student by ID
  Future<Student?> getStudentById(String id) async {
    final students = await loadStudents();
    try {
      return students.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // Flag to pause realtime sync during critical delete operations
  bool _pauseRealtimeSync = false;

  // Background sync for teachers (non-blocking)
  void _syncTeachersFromCloud() {
    if (_pauseRealtimeSync) {
      print('⏸️ Background sync paused (delete in progress)');
      return;
    }

    _supabase
        .loadTeachers()
        .then((cloudTeachers) async {
          if (_pauseRealtimeSync) return; // Double-check

          try {
            if (cloudTeachers.isNotEmpty && _teachersCache != null) {
              // Standardize on ID-based merging
              final localMap = {for (var t in _teachersCache!) t.id: t};
              final cloudMap = {for (var t in cloudTeachers) t.id: t};

              // Cloud overwrites local (Cloud is Truth)
              // Local-only items are preserved
              localMap.addAll(cloudMap);
              
              final merged = localMap.values.toList();

              final updatedDb = await _readDb(forceRefresh: true);
              updatedDb['teachers'] = merged.map((t) => t.toJson()).toList();
              await _writeDb(updatedDb);
              _teachersCache = merged;
              _teachersController.add(merged);
              print('🔄 Background sync: Teachers updated from cloud (Merged IDs)');
            }
          } catch (e) {
            print('Error in background sync for teachers: $e');
          }
        })
        .catchError((e) {
          print('Error in background sync for teachers: $e');
        });
  }

  Future<void> saveTeachers(List<Teacher> teachers) async {
    _ensureInfra();
    try {
      // 1. Optimistic Update: Save to local
      final db = await _readDb();
      db['teachers'] = teachers.map((t) => t.toJson()).toList();
      await _writeDb(db);

      _teachersCache = teachers;
      _teachersController.add(teachers);
      print('💾 Local save complete (${teachers.length} teachers)');

      // 2. Cloud Sync
      try {
        final online = await ConnectivityService().isOnline;
        if (online) {
          await _supabase.upsertTeachers(teachers);
          print('☁️ Cloud save complete');
        } else {
          print('⚠️ Offline: Queueing save for later');
          await SyncQueueService().addOperation('save_teachers', {
            'list': teachers.map((t) => t.toJson()).toList(),
          });
        }
      } catch (e) {
        print('❌ Cloud save failed: $e');
        await SyncQueueService().addOperation('save_teachers', {
          'list': teachers.map((t) => t.toJson()).toList(),
        });
      }
    } catch (e) {
      print('Error saving teachers: $e');
      rethrow;
    }
  }

  Future<void> updateTeacher(Teacher teacher) async {
    _ensureInfra();
    try {
      // 1. Optimistic Update: Save to local immediately
      final db = await _readDb();
      final teachers = (db['teachers'] as List).cast<Map<String, dynamic>>();
      final index = teachers.indexWhere((t) => t['id'] == teacher.id);

      if (index != -1) {
        teachers[index] = teacher.toJson();
        db['teachers'] = teachers;
        await _writeDb(db);

        // Update cache and stream
        _teachersCache = teachers.map((e) => Teacher.fromJson(e)).toList();
        _teachersController.add(_teachersCache!);
        print('💾 Local update complete for teacher: ${teacher.name}');
      } else {
        throw Exception('Teacher not found locally for update.');
      }

      // 2. Cloud Sync
      try {
        final online = await ConnectivityService().isOnline;
        if (online) {
          await _supabase.updateTeacher(teacher);
          print('☁️ Cloud update complete for teacher: ${teacher.name}');
        } else {
          print('⚠️ Offline: Queueing teacher update for later');
          // Queue the specific update operation
          await SyncQueueService().addOperation(
            'update_teacher',
            teacher.toJson(),
          );
        }
      } catch (e) {
        print('❌ Cloud update for teacher failed: $e');
        await SyncQueueService().addOperation(
          'update_teacher',
          teacher.toJson(),
        );
      }
    } catch (e) {
      print('Error updating teacher: $e');
      rethrow;
    }
  }

  Future<void> deleteTeacher(String teacherId) async {
    print('🗑️ Starting teacher deletion: $teacherId');
    _pauseRealtimeSync = true;

    // Add to deleting set to prevent race conditions with realtime updates
    _deletingTeacherIds.add(teacherId);

    try {
      // 1. حذف من السحابة أولاً - محاولة مباشرة بدون فحص الاتصال
      print('☁️ Deleting from cloud...');
      try {
        await _supabase.deleteTeacher(teacherId);
        print('✅ Cloud delete successful');
      } catch (cloudError) {
        print('⚠️ Cloud delete failed: $cloudError');
        // Continue anyway - delete locally at least
      }

      // 2. حذف من المحلي
      print('💾 Deleting from local storage...');
      final db = await _readDb();
      final teachers = (db['teachers'] as List).cast<Map<String, dynamic>>();
      teachers.removeWhere((t) => t['id'] == teacherId);
      db['teachers'] = teachers;
      await _writeDb(db);
      clearTeachersCache();

      // 3. تحديث الـ Cache والـ Stream
      if (_teachersCache != null) {
        _teachersCache!.removeWhere((t) => t.id == teacherId);
        _teachersController.add(_teachersCache!);
      }

      print('✅ Teacher deleted successfully');
      await Future.delayed(const Duration(seconds: 3));
    } catch (e) {
      print('❌ Error deleting teacher: $e');
      rethrow;
    } finally {
      _pauseRealtimeSync = false;
      _deletingTeacherIds.remove(teacherId);
      print('▶️ Realtime sync resumed');
    }
  }

  Future<void> deleteStudent(String studentId) async {
    print('🗑️ Starting student deletion: $studentId');
    _pauseRealtimeSync = true;

    // Add to deleting set to prevent race conditions with realtime updates
    _deletingStudentIds.add(studentId);

    try {
      // 1. Delete from cloud first - attempt directly without checking connectivity
      print('☁️ Deleting student from cloud...');
      try {
        await _supabase.deleteStudent(studentId);
        print('✅ Cloud delete successful for student: $studentId');
      } catch (cloudError) {
        print('⚠️ Cloud delete failed for student $studentId: $cloudError');
        // Continue anyway - delete locally at least.
        // A robust offline solution would queue this deletion.
      }

      // 2. Delete from local storage
      print('💾 Deleting from local storage...');
      final db = await _readDb();
      final students = (db['students'] as List).cast<Map<String, dynamic>>();
      students.removeWhere((s) => s['id'] == studentId);
      db['students'] = students;
      // Also delete the user associated with the student
      final users = (db['users'] as List).cast<Map<String, dynamic>>();
      users.removeWhere((u) => u['studentId'] == studentId);
      db['users'] = users;
      await _writeDb(db); // Write both deletions
      clearStudentsCache();

      // 3. Update cache and stream
      if (_studentsCache != null) {
        _studentsCache!.removeWhere((s) => s.id == studentId);
        _studentsController.add(_studentsCache!);
      }

      print('✅ Student and associated user deleted successfully');
    } catch (e) {
      print('❌ Error deleting student: $e');
      rethrow;
    } finally {
      _pauseRealtimeSync = false;
      _deletingStudentIds.remove(studentId);
      print('▶️ Realtime sync resumed for students');
    }
  }

  // Students
  // Students - Local First Strategy
  Future<List<Student>> loadStudents({bool forceRefresh = false}) async {
    _ensureInfra();

    // 1. Load Local
    final db = await _readDb(forceRefresh: forceRefresh);
    final list = (db['students'] as List).cast<Map<String, dynamic>>();

    final localStudents = <Student>[];
    for (var e in list) {
      try {
        localStudents.add(Student.fromJson(e));
      } catch (err) {
        print('⚠️ Skipping corrupted student record: $err');
      }
    }

    // 2. If we have local data, return it immediately (FAST)
    if (localStudents.isNotEmpty && !forceRefresh) {
      _studentsCache = localStudents;
      // CRITICAL FIX: Immediately push cached data to the stream for any listeners.
      _studentsController.add(localStudents);

      // Trigger background sync to update stream later
      _syncStudentsFromCloud();
      print(
        '🚀 Fast Load: Returning ${localStudents.length} local students. Syncing in background...',
      );
      return localStudents;
    }

    // 3. If Local empty or Force Refresh, Blocking Cloud Sync
    try {
      final online = await ConnectivityService().isOnline;
      if (online) {
        print('☁️ Fetching students from cloud (Blocking)...');
        final cloudStudents = await _supabase.loadStudents();

        if (cloudStudents.isNotEmpty) {
           // SAFE MERGE: Keep local items not yet in cloud?
           // Or at least merge with existing local cache to avoid losing new items.
           
           // We need to read the latest DB state because we might be in the middle of an operation
           final currentDb = await _readDb();
           final currentLocalList = (currentDb['students'] as List).cast<Map<String, dynamic>>()
               .map((e) => Student.fromJson(e)).toList();

           final localMap = {for (var s in currentLocalList) s.id: s};
           final cloudMap = {for (var s in cloudStudents) s.id: s};
           
           // Cloud updates existing, but does NOT remove local-only items blindly 
           // (unless we are sure they are deleted, which is hard here. Safer to keep).
           localMap.addAll(cloudMap);
           
           final merged = localMap.values.toList();

          db['students'] = merged.map((s) => s.toJson()).toList();
          await _writeDb(db);

          _studentsCache = merged;
          _studentsController.add(merged);
          print('✅ Blocking Sync: Loaded ${merged.length} students (Merged)');
          return merged;
        }
      }
    } catch (e) {
      print('⚠️ Blocking Sync failed: $e');
    }

    // Final Fallback
    _studentsCache = localStudents;
    return localStudents;
  }

  // Background sync for students (non-blocking)
  void _syncStudentsFromCloud() {
    _supabase
        .loadStudents()
        .then((cloudStudents) async {
          try {
            if (cloudStudents.isNotEmpty && _studentsCache != null) {
              // Standardize on ID-based merging
              final localMap = {for (var s in _studentsCache!) s.id: s};
              final cloudMap = {for (var s in cloudStudents) s.id: s};

              // Cloud overwrites local (Cloud is Truth)
              // Local-only items are preserved
              localMap.addAll(cloudMap);
              
              final merged = localMap.values.toList();

              final updatedDb = await _readDb(forceRefresh: true);
              updatedDb['students'] = merged.map((s) => s.toJson()).toList();
              await _writeDb(updatedDb);
              _studentsCache = merged;
              _studentsController.add(merged);
              print('🔄 Background sync: Students updated from cloud (Merged IDs)');
            }
          } catch (e) {
            print('Error in background sync for students: $e');
          }
        })
        .catchError((e) {
          print('Error in background sync for students: $e');
        });
  }

  Future<void> saveStudents(List<Student> students) async {
    _ensureInfra();
    try {
      // 1. Optimistic Update: Save to local immediately so UI updates
      final db = await _readDb();
      db['students'] = students.map((s) => s.toJson()).toList();
      await _writeDb(db);

      _studentsCache = students;
      _studentsController.add(students);
      print('💾 Local save complete (${students.length} students)');

      // 2. Cloud Sync
      try {
        final online = await ConnectivityService().isOnline;
        if (online) {
          await _supabase.saveStudents(students);
          print('☁️ Cloud save complete');
        } else {
          print('⚠️ Offline: Queueing save for later');
          await SyncQueueService().addOperation('save_students', {
            'list': students.map((s) => s.toJson()).toList(),
          });
        }
      } catch (e) {
        print('❌ Cloud save failed: $e');
        await SyncQueueService().addOperation('save_students', {
          'list': students.map((s) => s.toJson()).toList(),
        });
      }
    } catch (e) {
      print('❌ Error saving students: $e');
      rethrow;
    }
  }

  // Users for auth
  // هذه الدالة للتوافق مع الكود القديم - تستخدم loginUser الآن
  Future<Map<String, dynamic>?> findUser(String email, String password) async {
    print('⚠️ findUser مستخدمة - يفضل استخدام loginUser');
    return await loginUser(email, password);
  }

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    try {
      final db = await _readDb();
      final users = (db['users'] as List).cast<Map<String, dynamic>>();
      for (final user in users) {
        if (user['email'] == email) {
          return user;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateStudent(Student student) async {
    _ensureInfra();
    try {
      // 1. Optimistic Update: Save to local immediately
      final db = await _readDb();
      final students = (db['students'] as List).cast<Map<String, dynamic>>();
      final index = students.indexWhere((s) => s['id'] == student.id);

      if (index != -1) {
        students[index] = student.toJson();
        db['students'] = students;
        await _writeDb(db);

        // Update cache and stream
        _studentsCache = students.map((e) => Student.fromJson(e)).toList();
        _studentsController.add(_studentsCache!);
        print('💾 Local update complete for student: ${student.name}');
      } else {
        throw Exception('Student not found locally for update.');
      }

      // 2. Cloud Sync
      try {
        final online = await ConnectivityService().isOnline;
        if (online) {
          await _supabase.updateStudent(student);
          print('☁️ Cloud update complete for student: ${student.name}');
        } else {
          print('⚠️ Offline: Queueing student update for later');
          await SyncQueueService().addOperation(
            'update_student',
            student.toJson(),
          );
        }
      } catch (e) {
        print('❌ Cloud update for student failed: $e');
        await SyncQueueService().addOperation(
          'update_student',
          student.toJson(),
        );
      }
    } catch (e) {
      print('Error updating student: $e');
      rethrow;
    }
  }

  Future<Student> addStudentAndUser(Student student) async {
    print('📝 إضافة طالب: ${student.name}');

    // توليد UUID فريد للطالب
    final newId = 'student_${DateTime.now().millisecondsSinceEpoch}_${student.email.hashCode.abs()}';
    final studentWithId = student.copyWith(id: newId);

    // 1. احفظ محلياً أولاً (Optimistic)
    final db = await _readDb();
    final students = (db['students'] as List).cast<Map<String, dynamic>>();
    final users = (db['users'] as List).cast<Map<String, dynamic>>();

    // Check duplicates locally
    if (students.any((s) => s['email'] == student.email)) {
      throw Exception('هذا البريد الإلكتروني مسجل مسبقاً.');
    }

    students.add(studentWithId.toJson());
    users.add({
      'email': student.email,
      'password': student.password,
      'role': 'student',
      'studentId': newId,
      'id': newId,
    });

    db['students'] = students;
    db['users'] = users;
    await _writeDb(db);

    _studentsCache = students.map((e) => Student.fromJson(e)).toList();
    _studentsController.add(_studentsCache!);
    print('💾 تم الحفظ محلياً: ${student.name} (ID: $newId)');

    // 2. ارفع مباشرةً لـ Supabase (بدون Auth signUp)
    final online = await ConnectivityService().checkRealConnectivity();
    if (online) {
      try {
        await _supabase.addStudent(studentWithId);
        print('☁️ تم رفع الطالب لـ Supabase بنجاح: ${student.name}');
      } catch (e) {
        print('⚠️ فشل رفع الطالب للسحابة: $e. سيتم المزامنة لاحقاً.');
        await SyncQueueService().addOperation('upsert_student', studentWithId.toJson());
      }
    } else {
      print('🔌 لا يوجد إنترنت. تم الحفظ محلياً وسيتم المزامنة لاحقاً.');
      await SyncQueueService().addOperation('upsert_student', studentWithId.toJson());
    }

    return studentWithId;
  }

  /// Centralized execution wrapper for robust error handling.
  /// This is a copy from SupabaseService to handle local storage errors
  /// and provide consistent error messages.
  Future<T> _safeExecution<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    try {
      return await operation();
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      print('❌ Error in StorageService.$operationName: $e');

      String friendlyMessage = 'حدث خطأ غير متوقع';
      if (errorStr.contains('invalid login credentials')) {
        friendlyMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      } else if (errorStr.contains('socket') ||
          errorStr.contains('dns') ||
          errorStr.contains('network') ||
          errorStr.contains('connection')) {
        friendlyMessage = 'مشكلة في الاتصال بالإنترنت. يرجى التحقق من الشبكة.';
      } else if (errorStr.contains('timeout')) {
        friendlyMessage = 'انتهت مهلة الاتصال. السيرفر لا يستجيب.';
      } else if (errorStr.contains('auth') || errorStr.contains('jwt')) {
        friendlyMessage = 'مشكلة في المصادقة. يرجى المحاولة مرة أخرى.';
      } else if (errorStr.contains('duplicate') ||
          errorStr.contains('unique') || errorStr.contains('already exists')) {
        friendlyMessage = 'هذا المستخدم مسجل بالفعل.';
      }

      throw Exception(friendlyMessage);
    }
  }
  /// Forcefully push local DB to cloud for teachers/students/messages.
  /// Useful for debugging and ensuring data reaches Supabase immediately.
  Future<void> forceSync({
    bool syncTeachers = true,
    bool syncStudents = true,
    bool syncMessages = true,
  }) async {
    _ensureInfra();
    try {
      // Check connectivity first (Real Ping)
      final hasInternet = await ConnectivityService().checkRealConnectivity();
      if (!hasInternet) {
        // Log locally but don't crash
        print(
          'StorageService: No real internet connection. Skipping cloud sync.',
        );
        throw Exception('لا يوجد اتصال حقيقي بالإنترنت (Offline Mode)');
      }

      final db = await _readDb(forceRefresh: true);
      final teachers = (db['teachers'] as List).cast<Map<String, dynamic>>();
      final students = (db['students'] as List).cast<Map<String, dynamic>>();
      final messages = (db['messages'] as List).cast<Map<String, dynamic>>();
      final chatMessages = (db['chat_messages'] as List)
          .cast<Map<String, dynamic>>();

      final teachersList = syncTeachers && teachers.isNotEmpty
          ? teachers
          : null;
      final studentsList = syncStudents && students.isNotEmpty
          ? students
          : null;
      final messagesList = syncMessages && messages.isNotEmpty
          ? messages
          : null;
      final chatMessagesList = syncMessages && chatMessages.isNotEmpty
          ? chatMessages
          : null;

      print(
        'StorageService: forceSync starting — teachers:${teachersList?.length ?? 0} students:${studentsList?.length ?? 0} messages:${messagesList?.length ?? 0} chat_messages:${chatMessagesList?.length ?? 0}',
      );

      // Only sync if there's data to sync
      if (teachersList != null ||
          studentsList != null ||
          messagesList != null ||
          chatMessagesList != null) {
        try {
          await _supabase.syncLocalToCloud(
            teachers: teachersList,
            students: studentsList,
            messages: messagesList,
          );
          print('✅ StorageService: forceSync completed successfully');

          // Clear cache after successful sync to force reload
          _teachersCache = null;
          _studentsCache = null;
          _messagesCache = null;
          _chatMessagesCache = null;
        } catch (e) {
          print('❌ StorageService: forceSync error: $e');
          rethrow;
        }
      } else {
        print('⚠️ StorageService: forceSync skipped - no data to sync');
      }
    } catch (e) {
      print('StorageService: forceSync failed: $e');
      rethrow;
    }
  }

  Future<Teacher> addTeacherAndUser(Teacher teacher) async {
    print('📝 إضافة أستاذ: ${teacher.name}');

    // توليد UUID فريد للأستاذ
    final newId = 'teacher_${DateTime.now().millisecondsSinceEpoch}_${teacher.email.hashCode.abs()}';
    final teacherWithId = teacher.copyWith(id: newId);

    // 1. احفظ محلياً أولاً (Optimistic)
    final db = await _readDb();
    final teachers = (db['teachers'] as List).cast<Map<String, dynamic>>();
    final users = (db['users'] as List).cast<Map<String, dynamic>>();

    // Check duplicates locally
    if (teachers.any((t) => t['email'] == teacher.email)) {
      throw Exception('هذا البريد الإلكتروني مسجل مسبقاً.');
    }

    teachers.add(teacherWithId.toJson());
    users.add({
      'email': teacher.email,
      'password': teacher.password,
      'role': 'teacher',
      'teacherId': newId,
      'id': newId,
    });

    db['teachers'] = teachers;
    db['users'] = users;
    await _writeDb(db);

    _teachersCache = teachers.map((e) => Teacher.fromJson(e)).toList();
    _teachersController.add(_teachersCache!);
    print('💾 تم الحفظ محلياً: ${teacher.name} (ID: $newId)');

    // 2. ارفع مباشرةً لـ Supabase (بدون Auth signUp)
    final online = await ConnectivityService().checkRealConnectivity();
    if (online) {
      try {
        await _supabase.addTeacher(teacherWithId);
        print('☁️ تم رفع الأستاذ لـ Supabase بنجاح: ${teacher.name}');
      } catch (e) {
        print('⚠️ فشل رفع الأستاذ للسحابة: $e. سيتم المزامنة لاحقاً.');
        await SyncQueueService().addOperation('upsert_teacher', teacherWithId.toJson());
      }
    } else {
      print('🔌 لا يوجد إنترنت. تم الحفظ محلياً وسيتم المزامنة لاحقاً.');
      await SyncQueueService().addOperation('upsert_teacher', teacherWithId.toJson());
    }

    return teacherWithId;
  }

  Future<void> resolveTempId({
    required String oldId,
    required String newId,
    required String collection, // 'teachers' or 'students'
  }) async {
    print('🔄 resolving ID: $oldId -> $newId in $collection');
    final db = await _readDb();
    
    // 1. Update the main record
    final list = (db[collection] as List).cast<Map<String, dynamic>>();
    final index = list.indexWhere((item) => item['id'] == oldId);
    
    if (index != -1) {
      list[index]['id'] = newId;
    }
    
    // 2. Update the user record
    final users = (db['users'] as List).cast<Map<String, dynamic>>();
    final userIndex = users.indexWhere((u) => u['id'] == oldId); // or teacherId/studentId check
    
    if (userIndex != -1) {
      users[userIndex]['id'] = newId;
      if (collection == 'teachers') {
        users[userIndex]['teacherId'] = newId;
      } else if (collection == 'students') {
        users[userIndex]['studentId'] = newId;
      }
    } else {
      // Fallback check by specific role ID if 'id' mismatch
      if (collection == 'teachers') {
         final tIdx = users.indexWhere((u) => u['teacherId'] == oldId);
         if (tIdx != -1) {
            users[tIdx]['teacherId'] = newId;
            users[tIdx]['id'] = newId;
         }
      } else {
         final sIdx = users.indexWhere((u) => u['studentId'] == oldId);
         if (sIdx != -1) {
            users[sIdx]['studentId'] = newId;
            users[sIdx]['id'] = newId;
         }
      }
    }
    
    // 3. Update references (e.g. students pointing to teacher)
    if (collection == 'teachers') {
       final students = (db['students'] as List).cast<Map<String, dynamic>>();
       // Not strictly relational in NoSQL style local JSON, but if we had IDs... 
       // Currently students store teacherName/teacherPhone which are static.
       // So maybe no update needed there unless we start using teacherId foreign keys.
    } else if (collection == 'students') {
       // Update messages, prayer records, etc?
       // For now, simpler app structure might not need deep cascading.
    }

    await _writeDb(db);
    
    // Refresh caches
    if (collection == 'teachers') {
        await loadTeachers(forceRefresh: true);
    } else {
        await loadStudents(forceRefresh: true);
    }
    print('✅ ID resolution complete.');
  }

  Future<void> ensureSampleStudent() async {
    try {
      final students = await loadStudents();
      final exists = students.any((s) => s.id == 'stu_1');
      if (!exists) {
        students.add(
          Student(
            id: 'stu_1',
            name: 'طالب تجريبي',
            phone: '0911111111',
            teacherName: 'أ. يمان',
            teacherPhone: '0999999999',
            email: 'student@yaman',
            password: '123456',
            points: 80,
            attendance: [
              true,
              true,
              false,
              true,
              true,
              false,
              true,
              true,
              false,
              true,
            ],
            prayers: [
              ['جماعة', 'أداء', 'قضاء', 'غياب'],
              ['جماعة', 'أداء', 'قضاء', 'غياب'],
              ['جماعة', 'أداء', 'قضاء', 'غياب'],
              ['جماعة', 'أداء', 'قضاء', 'غياب'],
              ['جماعة', 'أداء', 'قضاء', 'غياب'],
            ],
            prayerDates: [],
            memorization: ['ممتاز', 'جيد', 'ضعيف', 'ممتاز', 'جيد'],
          ),
        );
        await saveStudents(students);
        print('Sample student created successfully');
      }
    } catch (e) {
      print('Error ensuring sample student: $e');
      rethrow;
    }
  }

  Future<void> ensureSampleTeacher() async {
    try {
      final teachers = await loadTeachers();
      final exists = teachers.any((t) => t.email == 'teacher@yaman');
      if (!exists) {
        final sample = Teacher(
          id: 'teacher_1',
          name: 'أ. يمان',
          number: '0999999999',
          email: 'teacher@yaman',
          password: '123456',
        );
        final saved = await addTeacherAndUser(sample);
        print('Sample teacher created successfully: ${saved.name}');
      }
    } catch (e) {
      print('Error ensuring sample teacher: $e');
    }
  }

  Future<void> updateTeacherUser(
    String teacherName,
    String newEmail,
    String newPassword,
  ) async {
    try {
      final db = await _readDb();
      final users = (db['users'] as List).cast<Map<String, dynamic>>();
      final userIndex = users.indexWhere((u) => u['teacherId'] == teacherName);
      if (userIndex != -1) {
        users[userIndex]['email'] = newEmail;
        users[userIndex]['password'] = newPassword;
        db['users'] = users;
        await _writeDb(db);
        print('Teacher user updated successfully: $teacherName');
      }
    } catch (e) {
      print('Error updating teacher user: $e');
      rethrow;
    }
  }

  Future<void> deleteTeacherUser(String teacherId) async {
    try {
      final db = await _readDb();
      final users = (db['users'] as List).cast<Map<String, dynamic>>();
      users.removeWhere((u) => u['teacherId'] == teacherId);
      db['users'] = users;
      await _writeDb(db);
      print('Teacher user deleted successfully: $teacherId');
    } catch (e) {
      print('Error deleting teacher user: $e');
      rethrow;
    }
  }

  // Messages
  Future<List<Message>> loadMessages({bool forceRefresh = false}) async {
    try {
      final online = await ConnectivityService().isOnline;
      if (online) {
        try {
          // CLOUD FIRST
          print('☁️ Fetching messages from cloud (Cloud-First)...');
          final cloudMessages = await _supabase.loadMessages();
          if (cloudMessages.isNotEmpty) {
            final db = await _readDb(forceRefresh: true);
            db['messages'] = cloudMessages.map((m) => m.toJson()).toList();
            await _writeDb(db);
            _messagesCache = cloudMessages;
            return cloudMessages;
          }
        } catch (e) {
          print('⚠️ Cloud sync failed for messages, falling back to local: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error checking connectivity: $e');
    }

    if (_messagesCache != null && !forceRefresh) return _messagesCache!;

    try {
      final db = await _readDb(forceRefresh: forceRefresh);
      final list = (db['messages'] as List).cast<Map<String, dynamic>>();
      final localMessages = list.map((e) => Message.fromJson(e)).toList();
      _messagesCache = localMessages;
      return localMessages;
    } catch (e) {
      print('Error loading messages locally: $e');
      return [];
    }
  }

  Future<void> saveMessages(List<Message> messages) async {
    _ensureInfra();
    try {
      // 1. Optimistic Update: Save to local
      final db = await _readDb();
      db['messages'] = messages.map((m) => m.toJson()).toList();
      await _writeDb(db);
      print('💾 Local save complete (${messages.length} messages)');

      // 2. Cloud Sync
      try {
        final online = await ConnectivityService().isOnline;
        if (online) {
          await _supabase.saveMessages(messages);
          print('☁️ Cloud save complete');
        } else {
          print('⚠️ Offline: Queueing save_messages for later');
          await SyncQueueService().addOperation('save_messages', {
            'list': messages.map((m) => m.toJson()).toList(),
          });
        }
      } catch (e) {
        print('❌ Cloud save failed: $e');
        await SyncQueueService().addOperation('save_messages', {
          'list': messages.map((m) => m.toJson()).toList(),
        });
      }
    } catch (e) {
      print('Error saving messages: $e');
      rethrow;
    }
  }

  // Chat Messages
  Future<List<ChatMessage>> loadChatMessages({
    required String conversationId,
    bool forceRefresh = false,
    int limit = 30, // Default batch size
    int offset = 0,
  }) async {
    // 1. Check Cache
    if (!forceRefresh && _conversationCache.containsKey(conversationId)) {
      final timestamp = _conversationCacheTimestamps[conversationId];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheTTL) {
        final cached = _conversationCache[conversationId]!;
        
        // standard Slice logic:
        // We want LATEST N messages.
        // Cache is ASC (Old...New).
        // To get latest, we sort DESC.
        final sortedDesc = List<ChatMessage>.from(cached)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        final start = offset;
        final end = (offset + limit) > sortedDesc.length ? sortedDesc.length : (offset + limit);
        if (start >= sortedDesc.length) return [];
        
        print('📦 Returning ${end-start} messages from cache for $conversationId (offset: $offset)');
        return sortedDesc.sublist(start, end);
      }
    }

    try {
      final db = await _readDb(forceRefresh: forceRefresh);
      final allMessages = (db['chat_messages'] as List)
          .cast<Map<String, dynamic>>();

      final conversationMessages = allMessages
          .where((m) => m['conversationId'] == conversationId)
          .map((e) => ChatMessage.fromJson(e))
          .toList();

      // 1.5. REPAIR STEP: Check for "stuck" pending messages
      // If we have a pending message locally, but it exists in Cloud (via sync or just logic),
      // we should mark it sent.
      // However, we only have 'conversationMessages' from LOCAL DB here.
      // We rely on _syncChatConversation to update DB from Cloud.
      // But _syncChatConversation runs in background.
      
      // Better approach: When loading locally, if we see 'pending' messages that are OLD (> 5 mins),
      // we should probably mark them 'failed' or trigger a specific check.
      // But for "loading" bug (user sees loading forever), it's because UI shows local state.
      // If _syncChatConversation succeeded, DB has new state.
      // So if DB still has 'pending', it means _syncChatConversation didn't run or didn't find it.
      
      // New logic: If this method was called with forceRefresh=true (usually on init),
      // we might want to wait for sync or check explicitly? 
      // But we can't block too long.
      
      // Let's rely on the fact that if we are Online, we trigger sync.
      // If we are Offline, we keep pending.
      
      // Fix for "Stuck Loading": 
      // Ensure that if a message ID is in the "Cloud List" (if we fetched it),
      // we update local to matches Cloud.
      
      // Since _syncChatConversation does the fetching, we can't see cloud list here easily
      // unless we await it.
      // BUT current implementation calls _syncChatConversation WITHOUT await (fire and forget).
      
      // CHANGE: If forceRefresh is true, we should AWAIT the sync (at least for a short time?)
      // No, that might freeze UI.
      
      // Alternative: We return local list. 
      // Then background sync updates DB. 
      // The UI uses a Stream from Supabase.
      // The Supabase Stream should emit the message.
      
      // If the UI is stuck, it means:
      // 1. Local has Pending.
      // 2. Stream didn't emit (or UI ignored it).
      
      // We found UI ignores if ID exists.
      // So we MUST fix UI _addNewMessage first.
      
      // But improving StorageService is also good.
      // Let's add a robust check: If status is pending and created > 10 min ago, mark failed.
      final now = DateTime.now();
      for (var i = 0; i < conversationMessages.length; i++) {
        final msg = conversationMessages[i];
         if (msg.status == MessageStatus.pending) {
            if (now.difference(msg.createdAt).inMinutes > 5) {
               // Mark as failed if stuck for 5 minutes
               conversationMessages[i] = msg.copyWith(status: MessageStatus.failed);
               
               // Persist this fix asynchronously
               // We don't await to avoid blocking read
               // But we should update DB eventually.
               updateMessageStatusExternal(
                 messageId: msg.id, 
                 conversationId: conversationId, 
                 status: MessageStatus.failed
               );
            }
         }
      }

      // Sort Newest -> Oldest for consistent return value
      conversationMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // 2. Update Cache (Store Full History in ASC order)
      final canonicalList = List<ChatMessage>.from(conversationMessages)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      _conversationCache[conversationId] = canonicalList;
      _conversationCacheTimestamps[conversationId] = DateTime.now();

      // If online, trigger a background sync for this conversation (Syncs Latest)
      try {
        final online = await ConnectivityService().isOnline;
        if (online) {
          _syncChatConversation(conversationId);
        }
      } catch (_) {
        // Ignore connectivity errors
      }

      // Return requested slice
      final start = offset;
      final end = (offset + limit) > conversationMessages.length ? conversationMessages.length : (offset + limit);
      if (start >= conversationMessages.length) return [];
      
      return conversationMessages.sublist(start, end);
    } catch (e) {
      print('Error loading chat messages locally: $e');
      return [];
    }
  }

  // Background sync for a single chat conversation
  void _syncChatConversation(String conversationId) {
    _supabase
        .loadChatMessages(conversationId: conversationId)
        .then((cloudMessages) async {
            // Even if empty, we might need to clear local if cloud was cleared.
            // But usually loadChatMessages returns empty if error or empty.
            // Let's assume successful empty list means "no messages".
            
            final db = await _readDb(forceRefresh: true);
            final allLocalMessages = (db['chat_messages'] as List).cast<Map<String, dynamic>>();

            // 1. Update/Insert from Cloud
            final localMessageMap = {
              for (var m in allLocalMessages) m['id'] as String: m,
            };

            final cloudIds = <String>{};
            for (final cloudMsg in cloudMessages) {
              localMessageMap[cloudMsg.id] = cloudMsg.toJson();
              cloudIds.add(cloudMsg.id);
            }

            // 2. Handle Deletions:
            // If a message exists LOCALLY for this conversation, but is NOT in Cloud list,
            // AND it's not a pending message we just created (status != pending),
            // then it means it was deleted on Cloud. Delete it locally.
            
            localMessageMap.removeWhere((id, msgJson) {
              final msgConvId = msgJson['conversationId'];
              if (msgConvId != conversationId) return false; // Don't touch other convos
              
              // If it's in cloudIds, keep it (it was just updated).
              if (cloudIds.contains(id)) return false;

              // It's NOT in cloud fetch.
              // Determine status safely
              final statusVal = msgJson['status'];
              final isPending = statusVal == 0 || statusVal == 'pending';
              final isSent = statusVal == 1 || statusVal == 'sent';

              // 1. Always keep Pending messages (waiting for sync or in-flight)
              if (isPending) return false;

              // 2. For Sent messages not in cloud:
              // Apply a 24-hour grace period to prevent deletion of recently sent messages 
              // that might not have replicated or been indexed in the cloud yet.
              if (isSent) {
                final createdAtStr = msgJson['createdAt'] as String?;
                if (createdAtStr != null) {
                  try {
                    final createdAt = DateTime.parse(createdAtStr);
                    final age = DateTime.now().difference(createdAt);
                    if (age.inHours < 24) {
                      return false; // Grace period: Keep recent local-only "sent" messages
                    }
                  } catch (_) {}
                }
              }

              // 3. For Failed messages or OLD local-only messages:
              // If they were deleted on cloud by another device or user, they won't be in cloudIds.
              // We delete them locally to maintain consistency with cloud truth.
              return true; 
            });

            db['chat_messages'] = localMessageMap.values.toList();
            await _writeDb(db);
            
            // 3. Update In-Memory Cache for this conversation
            if (_conversationCache.containsKey(conversationId)) {
                final currentCache = {for (var m in _conversationCache[conversationId]!) m.id: m};
                for (final cloudMsg in cloudMessages) {
                    currentCache[cloudMsg.id] = cloudMsg;
                }
                final sorted = currentCache.values.toList()
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                _conversationCache[conversationId] = sorted;
                _conversationCacheTimestamps[conversationId] = DateTime.now();
            }

            print('🔄 Background sync: Chat $conversationId synced (Upsert + Delete + Cache Update).');
        })
        .catchError((e) {
          print('Error in background sync for chat conversation $conversationId: $e');
        });
  }

  Future<void> saveChatMessages(List<ChatMessage> messages) async {
    _ensureInfra();
    try {
      // 1. Optimistic Update: Save to local (Merge, don't overwrite)
      final db = await _readDb();
      final allLocalMessages = (db['chat_messages'] as List).cast<Map<String, dynamic>>();

      // Create a map of existing messages for O(1) lookup
      final messageMap = {
        for (var m in allLocalMessages) m['id'] as String: m,
      };

      // Upsert new messages
      for (var msg in messages) {
        messageMap[msg.id] = msg.toJson();
      }

      db['chat_messages'] = messageMap.values.toList();
      await _writeDb(db);
      print('💾 Local save complete (${messages.length} updated/added). Total: ${messageMap.length}');

      // Update Cache immediately
      final groups = <String, List<ChatMessage>>{};
      for (var msg in messages) {
        if (!groups.containsKey(msg.conversationId)) groups[msg.conversationId] = [];
        groups[msg.conversationId]!.add(msg);
      }

      for (var entry in groups.entries) {
        final convId = entry.key;
        if (_conversationCache.containsKey(convId)) {
           // We have a cache, let's update it intelligently or just invalid/re-read from our fresh map
           // Merging is safer.
           final currentCache = {for (var m in _conversationCache[convId]!) m.id: m};
           for (var newMsg in entry.value) {
             currentCache[newMsg.id] = newMsg;
           }
           final sorted = currentCache.values.toList()
             ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
           _conversationCache[convId] = sorted;
           _conversationCacheTimestamps[convId] = DateTime.now(); // Refresh TTL
        }
      }

      // 2. Cloud Sync (Only online messages need to be pushed if this method is used for bulk save)
      // Note: Usually specialized methods like sendChatMessage handle individual sync.
      // We'll leave this simple bulk sync attempt here for compatibility.
      try {
        final online = await ConnectivityService().checkRealConnectivity();
        if (online) {
          await _supabase.saveChatMessages(messages);
          print('☁️ Cloud save complete for chat messages');
        }
      } catch (e) {
        print('⚠️ Cloud save failed (Background): $e');
      }
    } catch (e) {
      print('Error saving chat messages: $e');
    }
  }

  /// Sends a single chat message with Offline-First logic
  /// Sends a single chat message with Offline-First logic
  Future<void> sendChatMessage(ChatMessage message) async {
    // 1. Optimistic Update (Immediate UI Reflection)
    // We update the In-Memory DB & Cache immediately.
    // The disk write will be debounced by _writeDb.
    
    // Update Cache (Upsert to prevent duplicates)
    if (!_conversationCache.containsKey(message.conversationId)) {
      _conversationCache[message.conversationId] = [];
    }
    final cached = _conversationCache[message.conversationId]!;
    final index = cached.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      cached[index] = message;
    } else {
      cached.add(message);
    }
    // Re-sort to maintain ASC order in cache
    cached.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _conversationCacheTimestamps[message.conversationId] = DateTime.now();

    // Update DB Object
    try {
      final db = await _readDb();
      final allLocalMessages = (db['chat_messages'] as List).cast<Map<String, dynamic>>();
      
      // Upsert Logic: Check existence by ID
      final messageMap = {for (var m in allLocalMessages) m['id'] as String: m};
      messageMap[message.id] = message.toJson();
      
      db['chat_messages'] = messageMap.values.toList();
      await _writeDb(db); // Triggers debounced write
    } catch (e) {
      print('Error updating local DB for send: $e');
    }

    print('📤 Sending message to cloud: ${message.id} (Optimistic)');

    // 2. Cloud Send
    try {
      final online = await ConnectivityService().checkRealConnectivity();
      if (online) {
        await _supabase.saveChatMessage(message);
        
        // 3. Update Status to Sent Robusly
        await updateMessageStatusExternal(
          messageId: message.id,
          conversationId: message.conversationId,
          status: MessageStatus.sent,
        );
      } else {
        throw Exception('Offline');
      }
    } catch (e) {
      print('⚠️ Send Failed/Offline: Queueing... ($e)');
      
      // Ensure it is in the Queue for background sync
      await SyncQueueService().addOperation('save_chat_messages', {
        'list': [message.toJson()],
      });

      // Rethrow to allow UI rollback if desired, or at least stop the "AWAIT" with an error.
      // Note: If we don't rethrow, the UI will think it succeeded and show 'sent' via my new _updateSingleMessageStatus(sent) call.
      // So we MUST rethrow or return bool.
      rethrow;
    }
  }

  // Batch Send
  Future<void> sendChatMessages(List<ChatMessage> messages) async {
    for (var msg in messages) {
      await sendChatMessage(msg); // Debouncing handles the write load
    }
  }

  Future<List<Message>> loadMessagesForConversation(
    String studentId,
    String teacherName,
  ) async {
    try {
      return await _supabase.loadMessagesForConversation(
        studentId,
        teacherName,
      );
    } catch (e) {
      print('Error loading conversation from cloud, falling back to local: $e');
      final allMessages = await loadMessages();
      return allMessages
          .where(
            (m) =>
                (m.senderId == studentId && m.receiverName == teacherName) ||
                (m.senderName == teacherName && m.receiverId == studentId),
          )
          .toList();
    }
  }

  Future<void> addMessage(Message message) async {
    final messages = await loadMessages();
    messages.add(message);
    await saveMessages(messages);

    // Add to cloud in background
    try {
      await _supabase.addMessage(message);
    } catch (e) {
      print('Error adding message to cloud: $e');
    }
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    print('🔐 تسجيل دخول: $email');

    final db = await _readDb();
    final users = (db['users'] as List).cast<Map<String, dynamic>>();
    final students = (db['students'] as List).cast<Map<String, dynamic>>();
    final teachers = (db['teachers'] as List).cast<Map<String, dynamic>>();

    // 1. تحقق من الأدمن (محلياً دائماً)
    final adminUser = users.firstWhere(
      (u) => u['role'] == 'admin' && u['email'] == email,
      orElse: () => <String, dynamic>{},
    );

    if (adminUser.isNotEmpty) {
      if (adminUser['password'] == password) {
        print('✅ أدمن (محلي)');
        return adminUser;
      } else {
        throw Exception('كلمة مرور خاطئة');
      }
    }

    // 2. البحث عن المستخدم محلياً (Offline-First) لتسريع الدخول إذا كان مسجلاً
    print('📂 البحث عن المستخدم محلياً (Offline-First)...');
    
    final localTeacher = teachers.firstWhere(
      (t) => t['email'] == email,
      orElse: () => <String, dynamic>{},
    );
    if (localTeacher.isNotEmpty) {
      if (localTeacher['password'] == password) {
        print('✅ وجدنا الأستاذ محلياً');
        return {
          'role': 'teacher',
          'teacherId': localTeacher['id'],
          'id': localTeacher['id'],
          'email': email,
          'password': password,
        };
      } else {
        throw Exception('البريد الإلكتروني أو كلمة المرور غير صحيحة');
      }
    }

    final localStudent = students.firstWhere(
      (s) => s['email'] == email,
      orElse: () => <String, dynamic>{},
    );
    if (localStudent.isNotEmpty) {
      if (localStudent['password'] == password) {
        print('✅ وجدنا الطالب محلياً');
        return {
          'role': 'student',
          'studentId': localStudent['id'],
          'id': localStudent['id'],
          'email': email,
          'password': password,
        };
      } else {
        throw Exception('البريد الإلكتروني أو كلمة المرور غير صحيحة');
      }
    }

    // Fallback لجدول users القديم (احتياطاً)
    final localUser = users.firstWhere(
      (u) => u['email'] == email,
      orElse: () => <String, dynamic>{},
    );
    if (localUser.isNotEmpty && localUser['role'] != 'admin') {
      if (localUser['password'] == password) {
        print('✅ وجدناه في سِجل المستخدمين (محلياً)');
        return localUser;
      } else {
        throw Exception('البريد الإلكتروني أو كلمة المرور غير صحيحة');
      }
    }

    // 3. محاولة السحابة (إذا لم يتواجد محلياً إطلاقاً - مثلاً تسجيل دخول لأول مرة على هذا الجهاز)
    try {
      final hasInternet = await ConnectivityService().checkRealConnectivity(timeout: Duration(seconds: 2));
      
      if (hasInternet) {
        print('☁️ محاولة تسجيل الدخول عبر السحابة...');
        final result = await _supabase.signIn(email, password);
        
        if (result != null) {
          print('✅ نجح تسجيل الدخول السحابي: ${result['role']}');
          
          // تحديث البيانات محلياً فوراً
          final userRecord = {
            'email': email,
            'password': password,
            'role': result['role'],
            'studentId': result['studentId'],
            'teacherId': result['teacherId'],
            'id': result['userId'],
          };

          // إضافته للوحة المستخدمين لتسهيل البحث لاحقاً
          final existingIndex = users.indexWhere((u) => u['email'] == email);
          if (existingIndex != -1) {
            users[existingIndex] = userRecord;
          } else {
            users.add(userRecord);
          }
          db['users'] = users;
          await _writeDb(db);

          // تحميل بيانات الملف الشخصي الكاملة من السحابة ليعمل التطبيق بسلاسة
          try {
             if (result['role'] == 'student' && result['studentId'] != null) {
                await loadStudents(forceRefresh: true);
                print('✅ تم سحب ملف الطالب من السحابة.');
             } else if (result['role'] == 'teacher' && result['teacherId'] != null) {
                await loadTeachers(forceRefresh: true);
                print('✅ تم سحب ملف الأستاذ من السحابة.');
             }
          } catch (e) {
             print('⚠️ فشل تحميل البيانات التفصيلية بعد تسجيل الدخول: $e');
             // لا مشكلة، سينجح الدخول والـ AutoSyncService سيتكفل بالباقي.
          }
          
          return result;
        } else {
          throw Exception('البريد الإلكتروني أو كلمة المرور غير صحيحة');
        }
      } else {
        throw Exception('غير متصل بالإنترنت، ولم يتم العثور محلياً على هذا المستخدم.');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('غير صحيحة')) {
         rethrow;
      }
      print('⚠️ خطأ أثناء تسجيل الدخول: $e');
      throw Exception('حدثت مشكلة (راجع البريد/كلمة المرور أو اتصالك بالإنترنت).');
    }
  }

  Future<Map<String, dynamic>?> registerUser(
    String email,
    String password,
    String role, {
    String? name,
    String? phone,
  }) async {
    return _safeExecution(() async {
      print('📝 تسجيل مستخدم جديد عبر التطبيق: $email ($role)');
      
      if (role == 'student') {
        final newStudent = Student(
          id: '', // Will be generated in addStudentAndUser
          name: name ?? 'طالب جديد',
          phone: phone ?? '',
          teacherName: '',
          teacherPhone: '',
          email: email,
          password: password,
          points: 0,
          attendance: [],
          prayers: [],
          prayerDates: [],
          memorization: [],
        );
        
        final savedStudent = await addStudentAndUser(newStudent);
        return {
          'userId': savedStudent.id,
          'studentId': savedStudent.id,
          'role': 'student',
        };
      } else if (role == 'teacher') {
         final newTeacher = Teacher(
            id: '', 
            name: name ?? 'أستاذ جديد',
            number: phone ?? '',
            email: email,
            password: password,
         );
         final savedTeacher = await addTeacherAndUser(newTeacher);
         return {
            'userId': savedTeacher.id,
            'teacherId': savedTeacher.id,
            'role': 'teacher',
         };
      }
      return null;
    }, 'registerUser');
  }

  Future<bool> isUserSyncedLocally(String email) async {
    try {
      final db = await _readDb();
      final users = (db['users'] as List).cast<Map<String, dynamic>>();
      return users.any((u) => u['email'] == email);
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Logout Helper
  // ---------------------------------------------------------------------------
  Future<void> logout() async {
    try {
      // 1. Sign out from Supabase
      await _supabase.signOut();

      // 2. Clear Local Preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      print('✅ تم تسجيل الخروج بنجاح');
    } catch (e) {
      print('⚠️ فشل أثناء تسجيل الخروج: $e');
      // Force clear prefs anyway so user isn't stuck
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      rethrow;
    }
  }
  
  // Helper methods for SyncQueueService to access database
  Future<Map<String, dynamic>> readDbForSync() async {
    return await _readDb(forceRefresh: true);
  }
  
  Future<void> writeDbForSync(Map<String, dynamic> db) async {
    await _writeDb(db);
  }

  Future<void> updateMessageStatusExternal({
    required String messageId,
    required String conversationId,
    required MessageStatus status,
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    bool success = false;

    while (attempts < maxRetries && !success) {
      attempts++;
      try {
        print('🔄 [StatusUpdate] Attempt $attempts/$maxRetries: Message $messageId -> $status');
        
        // 1. Update Cache first (Immediate UI feedback for anyone listening to cache)
        final cachedList = _conversationCache[conversationId];
        if (cachedList != null) {
          final index = cachedList.indexWhere((m) => m.id == messageId);
          if (index != -1) {
             // We update the cache object in place or replace it
            cachedList[index] = cachedList[index].copyWith(status: status);
            _conversationCacheTimestamps[conversationId] = DateTime.now(); // Bump TTL
          }
        }

        // 2. Update DB
        final db = await _readDb();
        final allLocalMessages = (db['chat_messages'] as List).cast<Map<String, dynamic>>();
        final index = allLocalMessages.indexWhere((m) => m['id'] == messageId);
        
        if (index != -1) {
          final msgJson = Map<String, dynamic>.from(allLocalMessages[index]);
          msgJson['status'] = status.index; // 0=pending, 1=sent, 2=failed
          allLocalMessages[index] = msgJson;
          
          await _writeDb(db);
          success = true;
          print('✅ [StatusUpdate] Successfully updated $messageId to $status in DB and Cache');
        } else {
          print('⚠️ [StatusUpdate] Message $messageId not found in DB. Already deleted?');
          success = true; // Nothing to update
        }
      } catch (e) {
        print('❌ [StatusUpdate] Attempt $attempts failed for $messageId: $e');
        if (attempts < maxRetries) {
          await Future.delayed(Duration(milliseconds: 300 * attempts)); // Backoff
        }
      }
    }
  }
  
}

