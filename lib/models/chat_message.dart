// lib/models/chat_message.dart

/// Model đại diện cho một tin nhắn chat giữa khách hàng và admin.
///
/// Backend trả về các trường: `id`, `fromUserId`, `toUserId`, `content`,
/// `fileUrl`, `fileType`, `fileName`, `sentAt` (UTC hoặc local). Lớp này cố gắng
/// chuyển đổi linh hoạt dựa vào dữ liệu có sẵn.
class ChatMessage {
  final int? id;
  final int? fromUserId;
  final int? toUserId;
  final String content;
  final String? fileUrl;
  final String? fileType;
  final String? fileName;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.content,
    required this.fileUrl,
    required this.fileType,
    required this.fileName,
    required this.sentAt,
  });

    /// Parse từ json động trả về từ API hoặc SignalR.
    factory ChatMessage.fromJson(Map<String, dynamic> json) {
      DateTime parseDate(dynamic value) {
        if (value is DateTime) return value.toLocal();
        if (value is String && value.isNotEmpty) {
          try {
            return DateTime.parse(value).toLocal();
          } catch (_) {}
        }
        return DateTime.now();
      }

      int? parseInt(dynamic value) {
        if (value is int) return value;
        if (value is String && value.isNotEmpty) {
          return int.tryParse(value);
        }
        return null;
      }

      String? parseString(dynamic value) {
        if (value == null) return null;
        if (value is String) return value;
        return value.toString();
      }

      final normalized = Map<String, dynamic>.from(json);
      return ChatMessage(
        id: parseInt(normalized['id'] ?? normalized['messageId']),
        fromUserId: parseInt(
          normalized['fromUserId'] ??
              normalized['from'] ??
              normalized['senderId'] ??
              normalized['sender'],
        ),
        toUserId: parseInt(
          normalized['toUserId'] ??
              normalized['to'] ??
              normalized['receiverId'] ??
              normalized['receiver'],
        ),
        content: parseString(normalized['content'] ?? normalized['message']) ?? '',
        fileUrl: parseString(normalized['fileUrl'] ?? normalized['url']),
        fileType: parseString(normalized['fileType'] ?? normalized['type']),
        fileName: parseString(normalized['fileName'] ?? normalized['name']),
        sentAt: parseDate(
          normalized['sentAt'] ??
              normalized['createdAt'] ??
              normalized['timestamp'],
        ),
      );
    }

    Map<String, dynamic> toJson() => {
    'id': id,
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'content': content,
    'fileUrl': fileUrl,
    'fileType': fileType,
    'fileName': fileName,
    'sentAt': sentAt.toUtc().toIso8601String(),
  };

  bool get hasAttachment => fileUrl != null && fileUrl!.isNotEmpty;
  bool get hasText => content.isNotEmpty;
  bool get isImageAttachment =>
      hasAttachment && (fileType?.toLowerCase().contains('image') ?? false);
  bool get isVideoAttachment =>
      hasAttachment && (fileType?.toLowerCase().contains('video') ?? false);
}