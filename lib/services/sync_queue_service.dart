import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:yaman/models/chat_message.dart';
import 'package:yaman/services/connectivity_service.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/services/storage_service.dart';

class SyncQueueService {
  SyncQueueService._internal();
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  
  // Maximum retry attempts before marking as failed
  static const int maxRetries = 10;
  
  // Callback for permanent failures (can be set by UI)
  Function(String type, Map<String, dynamic> data, String error)? onPermanentFailure;

  late final Box<Map> _box;
  late final Box<Map> _failedBox;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>('sync_queue');
    _failedBox = await Hive.openBox<Map>('failed_syncs');

    await ConnectivityService().initialize();
    
    // Trigger sync on connect, throttled
    ConnectivityService().connectivityStream.listen((online) {
      if (online) {
        _scheduleSync();
      }
    });

    // Periodic Sync (Every 5 minutes) to ensure data consistency
    Timer.periodic(const Duration(minutes: 5), (_) {
      if (ConnectivityService().isOnlineNow) { // I need to expose isOnlineNow or use async check
        _scheduleSync();
      }
    });
  }

  Timer? _syncThrottle;
  void _scheduleSync() {
    if (_syncThrottle?.isActive ?? false) return;
    
    _syncThrottle = Timer(const Duration(seconds: 10), () {
      processQueue();
    });
  }

  Future<void> dispose() async {
    // no-op
  }

  int getQueueSize() => _box.length;

  Future<void> addOperation(String type, Map<String, dynamic> data) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final op = {
      'id': id,
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
      'nextRetryAt': DateTime.now().toIso8601String(),
    };
    await _box.put(id, op);
  }

  Future<void> clearOperation(String id) async {
    await _box.delete(id);
  }

  Future<void> retryOperation(String id) async {
    final op = _box.get(id);
    if (op == null) return;
    await _processSingle(op);
  }

  Future<void> processQueue() async {
    final ops = _box.values.toList();
    for (final op in ops) {
      if (op['nextRetryAt'] != null) {
        final nextRetry = DateTime.parse(op['nextRetryAt']);
        if (DateTime.now().isBefore(nextRetry)) {
           continue; // Skip if too early
        }
      }
      await _processSingle(op);
    }
  }

  Future<void> _markChatMessagesAsFailed(Map<String, dynamic> data) async {
    try {
      final storage = StorageService();
      final list = (data['list'] as List).cast<Map<String, dynamic>>();
      
      for (var msgJson in list) {
        final msgId = msgJson['id'] as String;
        final convId = msgJson['conversationId'] as String? ?? '';
        
        // Use the robust method we just added to StorageService!
        await storage.updateMessageStatusExternal(
          messageId: msgId,
          conversationId: convId,
          status: MessageStatus.failed,
        );
      }
      
      print('✅ Marked ${list.length} chat messages as failed via StorageService');
    } catch (e) {
      print('❌ Error marking messages as failed: $e');
    }
  }

  /// Manually retry messages from the 'failed_syncs' box
  Future<void> retryFailedMessages() async {
    final failedOps = _failedBox.values.toList();
    if (failedOps.isEmpty) {
      print('ℹ️ No failed messages to retry.');
      return;
    }

    print('🔄 Retrying ${failedOps.length} failed operations...');
    for (final op in failedOps) {
       final id = op['id'] as String;
       // Reset retry count and move back to main queue
       op['retryCount'] = 0;
       op['nextRetryAt'] = DateTime.now().toIso8601String();
       
       await _box.put(id, op);
       await _failedBox.delete(id);
    }
    
    // Trigger processing
    await processQueue();
  }

  Future<void> _processSingle(Map op) async {
    final supabase = SupabaseService();
    final type = op['type'] as String? ?? '';
    final data = (op['data'] as Map).cast<String, dynamic>();
    final id = op['id'] as String? ?? '';
    final retryCount = (op['retryCount'] as int?) ?? 0;

    Future<void> onFail(String error) async {
      // Check if max retries exceeded
      if (retryCount >= maxRetries) {
        print('❌ PERMANENT FAILURE: Operation $id ($type) failed after $maxRetries attempts');
        print('   Error: $error');
        
        // 1. Mark chat messages as failed in their respective UI/Storage
        if (type == 'save_chat_messages') {
          await _markChatMessagesAsFailed(data);
        }
        
        // 2. Move to Failed Box instead of just deleting
        op['permanentError'] = error;
        op['failedAt'] = DateTime.now().toIso8601String();
        await _failedBox.put(id, op);
        
        // 3. Notify UI if callback is set
        onPermanentFailure?.call(type, data, error);
        
        // 4. Remove from main queue
        await clearOperation(id);
        return;
      }
      
      // Improved Backoff:
      // Try 1-3: fast (5s, 15s, 30s)
      // Try 4-7: medium (1m, 2m, 5m, 10m)
      // Try 8-10: slow (30m, 1h, 2h)
      int backoffSeconds;
      if (retryCount < 3) {
        backoffSeconds = [5, 15, 30][retryCount];
      } else if (retryCount < 7) {
        backoffSeconds = [60, 120, 300, 600][retryCount - 3];
      } else {
        backoffSeconds = [1800, 3600, 7200][retryCount - 7];
      }
      
      final next = DateTime.now().add(Duration(seconds: backoffSeconds));
      
      op['retryCount'] = retryCount + 1;
      op['nextRetryAt'] = next.toIso8601String();
      await _box.put(id, op);
      
      print('⚠️ Retry $retryCount/$maxRetries for $type. Next attempt in ${backoffSeconds}s at ${next.toLocal()}');
    }

    try {
      switch (type) {
        case 'save_teachers':
          final list = (data['list'] as List).cast<Map<String, dynamic>>();
          await supabase.syncLocalToCloud(
            teachers: list,
          );
          await clearOperation(id);
          break;
        case 'save_students':
          final list = (data['list'] as List).cast<Map<String, dynamic>>();
          await supabase.syncLocalToCloud(
            students: list,
          );
          await clearOperation(id);
          break;
        case 'save_messages':
          final list = (data['list'] as List).cast<Map<String, dynamic>>();
          await supabase.syncLocalToCloud(
            messages: list,
          );
          await clearOperation(id);
          break;

        case 'save_chat_messages':
          final list = (data['list'] as List).cast<Map<String, dynamic>>();
          await supabase.syncLocalToCloud(
            chatMessages: list,
          );
          await clearOperation(id);
          break;
        case 'save_prayer_record':
          final studentId = data['student_id'] as String;
          final date = data['date'] as String;
          final prayers = (data['prayers'] as List).cast<String>();
          await supabase.savePrayerRecord(
              studentId: studentId, date: date, prayers: prayers);
          await clearOperation(id);
          break;

        // رفع أستاذ أو طالب مباشرةً بدون Auth
        case 'upsert_teacher':
          final tData = data.cast<String, dynamic>();
          await supabase.syncLocalToCloud(teachers: [tData]);
          await clearOperation(id);
          break;

        case 'upsert_student':
          final sData = data.cast<String, dynamic>();
          await supabase.syncLocalToCloud(students: [sData]);
          await clearOperation(id);
          break;

        case 'update_student':
          await supabase.syncLocalToCloud(students: [data]);
          await clearOperation(id);
          break;

        case 'update_teacher':
          await supabase.syncLocalToCloud(teachers: [data]);
          await clearOperation(id);
          break;
        case 'create_teacher_full':
          final teacherData = (data['teacher'] as Map).cast<String, dynamic>();
          final password = data['password'] as String;
          final tempId = teacherData['id'];

          // 1. Sign up in Supabase (Cloud)
          final authResponse = await supabase.signUp(
            teacherData['email'],
            password,
            'teacher',
            name: teacherData['name'],
            phone: teacherData['number'],
          );

          if (authResponse != null && authResponse['userId'] != null) {
             final realId = authResponse['userId'] as String;
             print('✅ Sync: Teacher synced. TempID: $tempId -> RealID: $realId');
             
             // 2. Resolve ID locally (Migration)
             await StorageService().resolveTempId(
               oldId: tempId, 
               newId: realId, 
               collection: 'teachers',
             );
          }
          await clearOperation(id);
          break;

        case 'create_student_full':
          final studentData = (data['student'] as Map).cast<String, dynamic>();
          final password = data['password'] as String;
          final tempId = studentData['id'];

          final authResponse = await supabase.signUp(
            studentData['email'],
            password,
            'student',
            name: studentData['name'],
            phone: studentData['phone'],
            teacherName: studentData['teacherName'],
            teacherPhone: studentData['teacherPhone'],
          );

          if (authResponse != null && authResponse['userId'] != null) {
             final realId = authResponse['userId'] as String;
             print('✅ Sync: Student synced. TempID: $tempId -> RealID: $realId');
             
             // 2. Resolve ID locally
             await StorageService().resolveTempId(
               oldId: tempId, 
               newId: realId, 
               collection: 'students',
             );
          }
          await clearOperation(id);
          break;

        default:
          await clearOperation(id);
      }
    } catch (e, st) {
      print('❌ SyncQueue Error processing op $id ($type): $e');
      print(st);
      await onFail(e.toString());
    }
  }
}