class CommentModel {
  final int id;
  final int productId;
  String content;
  final String userName;
  final DateTime createdAt;
  final double rating;
  final List<String> mediaUrls;

  CommentModel({
    required this.id,
    required this.productId,
    required this.content,
    required this.userName,
    required this.createdAt,
    this.rating = 0,
    this.mediaUrls = const [],
  });

  factory CommentModel.fromJson(Map<String, dynamic> j) => CommentModel(
    id: j['id'] ?? 0,
    productId: j['productId'] ?? 0,
    content: j['content'] ?? '',
    userName: j['userName'] ?? 'User',
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
    rating: (j['rating'] is num) ? (j['rating'] + .0) : double.tryParse('${j['rating']}') ?? 0,
    mediaUrls: (j['mediaUrls'] is List)
        ? List<String>.from(j['mediaUrls'].map((e) => e.toString()))
        : [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'content': content,
    'userName': userName,
    'createdAt': createdAt.toIso8601String(),
    'rating': rating,
    'mediaUrls': mediaUrls,
  };
}
