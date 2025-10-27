// lib/models/chat_message.dart
class ChatMessage {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    return ChatMessage(
      id: (j['id'] ?? j['messageId'] ?? '').toString(),
      fromUserId: (j['fromUserId'] ?? j['from'] ?? '').toString(),
      toUserId: (j['toUserId'] ?? j['to'] ?? '').toString(),
      content: (j['content'] ?? j['message'] ?? '').toString(),
      createdAt: DateTime.parse(j['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };
}
