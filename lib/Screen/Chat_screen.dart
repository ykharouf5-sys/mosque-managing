import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaman/models/chat_message.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/services/connectivity_service.dart';
import 'package:yaman/services/active_conversation_tracker.dart';
import 'package:yaman/services/local_notification_service.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/utils/responsive_helper.dart';


class ChatScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String teacherId;
  final String teacherName;
  final bool isTeacher;

  const ChatScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.teacherName,
    required this.isTeacher,
  });


  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SupabaseService _supabase = SupabaseService();
  final StorageService _storage = StorageService();
  final ConnectivityService _connectivity = ConnectivityService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  String? _currentUserId;
  String? _currentUserName;
  bool _isLoading = true;
  bool _isLoadingMore = false; // Pagination
  bool _hasMore = true;        // Pagination
  final int _limit = 30;             // Pagination
  int _offset = 0;             // Pagination

  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _messageSubscription;
  Timer? _pollingTimer;
  Timer? _subscriptionDebouncer;
  bool _isPolling = false;

  // New state for private chat
  late final String _conversationId;
  late final String _recipientName;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeChat();
  }

  void _onScroll() {
    // If scrolled to top (pixels == 0) for reverse list OR pixels == max for standard list?
    // Chat usually uses standard list but reversed logic?
    // _scrollToBottom() is used. So list is standard (Top=Oldest, Bottom=Newest).
    // So we want to load OLDER messages when user scrolls to TOP (pixels == 0).
    // And if `reverse: true` is used, then Top is "end" of list.
    // Let's assume standard list where top is 0.
    if (_scrollController.hasClients && _scrollController.position.pixels <= 100 && !_isLoadingMore && _hasMore) {
        _loadMoreMessages();
    }
  }

  /// Creates a consistent, sorted ID for a conversation between two users.
  String _createConversationId(String userId1, String userId2) {
    // Ensure currentUserId is not null before creating the ID to avoid 'unknown_user_something'
    final id1 = userId1.isEmpty ? (_currentUserId ?? 'pending') : userId1;
    final id2 = userId2.isEmpty ? (_currentUserId ?? 'pending') : userId2;
    
    final ids = [id1, id2]..sort();
    final cid = ids.join('_');
    print('🆔 Generated ConversationID: $cid (from participants: $userId1, $userId2)');
    return cid;
  }

  Future<void> _initializeChat() async {
    print('🎬 Initializing Chat: student=${widget.studentId}, teacher=${widget.teacherId}');
    await _loadCurrentUser(); // Loads current user's ID and name

    // Determine conversation participants from widget properties
    final isUserTeacher = await _isCurrentUserTeacher();
    
    var studentId = widget.studentId;
    var teacherId = widget.teacherId;

    // Robust ID resolving: If teacherId is missing (common scenario for students),
    // try to find it by name in local storage/cache.
    if (teacherId.isEmpty && widget.teacherName.isNotEmpty) {
       print('🔍 teacherId is missing, attempting to resolve by name: ${widget.teacherName}');
       final teacher = await _storage.getTeacherByName(widget.teacherName);
       if (teacher != null) {
          teacherId = teacher.id ?? '';
          print('✅ Resolved teacherId: $teacherId');
       } else {
          print('⚠️ Could not resolve teacherId for ${widget.teacherName}');
       }
    }
    
    // Reverse for teacher if studentId is missing? (Less likely but good for robustness)
    if (studentId.isEmpty && widget.studentName.isNotEmpty) {
       // We don't have getStudentByName yet, but let's assume IDs are usually provided for teachers.
    }

    _recipientName = isUserTeacher ? widget.studentName : widget.teacherName;
    _conversationId = _createConversationId(studentId, teacherId);

    // Set this conversation as active ASAP to filter incoming notifications
    ActiveConversationTracker().setActiveConversation(_conversationId);

    // 1. Initial Local Load (Fast)
    await _loadMessages(refresh: true);
    
    // UI is now ready with local data
    if (mounted) {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }

    // 2. Setup Listeners (Realtime/Connectivity) - Non-blocking
    _setupListeners();
    
    // Note: _loadMessages already triggers background sync via StorageService
  }

  // Get user role from shared preferences
  Future<bool> _isCurrentUserTeacher() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('currentUserRole');
    return role == 'teacher';
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('currentUserId');
    _currentUserName = prefs.getString('currentUserName');

    // Fallback if name is not in prefs
    if (_currentUserName == null && _currentUserId != null) {
      final role = prefs.getString('currentUserRole');
      if (role == 'student') {
        final student = (await _storage.loadStudents()).firstWhere(
          (s) => s.id == _currentUserId,
          orElse: () => null as dynamic,
        );
        _currentUserName = student.name ?? 'طالب';
      } else if (role == 'teacher') {
        final teacher = (await _storage.loadTeachers()).firstWhere(
          (t) => t.id == _currentUserId,
          orElse: () => null as dynamic,
        );
        _currentUserName = teacher.name ?? 'أستاذ';
      } else if (role == 'admin') {
        _currentUserName = 'مشرف';
      } else {
        _currentUserName = 'مستخدم';
      }
    }
  }

  Future<void> _loadMessages({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _hasMore = true;
    }

    // Load latest messages (DESC)
    final localMessagesDesc = await _storage.loadChatMessages(
      conversationId: _conversationId,
      limit: _limit,
      offset: _offset,
    );
    
    // Convert to ASC (Oldest -> Newest) for display
    final localMessagesAsc = localMessagesDesc.reversed.toList();

    setState(() {
      if (refresh) {
        _messages = localMessagesAsc;
      } else {
        _messages = localMessagesAsc;
      }
      // If we were waiting for first load, clear it now
      if (_isLoading) _isLoading = false;
    });

    // Try Cloud Sync for *Latest* if refreshing
    if (refresh) {
      try {
         // This also updates cache, so next load pulls fresh data
         // _storage.loadChatMessages triggers sync internally if online.
         // We don't need explicit call unless StorageService behavior changed.
         // StorageService calls _syncChatConversation internally now.
      } catch (e) {
        print('Error sync: $e');
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final nextOffset = _offset + _limit;
      final moreMessagesDesc = await _storage.loadChatMessages(
        conversationId: _conversationId,
        limit: _limit,
        offset: nextOffset,
      );

      if (moreMessagesDesc.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      final moreMessagesAsc = moreMessagesDesc.reversed.toList();
      
      // Keep scroll position relative to bottom?
      // Standard list: inserting at 0 shifts content down.
      // We want to keep viewing the same message.
      final double oldExt = _scrollController.position.maxScrollExtent;
      final double oldPos = _scrollController.position.pixels;

      setState(() {
        _messages.insertAll(0, moreMessagesAsc);
        _offset = nextOffset;
        _isLoadingMore = false;
      });
      
      // Restore scroll position attempt (wait for build?)
      // This is flaky without specific ScrollPhysics or reverse list.
      // Basic implementation: User will see jump.
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (_scrollController.hasClients) {
             final newExt = _scrollController.position.maxScrollExtent;
             _scrollController.jumpTo(oldPos + (newExt - oldExt));
         }
      });

    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _setupListeners() {
    // 1. Debounce Realtime Subscription
    _subscriptionDebouncer?.cancel();
    _subscriptionDebouncer = Timer(const Duration(milliseconds: 300), () {
        _subscribeActual();
    });

    // 2. Listen for connectivity changes to trigger sync/reconnect
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.connectivityStream.listen((isConnected) {
      if (isConnected && mounted) {
        print('🌐 Connectivity restored, syncing pending messages');
        _syncPendingMessages();
        // Reset retry count on connectivity restore to give Realtime another chance
        _subscriptionRetryCount = 0;
        if (_isPolling) {
          _setupListeners();
        }
      }
    });
  }

  int _subscriptionRetryCount = 0;
  static const int _maxRetries = 5;

  void _subscribeActual() {
    // If polling is active, stop it as we're trying to restore Realtime
    if (_isPolling) {
      _stopPolling();
    }

    // Listen for new messages for this specific conversation
    _messageSubscription?.cancel();
    
    print('🔔 Setting up subscription for conversation: $_conversationId');
    
    _messageSubscription = _supabase
        .subscribeToChatMessages(conversationId: _conversationId, studentId: '')
        .listen((newMessages) {
          if (mounted) {
            print('📬 Received ${newMessages.length} new messages in Chat_screen');
            // Reset retry count on successful message
            _subscriptionRetryCount = 0;
            _stopPolling(); // If we successfully receive messages, stop polling
            
            // DB filtering is now trusted, simply add unique messages
            for (var newMessage in newMessages) {
              _addNewMessage(newMessage);
            }
          }
        }, onError: (e) {
          print('⚠️ Subscription Error: $e');
          
          if (_subscriptionRetryCount < _maxRetries) {
            _subscriptionRetryCount++;
            final delaySeconds = 2 * _subscriptionRetryCount;
            print('🔄 Retrying subscription in $delaySeconds seconds (attempt $_subscriptionRetryCount/$_maxRetries)');
            
            Future.delayed(Duration(seconds: delaySeconds), () {
              if (mounted) {
                _setupListeners();
              }
            });
          } else {
            print('❌ Max retry attempts reached for subscription. Falling back to polling.');
            _startPolling();
          }
        });
  }

  void _startPolling() {
    if (_isPolling) return;
    _isPolling = true;
    _pollingTimer?.cancel();
    
    print('⏱️ Starting 10s polling fallback for messages...');
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Pull latest messages
      _loadMessages(refresh: true);
      
      // Periodically (every 6 polls = 1 min) try to re-enable Realtime
      if (timer.tick % 6 == 0) {
        print('🔄 Attempting to restore Realtime from polling...');
        _subscriptionRetryCount = 0; // Reset retries
        _setupListeners();
      }
    });
  }

  void _stopPolling() {
    print('🛑 Stopping message polling.');
    _isPolling = false;
    _pollingTimer?.cancel();
  }

  void _mergeAndSaveMessages(List<ChatMessage> cloudMessages) {
    final messageMap = {for (var msg in _messages) msg.id: msg};
    for (final cloudMsg in cloudMessages) {
      if (cloudMsg.conversationId == _conversationId) {
        messageMap[cloudMsg.id] = cloudMsg.copyWith(status: MessageStatus.sent);
      }
    }
    final mergedList = messageMap.values.toList();
    mergedList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setState(() => _messages = mergedList);
    _storage.saveChatMessages(mergedList);
  }

  void _addNewMessage(ChatMessage message) {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      // Robust Check: Don't revert a 'sent' or 'failed' message to 'pending'
      final localStatus = _messages[index].status;
      final newStatus = message.status;
      
      if (localStatus != newStatus) {
        if (localStatus == MessageStatus.pending || newStatus == MessageStatus.sent) {
          setState(() {
            _messages[index] = _messages[index].copyWith(status: newStatus);
          });
          print('🔄 UI: Updated message ${message.id} status: $localStatus -> $newStatus');
        }
      }
      return; 
    }
    
    // Check if we should show a notification
    _showNotificationIfNeeded(message);
    
    setState(() => _messages.add(message));
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _storage.saveChatMessages(_messages);
    _scrollToBottom();
  }
  
  /// Show notification for new message if conversation is not active
  void _showNotificationIfNeeded(ChatMessage message) {
    // Don't notify for own messages
    if (message.senderId == _currentUserId) {
      print('⏭️ Skipping notification (own message)');
      return;
    }
    
    // Check if this conversation is currently active
    if (!ActiveConversationTracker().isConversationActive(_conversationId)) {
      // Conversation is not active, show notification
      LocalNotificationService().showChatMessageNotification(
        senderName: message.senderName,
        messageText: message.text,
        conversationId: message.conversationId,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null || _currentUserName == null) {
      return;
    }

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _conversationId,
      senderId: _currentUserId!,
      senderName: _currentUserName!,
      text: text,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
    );

    // 1. Optimistic Update
    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
    });
    _scrollToBottom();
  
    try {
      // 2. Wait for background sync attempt
      await _storage.sendChatMessage(newMessage);
      
      // 3. Update status locally for immediate feedback
      _updateSingleMessageStatus(newMessage.id, MessageStatus.sent);
      
    } catch (e) {
      print('❌ Failed to send message: $e');
      
      if (mounted) {
        // 4. Mark as FAILED instead of removing (Better for user experience)
        _updateSingleMessageStatus(newMessage.id, MessageStatus.failed);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذر الإرسال بسبب ضعف الإنترنت'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'حذف',
              textColor: Colors.white,
              onPressed: () => _confirmDeleteFailedMessage(newMessage),
            ),
          ),
        );
      }
    }
  }

  void _updateSingleMessageStatus(String messageId, MessageStatus status) {
    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(status: status);
      }
    });
  }

  Future<void> _resendMessage(ChatMessage message) async {
    // 1. Move back to pending
    _updateSingleMessageStatus(message.id, MessageStatus.pending);

    try {
      await _storage.sendChatMessage(message);
      _updateSingleMessageStatus(message.id, MessageStatus.sent);
    } catch (e) {
      print('❌ Resend failed: $e');
      _updateSingleMessageStatus(message.id, MessageStatus.failed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشلَت إعادة الإرسال: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'إعادة محاولة',
              textColor: Colors.white,
              onPressed: () => _resendMessage(message),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteFailedMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الرسالة'),
        content: const Text('هل أنت متأكد من حذف هذه الرسالة الفاشلة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _messages.removeWhere((m) => m.id == message.id);
      });
      // Also delete from local storage if needed
      // Currently StorageService doesn't have a direct "delete single message" exported, 
      // but we can save the whole list or we could just let it be (it will be gone on next reload if we don't save).
      // Let's save the current list to storage to persist the deletion.
      _storage.saveChatMessages(_messages);
    }
  }
  
  Future<void> _refreshMessagesAfterSend() async {
    try {
      final updatedMessages = await _storage.loadChatMessages(
        conversationId: _conversationId,
        limit: _messages.length + 10,
        offset: 0,
      );
      
      if (mounted) {
        setState(() {
          _messages = updatedMessages.reversed.toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error refreshing messages after send: $e');
    }
  }

  Future<void> _syncPendingMessages() async {
    // With new StorageService logic, this might be handled by SyncQueueService.
    // However, we keeping this for immediate UI feedback if needed, 
    // or we can rely on StorageService's background sync.
    // For now, let's just trigger a re-save of pending messages to force retry logic.
    final pendingMessages = _messages
        .where((m) => m.status == MessageStatus.pending && m.conversationId == _conversationId)
        .toList();

    if (pendingMessages.isEmpty) return;

    print('🔄 UI Sync: Retrying ${pendingMessages.length} pending messages...');
    for (var msg in pendingMessages) {
       await _storage.sendChatMessage(msg);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    // Clear active conversation when leaving
    ActiveConversationTracker().clearActiveConversation();
    
    _messageController.dispose();
    _scrollController.dispose();
    _connectivitySubscription?.cancel();
    _messageSubscription?.cancel();
    _subscriptionDebouncer?.cancel(); // New: Cancel debouncer
    _stopPolling(); // New: Stop polling
    _supabase.unsubscribeFromChatMessages();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    
    return Scaffold(
      backgroundColor: backcolor,
      appBar: AppBar(
        title: Text(
          _isLoading ? 'تحميل...' : _recipientName,
          style: TextStyle(
            color: Colors.white,
            fontSize: responsive.fontSize(18),
          ),
        ),
        backgroundColor: textcolor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد رسائل بعد. ابدأ المحادثة!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: responsive.fontSize(14),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(10.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == _currentUserId;
                      return _buildMessageBubble(message, isMe);
                    },
                  ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  // Animation Helper
  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final responsive = context.responsive;

    // Determine status icon
    Widget statusIcon;
    switch (message.status) {
      case MessageStatus.pending:
        statusIcon = const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        );
        break;
      case MessageStatus.sent:
        // Clearer "Sent" icon - single check usually means sent to server
        statusIcon = const Icon(Icons.check, size: 14, color: Colors.white70);
        break;
      case MessageStatus.failed:
        // Clearer "Failed" icon
        statusIcon = const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.redAccent);
        break;
    }

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: ModalRoute.of(context)!.animation!,
        curve: Curves.easeOutBack,
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                backgroundImage: const AssetImage('assets/images/avatar_placeholder.png'), // Fallback
                child: Text(message.senderName[0].toUpperCase(),
                    style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: responsive.width(75),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
                decoration: BoxDecoration(
                  color: isMe ? regsin.withOpacity(0.9) : textcolor,
                  boxShadow: [
                     BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2)),
                  ],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(2),
                    bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          message.senderName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[300],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMe && message.status == MessageStatus.failed)
                           const Padding(
                             padding: EdgeInsets.only(right: 4.0),
                             child: Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                           ),
                        Expanded(
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: responsive.fontSize(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          statusIcon,
                        ],
                      ],
                    ),
                    if (isMe && message.status == MessageStatus.failed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _confirmDeleteFailedMessage(message),
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                              label: const Text('حذف', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _resendMessage(message),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white24,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: const Size(0, 30),
                              ),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('إعادة الإرسال', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
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

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      color: textcolor,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration.collapsed(
                  hintText: 'اكتب رسالتك هنا...',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: regsin),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
