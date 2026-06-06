import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/models/chat_message.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/services/connectivity_service.dart';
import 'package:yaman/services/supabase_service.dart';
import 'package:yaman/services/active_conversation_tracker.dart';
import 'package:yaman/services/local_notification_service.dart';
import 'package:yaman/utils/responsive_helper.dart';


class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final StorageService _storage = StorageService();
  final ConnectivityService _connectivity = ConnectivityService();
  final SupabaseService _supabase = SupabaseService();
  final ScrollController _scrollController = ScrollController();

  List<Teacher> _teachers = [];
  Teacher? _selectedTeacher;
  List<ChatMessage> _messages = [];
  StreamSubscription? _messageSubscription;
  Timer? _pollingTimer;
  bool _isPolling = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    loadTeachers();
  }

  Future<void> loadTeachers() async {
    final teachers = await _storage.loadTeachers();
    if (mounted) {
      setState(() {
        _teachers = teachers;
        if (_teachers.isNotEmpty) {
          selectTeacher(_teachers.first);
        }
      });
    }
  }

  void selectTeacher(Teacher teacher) {
    // Clear previous active conversation
    ActiveConversationTracker().clearActiveConversation();

    setState(() {
      _selectedTeacher = teacher;
      _messages.clear();
      _isLoading = true;
    });

    // Set new active conversation
    final conversationId = getConversationId(teacher);
    ActiveConversationTracker().setActiveConversation(conversationId);

    loadMessages(teacher);
  }

  String getConversationId(Teacher teacher) {
    return 'admin_${teacher.id}';
  }

  Future<void> loadMessages(Teacher teacher) async {
    final conversationId = getConversationId(teacher);

    // Load local
    final localMessages = await _storage.loadChatMessages(conversationId: conversationId);
    if (mounted && _selectedTeacher?.id == teacher.id) {
       setState(() {
         _messages = localMessages;
         _isLoading = false;
       });
       _scrollToBottom();
    }

    // Subscribe to realtime - Non-blocking
    _subscribeToMessages(conversationId);

    // Attempt cloud sync in background - Non-blocking
    syncWithCloud(teacher);
  }

  Future<void> syncWithCloud(Teacher teacher) async {
    final conversationId = getConversationId(teacher);
    try {
      final cloudMessages = await _supabase.loadChatMessages(conversationId: conversationId);
      if (cloudMessages.isNotEmpty) {
        await _storage.saveChatMessages(cloudMessages);

        // Reload only if we're still on this teacher
        if (mounted && _selectedTeacher?.id == teacher.id) {
          final updatedLocal = await _storage.loadChatMessages(conversationId: conversationId);
          setState(() {
            _messages = updatedLocal;
            _isLoading = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Cloud load error: $e');
      if (mounted && _selectedTeacher?.id == teacher.id) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _subscriptionRetryCount = 0;
  final int _maxRetries = 5;

  void _subscribeToMessages(String conversationId) {
    _messageSubscription?.cancel();
    
    print('🔔 Admin subscribing to conversation: $conversationId');
    
    _messageSubscription = _supabase.subscribeToChatMessages(conversationId: conversationId, studentId: '')
        .listen((newMessages) {
           if (mounted && _selectedTeacher != null && getConversationId(_selectedTeacher!) == conversationId) {
             print('📬 Admin received ${newMessages.length} messages for conversation: $conversationId');
             // Reset retry count on successful message
             _subscriptionRetryCount = 0;
             _stopPolling(); // Stop polling if subscription works or returns data
             
             // We can just reload or simplisticly add. Reloading is safer for consistency.
             // But for animation smoothmess, adding is better.
             // Let's filter for this conversation
              final relevant = newMessages.where((m) => m.conversationId == conversationId).toList();
              if (relevant.isNotEmpty) {
                // Check if we should show notifications
                for (var msg in relevant) {
                  _showNotificationIfNeeded(msg, conversationId);
                }
                
                _storage.saveChatMessages(relevant).then((_) {
                  // Refresh view
                  loadMessages(_selectedTeacher!);
                });
              }
           }
        }, onError: (e) {
          print('⚠️ Admin Subscription Error: $e');
          
          // Implement retry with exponential backoff
          if (_subscriptionRetryCount < _maxRetries) {
            _subscriptionRetryCount++;
            final delaySeconds = 2 * _subscriptionRetryCount;
            print('🔄 Retrying admin subscription in $delaySeconds seconds (attempt $_subscriptionRetryCount/$_maxRetries)');
            
            Future.delayed(Duration(seconds: delaySeconds), () {
              if (mounted && _selectedTeacher != null) {
                _subscribeToMessages(getConversationId(_selectedTeacher!));
              }
            });
          } else {
            print('❌ Max retry attempts reached for admin subscription. Falling back to polling.');
            _startPolling();
          }
        });
  }

  void _startPolling() {
    if (_isPolling || _selectedTeacher == null) return;
    _isPolling = true;
    _pollingTimer?.cancel();
    
    print('⏱️ Admin: Starting 10s polling fallback for messages...');
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted || _selectedTeacher == null) {
        timer.cancel();
        return;
      }
      
      // Pull latest messages
      loadMessages(_selectedTeacher!);
      
      // Periodically (every 6 polls = 1 min) try to re-enable Realtime
      if (timer.tick % 6 == 0) {
        print('🔄 Admin: Attempting to restore Realtime from polling...');
        _subscriptionRetryCount = 0; // Reset retries
        _subscribeToMessages(getConversationId(_selectedTeacher!));
      }
    });
  }

  void _stopPolling() {
    print('🛑 Admin: Stopping message polling.');
    _isPolling = false;
    _pollingTimer?.cancel();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedTeacher == null) return;

    final conversationId = getConversationId(_selectedTeacher!);
    final newMessage = ChatMessage(
      id: 'msg_admin_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: 'admin', // Hardcoded admin ID
      senderName: 'الإدارة',
      text: text,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
    );

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      await _storage.sendChatMessage(newMessage);
      _updateSingleMessageStatus(newMessage.id, MessageStatus.sent);
    } catch (e) {
      print('❌ Admin send fail: $e');
      if (mounted) {
        // Mark as failed instead of removing immediately (or remove if requested)
        // The user asked for "Resend" button, which implies it stays in the list as failed.
        _updateSingleMessageStatus(newMessage.id, MessageStatus.failed);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'إعادة محاولة',
              textColor: Colors.white,
              onPressed: () => _resendMessage(newMessage),
            ),
          ),
        );
      }
    }
  }

  Future<void> _resendMessage(ChatMessage message) async {
    _updateSingleMessageStatus(message.id, MessageStatus.pending);

    try {
      await _storage.sendChatMessage(message);
      _updateSingleMessageStatus(message.id, MessageStatus.sent);
    } catch (e) {
      print('❌ Admin resend failed: $e');
      _updateSingleMessageStatus(message.id, MessageStatus.failed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر الإرسال: ${e.toString()}'),
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
        title: const Text('حذف رسالة الإدارة'),
        content: const Text('هل أنت متأكد من حذف هذه الرسالة؟'),
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
      _storage.saveChatMessages(_messages);
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

  @override
  void dispose() {
    // Clear active conversation when leaving
    ActiveConversationTracker().clearActiveConversation();
    
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _stopPolling();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return SafeArea(
      top: false,
      bottom: true,
      child: Scaffold(
          appBar: AppBar(
            title: Text(
              "Admin Chat",
              style: TextStyle(fontSize: responsive.fontSize(20), color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: backcolor,
            leading: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.menu, size: 25, color: Colors.white),
            ),
            actions: [
               IconButton(
                onPressed: () {},
                icon: const Icon(Icons.close, size: 25, color: Colors.white),
              ),
            ],
          ),
          body: Column(
            children: [
              // Teacher Selector
              Container(
                color: textcolor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Teacher>(
                    value: _selectedTeacher,
                    isExpanded: true,
                    dropdownColor: textcolor,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    hint: const Text('Select Teacher', style: TextStyle(color: Colors.white70)),
                    onChanged: (Teacher? newValue) {
                      if (newValue != null) selectTeacher(newValue);
                    },
                    items: _teachers.map<DropdownMenuItem<Teacher>>((Teacher teacher) {
                      return DropdownMenuItem<Teacher>(
                        value: teacher,
                        child: Text(teacher.name, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              // Chat Area
              Expanded(
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator()) 
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: false, // Standard chat is usually top-to-bottom but ListView reverse=true is common. 
                        // Wait, previous code had reverse: true. And messages were indices [length - 1 - index].
                        // Standard efficient chat is reverse: true with [0] being latest.
                        // My storage load sorts by createdAt (oldest first).
                        // So for reverse:true ListView, I should reverse the list or access from end.
                        // Let's use standard ListView (reverse: false) with auto-scroll or reverse: true with reversed list.
                        // Simpler: reverse: true and reversed list.
                  
                  // Actually, let's keep it simple: Standard list, auto-scroll to bottom like ChatScreen.
                  // ChatScreen sets controller to maxScrollExtent.
                  // Here, let's just use reverse: true and list.reversed.toList()
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.senderId == 'admin';
                          return _buildMessageBubble(message, isMe);
                        },
                      ),
              ),
              
              // Input Area
              Container(
                 padding: const EdgeInsets.all(8),
                 color: backcolor,
                 child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Enter your message...",
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: textcolor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: regsin,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                 ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final responsive = context.responsive;

    // Determine status icon for admin
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
        statusIcon = const Icon(Icons.check, size: 14, color: Colors.white70);
        break;
      case MessageStatus.failed:
        statusIcon = const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent);
        break;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: responsive.width(75)),
        decoration: BoxDecoration(
          color: isMe ? regsin.withOpacity(0.9) : textcolor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMe && message.status == MessageStatus.failed)
                   const Padding(
                     padding: EdgeInsets.only(right: 4.0),
                     child: Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                   ),
                Expanded(
                  child: Text(
                    message.text,
                    style: TextStyle(color: Colors.white, fontSize: responsive.fontSize(14)),
                  ),
                ),
              ],
            ),
             const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                if (isMe) ...[
                   const SizedBox(width: 4),
                   statusIcon,
                ]
              ],
            ),
            if (isMe && message.status == MessageStatus.failed)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _confirmDeleteFailedMessage(message),
                      child: const Text('حذف', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _resendMessage(message),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 28),
                      ),
                      child: const Text('إعادة المحاولة', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// Show notification if needed (conversation not active)
  void _showNotificationIfNeeded(ChatMessage message, String conversationId) {
    // Don't notify for admin's own messages
    if (message.senderId == 'admin') {
      print('⏭️ Skipping notification (admin message)');
      return;
    }

    // Check if this conversation is currently active
    if (!ActiveConversationTracker().isConversationActive(conversationId)) {
      // Conversation is not active, show notification
      LocalNotificationService().showChatMessageNotification(
        senderName: message.senderName,
        messageText: message.text,
        conversationId: message.conversationId,
      );
    }
  }
}
