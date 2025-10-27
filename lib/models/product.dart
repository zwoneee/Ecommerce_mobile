// lib/models/product.dart
class Product {
  final int id;
  final String name;
  final double price;
  final String description;
  final String thumbnailUrl;
  final int categoryId;
  final double rating;
  final bool isPromoted;
  final String? qrCode;
  final int stock;
  final String? slug;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.thumbnailUrl,
    required this.categoryId,
    required this.rating,
    required this.isPromoted,
    this.qrCode,
    required this.stock,
    this.slug,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'] is int ? j['id'] : int.parse('${j['id']}'),
    name: j['name']?.toString() ?? '',
    price: (j['price'] ?? 0).toDouble(),
    description: j['description']?.toString() ?? '',
    thumbnailUrl: j['thumbnailUrl']?.toString() ?? '',
    categoryId: j['categoryId'] is int ? j['categoryId'] : int.tryParse('${j['categoryId']}') ?? 0,
    rating: (j['rating'] ?? 0).toDouble(),
    isPromoted: j['isPromoted'] ?? false,
    qrCode: j['qrCode']?.toString(),
    stock: j['stock'] is int ? j['stock'] : int.tryParse('${j['stock']}') ?? 0,
    slug: j['slug']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'description': description,
    'thumbnailUrl': thumbnailUrl,
    'categoryId': categoryId,
    'rating': rating,
    'isPromoted': isPromoted,
    'qrCode': qrCode,
    'stock': stock,
    'slug': slug,
  };
}
