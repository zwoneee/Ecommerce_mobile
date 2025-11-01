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

  factory Product.fromJson(Map<String, dynamic> j, {String? baseUrl}) {
    // Hỗ trợ cả key viết hoa và viết thường
    dynamic getVal(String k1, [String? k2]) {
      if (j.containsKey(k1)) return j[k1];
      if (k2 != null && j.containsKey(k2)) return j[k2];
      return null;
    }

    return Product(
      id: getVal('id', 'Id') is int
          ? getVal('id', 'Id')
          : int.tryParse('${getVal('id', 'Id')}') ?? 0,
      name: getVal('name', 'Name')?.toString() ?? '',
      price: _parseDouble(getVal('price', 'Price')),
      description: getVal('description', 'Description')?.toString() ?? '',
      thumbnailUrl:
      _resolveThumbnailUrl(getVal('thumbnailUrl', 'ThumbnailUrl'), baseUrl),
      categoryId: getVal('categoryId', 'CategoryId') is int
          ? getVal('categoryId', 'CategoryId')
          : int.tryParse('${getVal('categoryId', 'CategoryId')}') ?? 0,
      rating: _parseDouble(getVal('rating', 'Rating')),
      isPromoted: getVal('isPromoted', 'IsPromoted') ?? false,
      qrCode: getVal('qrCode', 'QrCode')?.toString(),
      stock: getVal('stock', 'Stock') is int
          ? getVal('stock', 'Stock')
          : int.tryParse('${getVal('stock', 'Stock')}') ?? 0,
      slug: getVal('slug', 'Slug')?.toString(),
    );
  }

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

    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
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
