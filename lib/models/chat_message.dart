enum MessageStatus { pending, sent, failed }

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.status = MessageStatus.sent,
  });

  /// Convert status enum to integer for database storage
  /// 0 = pending, 1 = sent, 2 = failed
  int _statusToInt(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return 0;
      case MessageStatus.sent:
        return 1;
      case MessageStatus.failed:
        return 2;
    }
  }

  /// Convert integer from database to status enum
  static MessageStatus _intToStatus(int statusInt) {
    switch (statusInt) {
      case 0:
        return MessageStatus.pending;
      case 1:
        return MessageStatus.sent;
      case 2:
        return MessageStatus.failed;
      default:
        return MessageStatus.sent; // Default to sent for unknown values
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderName': senderName,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'status': _statusToInt(status), // Convert to integer
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    MessageStatus status;
    
    // Handle both integer (new format) and string (old format) for backward compatibility
    final statusValue = json['status'];
    if (statusValue is int) {
      // New format: integer from database
      status = _intToStatus(statusValue);
    } else if (statusValue is String) {
      // Old format: string from legacy data
      if (statusValue == 'pending') {
        status = MessageStatus.pending;
      } else if (statusValue == 'failed') {
        status = MessageStatus.failed;
      } else {
        status = MessageStatus.sent;
      }
    } else {
      // Default to sent if status is missing or invalid
      status = MessageStatus.sent;
    }

    return ChatMessage(
      id: json['id'],
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'],
      senderName: json['senderName'],
      text: json['text'],
      createdAt: DateTime.parse(json['createdAt']),
      status: status,
    );
  }

  ChatMessage copyWith({String? id, MessageStatus? status}) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}
