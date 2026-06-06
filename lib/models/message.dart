class Message {
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final String text;
  final DateTime timestamp;

  Message({
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'senderId': senderId,
    'senderName': senderName,
    'receiverId': receiverId,
    'receiverName': receiverName,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    senderId: json['senderId'] as String,
    senderName: json['senderName'] as String,
    receiverId: json['receiverId'] as String,
    receiverName: json['receiverName'] as String,
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
