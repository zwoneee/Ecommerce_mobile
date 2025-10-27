// lib/models/comment.dart
class CommentModel {
  final int id;
  final int productId;
  final String content;
  final String? userName;
  final DateTime createdAt;

  CommentModel({required this.id, required this.productId, required this.content, this.userName, required this.createdAt});

  factory CommentModel.fromJson(Map<String, dynamic> j) => CommentModel(
    id: j['id'] is int ? j['id'] : int.parse('${j['id']}'),
    productId: j['productId'] is int ? j['productId'] : int.tryParse('${j['productId']}') ?? 0,
    content: j['content']?.toString() ?? '',
    userName: j['fromUser'] ?? j['userName'] ?? null,
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {'id': id, 'productId': productId, 'content': content, 'userName': userName, 'createdAt': createdAt.toIso8601String()};
}
