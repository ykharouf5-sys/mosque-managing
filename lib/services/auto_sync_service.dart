import 'dart:async';
import 'package:yaman/services/connectivity_service.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/services/sync_queue_service.dart';
import 'package:yaman/services/local_notification_service.dart';
import 'package:yaman/services/active_conversation_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// AutoSyncService — يزامن كل البيانات تلقائياً مع Supabase.
/// يعمل عند:
///  1. بدء التطبيق
///  2. استعادة الإنترنت
///  3. كل 3 دقائق بشكل دوري
class AutoSyncService {
  AutoSyncService._internal();
  static final AutoSyncService _instance = AutoSyncService._internal();
  factory AutoSyncService() => _instance;

  final _storage = StorageService();
  final _supabase = SupabaseService();
  Timer? _periodicTimer;
  bool _isSyncing = false;
  StreamSubscription? _chatSubscription;

  /// استدعِ هذه الدالة مرة واحدة في main()
  Future<void> initialize() async {
    // 1. مزامنة فورية عند البدء (بعد ثانيتين لإعطاء التطبيق وقت للتهيئة)
    Future.delayed(const Duration(seconds: 2), () => _runSync());

    // 2. مزامنة تلقائية عند استعادة الإنترنت
    ConnectivityService().connectivityStream.listen((online) {
      if (online) _runSync();
    });

    // 3. مزامنة دورية كل 3 دقائق
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (ConnectivityService().isOnlineNow) _runSync();
    });

    // 4. Global listener for chat messages to show notifications
    _setupGlobalChatListener();
  }

  Future<void> _setupGlobalChatListener() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('currentUserId');
    if (currentUserId == null) return;

    _chatSubscription?.cancel();
    _chatSubscription = _supabase
        .subscribeToChatMessages(studentId: '') // Empty studentId means listen to all for now
        .listen((messages) {
      if (messages.isEmpty) return;

      // When listening to stream, we might get the full list or recent changes.
      // Usually, we want to know what is NEW. 
      // A simple way is to check the last message, though 'subscribeToChatMessages'
      // returns the active query. Let's process the newest message.
      // Assuming messages are ordered oldest to newest or newest to oldest. 
      // Supabase stream returns all matching rows. This might be heavy if not limited.
      // Since it's a global listener, we only care about real-time INSERTs ideally.
      // Alternatively, relying on the 'createdAt' to see if it's within the last 5 seconds.
      
      final latestMessage = messages.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
      
      if (latestMessage.senderId != currentUserId) {
         // Check if it's a recent message (within last 10 seconds)
         if (DateTime.now().difference(latestMessage.createdAt).inSeconds < 10) {
             if (!ActiveConversationTracker().isConversationActive(latestMessage.conversationId)) {
                LocalNotificationService().showChatMessageNotification(
                  senderName: latestMessage.senderName,
                  messageText: latestMessage.text,
                  conversationId: latestMessage.conversationId,
                );
             }
         }
      }
    }, onError: (e) {
      print('Global Chat Listener Error: $e');
    });
  }

  void dispose() {
    _periodicTimer?.cancel();
    _chatSubscription?.cancel();
  }

  /// الدالة الرئيسية للمزامنة — تعمل في الخلفية بدون تعطيل الـ UI
  Future<void> _runSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final online = await ConnectivityService().checkRealConnectivity();
      if (!online) return;

      // 1. معالجة العمليات المعلقة في الـ Queue
      await SyncQueueService().processQueue();

      // 2. رفع البيانات المحلية للسحابة (Push)
      await _pushAllLocalData();

      // 3. سحب البيانات الجديدة من السحابة (Pull)
      await _pullCloudData();
    } catch (_) {
      // تجاهل الأخطاء — التطبيق يعمل بشكل طبيعي
    } finally {
      _isSyncing = false;
    }
  }

  /// رفع كل البيانات المحلية لـ Supabase دفعة واحدة
  Future<void> _pushAllLocalData() async {
    try {
      // قراءة الأساتذة المحليين ورفعهم
      final localTeachers = await _storage.loadTeachers();
      if (localTeachers.isNotEmpty) {
        await _supabase.syncLocalToCloud(
          teachers: localTeachers.map((t) => t.toJson()).toList(),
        );
      }
    } catch (_) {}

    try {
      // قراءة الطلاب المحليين ورفعهم
      final localStudents = await _storage.loadStudents();
      if (localStudents.isNotEmpty) {
        await _supabase.syncLocalToCloud(
          students: localStudents.map((s) => s.toJson()).toList(),
        );
      }
    } catch (_) {}
  }

  /// سحب البيانات الجديدة من السحابة وحفظها محلياً
  Future<void> _pullCloudData() async {
    try {
      final cloudTeachers = await _supabase.loadTeachers();
      if (cloudTeachers.isNotEmpty) {
        await _storage.saveTeachers(cloudTeachers);
      }
    } catch (_) {}

    try {
      final cloudStudents = await _supabase.loadStudents();
      if (cloudStudents.isNotEmpty) {
        await _storage.saveStudents(cloudStudents);
      }
    } catch (_) {}
  }

  /// استدعِها مباشرةً بعد إضافة/تعديل أستاذ أو طالب
  Future<void> syncNow() async {
    _isSyncing = false; // إعادة تعيين لضمان التشغيل
    await _runSync();
  }
}
