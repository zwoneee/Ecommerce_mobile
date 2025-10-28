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

  factory Product.fromJson(Map<String, dynamic> j, {String? baseUrl}) => Product(
    id: j['id'] is int ? j['id'] : int.parse('${j['id']}'),
    name: j['name']?.toString() ?? '',
    price: _parseDouble(j['price']),
    description: j['description']?.toString() ?? '',
    thumbnailUrl: _resolveThumbnailUrl(j['thumbnailUrl'], baseUrl),
    categoryId: j['categoryId'] is int ? j['categoryId'] : int.tryParse('${j['categoryId']}') ?? 0,
    rating: _parseDouble(j['rating']),
    isPromoted: j['isPromoted'] ?? false,
    qrCode: j['qrCode']?.toString(),
    stock: j['stock'] is int ? j['stock'] : int.tryParse('${j['stock']}') ?? 0,
    slug: j['slug']?.toString(),
  );

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _resolveThumbnailUrl(dynamic rawValue, String? baseUrl) {
    final url = rawValue?.toString() ?? '';
    if (url.isEmpty) return '';
    final lower = url.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return url;
    }

    if (baseUrl == null || baseUrl.isEmpty) {
      return url;
    }

    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    if (url.startsWith('/')) {
      return '$normalizedBase$url';
    }
    return '$normalizedBase/$url';
  }

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
