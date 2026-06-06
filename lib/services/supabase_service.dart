import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/models/chat_message.dart';
import 'package:yaman/models/message.dart';
import 'package:yaman/models/adhkar.dart';
import 'package:yaman/models/lesson.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  List<Teacher>? _teachersCache;
  List<Student>? _studentsCache;
  List<Message>? _messagesCache;
  final _uuid = const Uuid();

  /// Centralized execution wrapper for all Supabase calls
  /// Handles connectivity checks, error parsing, and logging.
  Future<T> _safeExecution<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    try {
      // Optional: Check connectivity before trying (Fast fail)
      // final hasInternet = await ConnectivityService().isOnline;
      // if (!hasInternet) throw const SocketException('No Internet');
      // Note: We let the operation try, as network might be available even if listener says no.

      return await operation();
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      print('❌ Error in $operationName: $e');

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
          errorStr.contains('unique')) {
        friendlyMessage = 'هذه البيانات موجودة مسبقاً.';
      }

      throw Exception(friendlyMessage);
    }
  }

  // Real-time subscriptions
  Stream<List<Teacher>> subscribeToTeachers() {
    return _client
        .from('teachers')
        .stream(primaryKey: ['id'])
        .map((data) => data.map((e) => Teacher.fromJson(e)).toList())
        .handleError((error) {
          print('❌ Stream Error (Teachers): $error');
          // Return empty list or rethrow? Streams shouldn't die easily.
          // We can emit the last known cache if available, but here we just log.
        });
  }

  Stream<List<Student>> subscribeToStudents() {
    return _client
        .from('students')
        .stream(primaryKey: ['id'])
        .map((data) {
          final list = data.map((e) => Student.fromJson(e)).toList();
          return list;
        })
        .handleError((error) {
          print('❌ Stream Error (Students): $error');
        });
  }

  Stream<List<Message>> subscribeToMessages() {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .map((data) => data.map((e) => Message.fromJson(e)).toList())
        .handleError((error) {
          print('❌ Stream Error (Messages): $error');
        });
  }

  Stream<List<ChatMessage>> subscribeToChatMessages({String? conversationId, required String studentId}) {
    // SECURITY NOTE: RLS (Row Level Security) is currently enabled in supabase_migration_chat_messages.sql
    // but policies are open (USING true).
    // For production, change policies to:
    // "id IN (SELECT auth.uid() FROM students WHERE ...) OR conversationId LIKE '%' || auth.uid() || '%'"
    
    // Using .stream() automatically handles channel creation/destruction on listen/cancel.
    
    if (conversationId != null && conversationId.isNotEmpty) {
      print('📡 Subscribing to chat messages for conversation: $conversationId');
      return _client
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('conversationId', conversationId)
          .order('createdAt')
          .map((data) {
            return data.map((e) => ChatMessage.fromJson(e)).toList();
          })
          .handleError((error) {
             print('❌ [SupabaseSubscription] Error for $conversationId: $error');
             // Signal through the stream that an error happened
             throw error; 
          });
    } else {
      print('📡 Subscribing to all chat messages');
      return _client
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .order('createdAt')
          .map((data) {
            return data.map((e) => ChatMessage.fromJson(e)).toList();
          })
          .handleError((error) {
             print('❌ [SupabaseSubscription] Error: $error');
             throw error;
          });
    }
  }

  void unsubscribeFromChatMessages() {
    // When using .stream(), cancelling the subscription in the UI layer 
    // automatically leaves the channel. No manual cleanup needed here.
    // This method is kept for API compatibility.
  }

  // Students
  Future<List<Student>> loadStudents({int? limit, int? offset}) async {
    return _safeExecution(() async {
      if (limit == null && offset == null && _studentsCache != null) {
        print('✅ Serving students from cache');
        return _studentsCache!;
      } else {
        print('🔄 Loading students from Supabase');
      }
      final builder = _client.from('students').select();
      final response = limit != null && offset != null
          ? await builder.range(offset, offset + limit - 1)
          : limit != null
          ? await builder.limit(limit)
          : await builder;
      final list = response.map((e) => Student.fromJson(e)).toList();

      if (limit == null && offset == null) {
        _studentsCache = list;
      }
      return list;
    }, 'loadStudents');
  }

  Future<void> saveStudents(List<Student> students) async {
    return _safeExecution(() async {
      final data = students.map((s) {
        final json = s.toJson();
        json.remove('teacherId'); // 🔧 Hotfix for missing column in DB
        return json;
      }).toList();
      await _client.from('students').upsert(data, onConflict: 'id');
    }, 'saveStudents');
  }

  Future<void> addStudent(Student student) async {
    return _safeExecution(() async {
      // Use upsert instead of insert to handle network retries gracefully
      final json = student.toJson();
      json.remove('teacherId'); // 🔧 Hotfix for missing column in DB
      await _client.from('students').upsert(json, onConflict: 'id');
      print('✅ Student added/upserted to Supabase successfully');
    }, 'addStudent');
  }

  Future<void> updateStudent(Student student) async {
    return _safeExecution(() async {
      final json = student.toJson();
      json.remove('id'); // ID cannot be updated (primary key)
      json.remove('teacherId'); // 🔧 Hotfix for missing column in DB
      
      await _client
          .from('students')
          .update(json)
          .eq('id', student.id);
      print('✅ Student updated in Supabase successfully: ${student.id}');
    }, 'updateStudent');
  }

  Future<void> updateStudentPrayers({
    required String studentId,
    required List<List<String>> prayers,
    required List<String> prayerDates,
  }) async {
    return _safeExecution(() async {
      await _client
          .from('students')
          .update({'prayers': prayers, 'prayerDates': prayerDates})
          .eq('id', studentId);
      print('✅ Student prayers updated in Supabase for $studentId');
    }, 'updateStudentPrayers');
  }

  // Teachers
  Future<List<Teacher>> loadTeachers({int? limit, int? offset}) async {
    return _safeExecution(() async {
      if (limit == null && offset == null && _teachersCache != null) {
        print('✅ Serving teachers from cache');
        return _teachersCache!;
      } else {
        print('🔄 Loading teachers from Supabase');
      }
      final builder = _client.from('teachers').select();
      final response = limit != null && offset != null
          ? await builder.range(offset, offset + limit - 1)
          : limit != null
          ? await builder.limit(limit)
          : await builder;
      final list = response.map((e) => Teacher.fromJson(e)).toList();
      if (limit == null && offset == null) {
        _teachersCache = list;
      }
      return list;
    }, 'loadTeachers');
  }

  Future<void> upsertTeachers(List<Teacher> teachers) async {
    return _safeExecution(() async {
      final data = teachers.map((t) => t.toJson()).toList();
      await _client.from('teachers').upsert(data, onConflict: 'id');
    }, 'upsertTeachers');
  }

  Future<void> addTeacher(Teacher teacher) async {
    return _safeExecution(() async {
      // Use upsert instead of insert to handle network retries gracefully
      // and prevent crashes on duplicate entries if the user retries.
      await _client.from('teachers').upsert(teacher.toJson(), onConflict: 'id');
      print('✅ Teacher added/upserted to Supabase successfully');
    }, 'addTeacher');
  }

  Future<void> updateTeacher(Teacher teacher) async {
    return _safeExecution(() async {
      await _client
          .from('teachers')
          .update(teacher.toJson())
          .eq('id', teacher.id!);
    }, 'updateTeacher');
  }

  Future<void> deleteTeacher(String teacherId) async {
    return _safeExecution(() async {
      await _client.from('teachers').delete().eq('id', teacherId);
      print('✅ Teacher deleted from Supabase');
    }, 'deleteTeacher');
  }

  Future<void> deleteStudent(String studentId) async {
    return _safeExecution(() async {
      await _client.from('students').delete().eq('id', studentId);
      print('✅ Student deleted from Supabase');
    }, 'deleteStudent');
  }

  // Messages
  Future<List<Message>> loadMessages() async {
    return _safeExecution(() async {
      if (_messagesCache != null) return _messagesCache!;
      final response = await _client.from('messages').select();
      _messagesCache = response.map((e) => Message.fromJson(e)).toList();
      return _messagesCache!;
    }, 'loadMessages');
  }

  Future<void> saveMessages(List<Message> messages) async {
    return _safeExecution(() async {
      final data = messages.map((m) => m.toJson()).toList();
      await _client.from('messages').upsert(data, onConflict: 'id');
    }, 'saveMessages');
  }

  Future<List<ChatMessage>> loadChatMessages({
    required String conversationId,
    int limit = 30,
    int offset = 0,
  }) async {
    // SECURITY NOTE: Ensure that the authenticated user part of 'conversationId'
    // matches their auth.uid() if RLS is hardened.
    return _safeExecution(() async {
      final response = await _client
          .from('chat_messages')
          .select()
          .eq('conversationId', conversationId)
          .order('createdAt', ascending: false) // Newest first
          .range(offset, offset + limit - 1);
      
      return response.map((e) => ChatMessage.fromJson(e)).toList();
    }, 'loadChatMessages');
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    // SECURITY NOTE: In production, RLS should verify that message.senderId == auth.uid()
    return _safeExecution(() async {
      final jsonData = message.toJson();
      // Force status to "sent" (1) when saving to cloud
      jsonData['status'] = 1; 
      
      print('💾 Saving chat message to Supabase: ${message.id} (conversation: ${message.conversationId})');
      
      // Use upsert to handle potential retries and concurrency gracefully
      await _client
          .from('chat_messages')
          .upsert(jsonData, onConflict: 'id');
          
      print('✅ Message saved successfully: ${message.id}');
    }, 'saveChatMessage');
  }

  Future<void> saveChatMessages(List<ChatMessage> messages) async {
    return _safeExecution(() async {
      await _client
          .from('chat_messages')
          .upsert(messages.map((m) => m.toJson()).toList(), onConflict: 'id');
    }, 'saveChatMessages');
  }

  Future<void> addMessage(Message message) async {
    return _safeExecution(() async {
      await _client.from('messages').insert(message.toJson());
    }, 'addMessage');
  }

  Future<void> invokeSendNotification({
    required String recipientId,
    required String message,
  }) async {
    return _safeExecution(() async {
      await _client.functions.invoke(
        'send-notification',
        body: {'recipientId': recipientId, 'message': message},
      );
      print('✅ Invoked send-notification function for recipient: $recipientId');
    }, 'invokeSendNotification');
  }

  Future<List<Message>> loadMessagesForConversation(
    String studentId,
    String teacherName,
  ) async {
    return _safeExecution(() async {
      final response = await _client
          .from('messages')
          .select()
          .or(
            'and(sender_id.eq.$studentId,receiver_name.eq.$teacherName),and(sender_name.eq.$teacherName,receiver_id.eq.$studentId)',
          )
          .order('timestamp', ascending: true);
      return response.map((e) => Message.fromJson(e)).toList();
    }, 'loadMessagesForConversation');
  }

  // Auth methods
  Future<Map<String, dynamic>?> signIn(String email, String password) async {
    return _safeExecution(() async {
      // Since we bypassed Supabase Auth for student/teacher creation,
      // we must check the tables directly for email/password match.
      
      // Parallel checks for student and teacher
      final studentFuture = _client
          .from('students')
          .select()
          .eq('email', email)
          .eq('password', password)
          .maybeSingle();
          
      final teacherFuture = _client
          .from('teachers')
          .select()
          .eq('email', email)
          .eq('password', password)
          .maybeSingle();

      final results = await Future.wait([studentFuture, teacherFuture]);
      final studentResponse = results[0];
      final teacherResponse = results[1];

      if (studentResponse != null) {
        return {
          'role': 'student',
          'studentId': studentResponse['id'],
          'userId': studentResponse['id'], 
        };
      } else if (teacherResponse != null) {
        return {
          'role': 'teacher',
          'teacherId': teacherResponse['id'],
          'userId': teacherResponse['id'],
        };
      }
      
      // If neither, try Supabase Auth (for backwards compatibility/admin)
      try {
        final authResponse = await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (authResponse.user != null) {
           return {
             'role': 'admin', // Assume admin if only in Auth but not tables
             'userId': authResponse.user!.id,
           };
        }
      } catch (e) {
        // Ignored, user doesn't exist in Auth either
      }

      return null;
    }, 'signIn');
  }

  /// Updates a user's auth data (email/password) using an edge function.
  /// This requires admin privileges and should be handled by a secure function.
  Future<void> updateAuthUserById(
    String userId, {
    String? email,
    String? password,
  }) async {
    return _safeExecution(() async {
      final Map<String, dynamic> body = {'userId': userId};
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (password != null && password.isNotEmpty) body['password'] = password;

      if (body.length <= 1) return; // Nothing to update

      await _client.functions.invoke('update-user', body: body);
      print('✅ Invoked "update-user" function for user ID: $userId');
    }, 'updateAuthUserById');
  }

  Future<void> signOut() async {
    return _safeExecution(() async {
      await _client.auth.signOut();
    }, 'signOut');
  }

  Future<bool> isUserSignedIn() async {
    return _client.auth.currentUser != null;
  }

  // Sign up methods
  Future<Map<String, dynamic>?> signUp(
    String email,
    String password,
    String role, {
    String? name,
    String? phone,
    String? teacherName,
    String? teacherPhone,
  }) async {
    return _safeExecution(() async {
      AuthResponse response;
      try {
        response = await _client.auth.signUp(
          email: email,
          password: password,
        );
      } on AuthException catch (e) {
        if (e.message.toLowerCase().contains('already registered') || 
            e.message.toLowerCase().contains('unique')) {
           print('⚠️ User exists, attempting recovery via login...');
           final loginRes = await _client.auth.signInWithPassword(email: email, password: password);
           response = loginRes; 
        } else {
           rethrow;
        }
      }

      if (response.user != null) {
        if (role == 'student') {
          final student = Student(
            id: response.user!.id,
            name: name ?? '',
            phone: phone ?? '',
            teacherName: teacherName ?? '',
            teacherPhone: teacherPhone ?? '',
            email: email,
            password: password,
            points: 0,
            attendance: [],
            prayers: [],
            prayerDates: [],
            memorization: [],
            dailyPointsAdded: 0,
            lastPointsDate: '',
          );
          await addStudent(student);
        } else if (role == 'teacher') {
          final teacher = Teacher(
            id: response.user!.id, // Assign the user's ID to the teacher object
            name: name ?? '',
            number: phone ?? '',
            email: email,
            password: password,
          );
          await upsertTeachers([
            teacher,
          ]); // Use the correct method 'upsertTeachers'
        }
        return {
          'role': role,
          'user': response.user,
          'userId': response.user?.id,
        };
      }
      return null;
    }, 'signUp');
  }

  // Sync methods for offline/online
  Future<void> syncLocalToCloud({
    List<Map<String, dynamic>>? teachers,
    List<Map<String, dynamic>>? students,
    List<Map<String, dynamic>>? messages,
    List<Map<String, dynamic>>? chatMessages,
  }) async {
    return _safeExecution(() async {
      // Sync teachers
      if (teachers != null && teachers.isNotEmpty) {
        print('🔄 Syncing ${teachers.length} teachers to cloud...');
        // Clean data: ensure string keys
        final cleanedTeachers = teachers
            .map(
              (t) => t.map(
                (k, v) => MapEntry(
                  k.toString(),
                  v is DateTime ? v.toIso8601String() : v,
                ),
              ),
            )
            .toList();
        await _client
            .from('teachers')
            .upsert(
              cleanedTeachers,
              onConflict: 'id',
            ); // Use 'id' as it's the primary key
        print('✅ Teachers synced successfully');
      }

      // Sync students
      if (students != null && students.isNotEmpty) {
        print('🔄 Syncing ${students.length} students to cloud...');
        // Clean data: ensure string keys and handle potential type issues from JSON decoding.
        final cleanedStudents = students
            .map(
              (s) {
                 final m = Map<String, dynamic>.from(
                   s.map((k, v) => MapEntry(k.toString(), v)),
                 );
                 m.remove('teacherId'); // 🔧 Hotfix for missing column in DB
                 return m;
              }
            )
            .toList();

        await _client
            .from('students')
            .upsert(cleanedStudents, onConflict: 'id');
        print('✅ Students synced successfully');
      }

      // Sync messages
      if (messages != null && messages.isNotEmpty) {
        print('🔄 Syncing ${messages.length} messages to cloud...');
        final cleanedMessages = messages
            .map(
              (m) => m.map(
                (k, v) => MapEntry(
                  k.toString(),
                  v is DateTime ? v.toIso8601String() : v,
                ),
              ),
            )
            .toList();
        await _client
            .from('messages')
            .upsert(cleanedMessages, onConflict: 'id');
        print('✅ Messages synced successfully');
      }

      // Sync chat_messages
      if (chatMessages != null && chatMessages.isNotEmpty) {
        print('🔄 Syncing ${chatMessages.length} chat_messages to cloud...');
        final cleanedChatMessages = chatMessages
            .map(
              (m) {
                final cleaned = m.map(
                  (k, v) => MapEntry(
                    k.toString(),
                    v is DateTime ? v.toIso8601String() : v,
                  ),
                );
                cleaned['status'] = 1; // Always mark as 'sent' (1) when pushed to cloud
                return cleaned;
              },
            )
            .toList();
            
        await _client
            .from('chat_messages')
            .upsert(cleanedChatMessages, onConflict: 'id');
        print('✅ ChatMessages synced successfully');
      }
    }, 'syncLocalToCloud');
  }

  Future<Map<String, List<Map<String, dynamic>>>> syncCloudToLocal({
    int teachersLimit = 1000,
    int teachersOffset = 0,
    int studentsLimit = 1000,
    int studentsOffset = 0,
    int messagesLimit = 1000,
    int messagesOffset = 0,
  }) async {
    return _safeExecution(() async {
      final teachersResp = await _client
          .from('teachers')
          .select()
          .range(teachersOffset, teachersOffset + teachersLimit - 1);
      final studentsResp = await _client
          .from('students')
          .select()
          .range(studentsOffset, studentsOffset + studentsLimit - 1);
      final messagesResp = await _client
          .from('messages')
          .select()
          .range(messagesOffset, messagesOffset + messagesLimit - 1);

      return {
        'teachers': (teachersResp as List).cast<Map<String, dynamic>>(),
        'students': (studentsResp as List).cast<Map<String, dynamic>>(),
        'messages': (messagesResp as List).cast<Map<String, dynamic>>(),
      };
    }, 'syncCloudToLocal');
  }

  Future<void> savePrayerRecord({
    required String studentId,
    required String date,
    required List<String> prayers,
  }) async {
    return _safeExecution(() async {
      // Use upsert for simplicity and robustness. It combines insert and update.
      await _client.from('prayer_records').upsert({
        'student_id': studentId,
        'date': date,
        'prayers': prayers,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'student_id, date');
      print(
        '✅ Prayer record saved via SupabaseService for $studentId on $date',
      );
    }, 'savePrayerRecord');
  }

  Future<List<Map<String, dynamic>>> getPrayerRecords({
    required String studentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return _safeExecution(() async {
      final records = await _client
          .from('prayer_records')
          .select()
          .eq('student_id', studentId)
          .gte('date', startDate.toIso8601String().split('T')[0])
          .lte('date', endDate.toIso8601String().split('T')[0])
          .order('date', ascending: false);

      print('📊 Retrieved ${records.length} prayer records for period');
      return List<Map<String, dynamic>>.from(records);
    }, 'getPrayerRecords');
  }

  // --- Adhkar (Ahadith) ---
  Stream<List<AdhkarCategory>> subscribeToAdhkarCategories() {
    return _client
        .from('adhkar_categories')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => AdhkarCategory.fromJson(e)).toList());
  }

  Future<List<AdhkarCategory>> loadAdhkarCategories() async {
    return _safeExecution(() async {
      final response = await _client
          .from('adhkar_categories')
          .select()
          .order('created_at', ascending: true);
      return response.map((e) => AdhkarCategory.fromJson(e)).toList();
    }, 'loadAdhkarCategories');
  }

  Future<void> addAdhkarCategory(AdhkarCategory category) async {
    return _safeExecution(() async {
      final json = category.toJson();
      if (json['id'] == null || json['id'].toString().isEmpty) {
        json['id'] = _uuid.v4();
      }
      await _client.from('adhkar_categories').upsert(json, onConflict: 'id');
      print('✅ Adhkar category added/upserted to Supabase successfully');
    }, 'addAdhkarCategory');
  }

  Future<void> deleteAdhkarCategory(String id) async {
    return _safeExecution(() async {
      await _client.from('adhkar_categories').delete().eq('id', id);
      print('✅ Adhkar category deleted from Supabase');
    }, 'deleteAdhkarCategory');
  }

  Stream<List<Dhikr>> subscribeToAdhkarForCategory(String categoryId) {
    return _client
        .from('adhkar')
        .stream(primaryKey: ['id'])
        .eq('category_id', categoryId)
        .order('created_at', ascending: true)
        .map((data) => data.map((e) => Dhikr.fromJson(e)).toList());
  }

  Future<List<Dhikr>> loadAdhkarForCategory(String categoryId) async {
    return _safeExecution(() async {
      final response = await _client
          .from('adhkar')
          .select()
          .eq('category_id', categoryId)
          .order('created_at', ascending: true);
      return response.map((e) => Dhikr.fromJson(e)).toList();
    }, 'loadAdhkarForCategory');
  }

  Future<void> addDhikr(Dhikr dhikr) async {
    return _safeExecution(() async {
      final json = dhikr.toJson();
      if (json['id'] == null || json['id'].toString().isEmpty) {
        json['id'] = _uuid.v4();
      }
      await _client.from('adhkar').upsert(json, onConflict: 'id');
      print('✅ Dhikr added to Supabase successfully');
    }, 'addDhikr');
  }

  Future<void> deleteDhikr(String id) async {
    return _safeExecution(() async {
      await _client.from('adhkar').delete().eq('id', id);
      print('✅ Dhikr deleted from Supabase');
    }, 'deleteDhikr');
  }

  // --- Lessons ---
  Stream<List<Lesson>> subscribeToLessons() {
    return _client
        .from('lessons')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => Lesson.fromJson(e)).toList());
  }

  Future<List<Lesson>> loadLessons() async {
    return _safeExecution(() async {
      final response = await _client
          .from('lessons')
          .select()
          .order('created_at', ascending: false);
      return response.map((e) => Lesson.fromJson(e)).toList();
    }, 'loadLessons');
  }

  Future<void> addLesson(Lesson lesson) async {
    return _safeExecution(() async {
      final json = lesson.toJson();
      if (json['id'] == null || json['id'].toString().isEmpty) {
        json['id'] = _uuid.v4();
      }
      await _client.from('lessons').upsert(json, onConflict: 'id');
      print('✅ Lesson added to Supabase successfully');
    }, 'addLesson');
  }

  Future<void> deleteLesson(String id) async {
    return _safeExecution(() async {
      await _client.from('lessons').delete().eq('id', id);
      print('✅ Lesson deleted from Supabase');
    }, 'deleteLesson');
  }

  /// Uploads a video file and its generated thumbnail to Supabase
  /// Returns a map with 'videoUrl' and 'thumbnailUrl'
  Future<Map<String, String>> uploadLessonVideoWithThumbnail(File videoFile, String fileName) async {
    return _safeExecution(() async {
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoPath = '${timestamp}_$cleanName';
      final thumbPath = '${timestamp}_${cleanName.split('.').first}.jpg';

      print('🚀 Starting video upload for $videoPath');

      // 1. Upload Video
      await _client.storage.from('lessons').upload(
        videoPath,
        videoFile,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      final videoUrl = _client.storage.from('lessons').getPublicUrl(videoPath);

      // 2. Generate Thumbnail
      print('📸 Generating thumbnail...');
      try {
        final thumbnailFile = await VideoCompress.getFileThumbnail(
          videoFile.path,
          quality: 50,
          position: -1,
        );

        String? thumbnailUrl;
        if (thumbnailFile != null) {
          print('📤 Uploading thumbnail...');
          await _client.storage.from('lessons').upload(
            'thumbnails/$thumbPath',
            thumbnailFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
          thumbnailUrl = _client.storage.from('lessons').getPublicUrl('thumbnails/$thumbPath');
        }

        print('✅ Upload complete. Video: $videoUrl, Thumb: $thumbnailUrl');
        return {
          'videoUrl': videoUrl,
          'thumbnailUrl': thumbnailUrl ?? '',
        };
      } catch (e) {
        print('⚠️ Thumbnail generation failed: $e');
        return {
          'videoUrl': videoUrl,
          'thumbnailUrl': '',
        };
      }
    }, 'uploadLessonVideoWithThumbnail');
  }

  /// Downloads a video from a URL and saves it to the gallery
  Future<void> downloadVideo(String url, String fileName, Function(double) onProgress) async {
    return _safeExecution(() async {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$fileName';

      print('📥 Starting download from $url to $savePath');
      
      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      print('💾 Saving to gallery...');
      await Gal.putVideo(savePath);
      
      // Cleanup temp file
      final file = File(savePath);
      if (await file.exists()) await file.delete();
      
      print('✅ Video saved successfully to gallery');
    }, 'downloadVideo');
  }
}
