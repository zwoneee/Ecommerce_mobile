class OrderItem {
  final int productId;
  final int quantity;
  final double price;

  OrderItem({
    required this.productId,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    productId: j['productId'] is int ? j['productId'] : int.parse(j['productId'].toString()),
    quantity: j['quantity'] is int ? j['quantity'] : int.parse(j['quantity'].toString()),
    price: (j['price'] is num) ? (j['price'] as num).toDouble() : double.tryParse(j['price'].toString()) ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'price': price,
  };
}

class Order {
  final int id;
  final String userId;
  final List<OrderItem> items;
  final double total;
  final String status;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.total,
    required this.status,
  });

  // parse từ JSON (ví dụ API trả về object)
  factory Order.fromJson(Map<String, dynamic> j) {
    final itemsJson = j['items'] as List<dynamic>? ?? [];
    final items = itemsJson.map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    return Order(
      id: j['id'] is int ? j['id'] : int.tryParse(j['id'].toString()) ?? 0,
      userId: j['userId']?.toString() ?? j['user']?.toString() ?? '',
      items: items,
      total: (j['total'] is num) ? (j['total'] as num).toDouble() : double.tryParse(j['total']?.toString() ?? '0') ?? 0.0,
      status: j['status']?.toString() ?? '',
    );
  }

  // chuyển sang JSON (để gửi lên API)
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'items': items.map((i) => i.toJson()).toList(),
    'total': total,
    'status': status,
  };
}
