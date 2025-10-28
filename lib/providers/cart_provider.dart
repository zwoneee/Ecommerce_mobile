// lib/providers/cart_provider.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}

class CartProvider extends ChangeNotifier {
  final ApiService api;

  CartProvider({required this.api});

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  double get total => _items.fold(0.0, (s, it) => s + it.product.price * it.quantity);

  void addToCart(Product p, {int qty = 1}) {
    final idx = _items.indexWhere((e) => e.product.id == p.id);
    if (idx >= 0) {
      _items[idx].quantity += qty;
    } else {
      _items.add(CartItem(product: p, quantity: qty));
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    _items.removeWhere((e) => e.product.id == productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  int get itemCount => _items.fold(0, (s, it) => s + it.quantity);

  /// Build payload expected by backend for checkout / create order.
  /// Adjust keys to match your backend's DTO if necessary.
  Map<String, dynamic> createOrderPayload({
    required int userId,
    required String deliveryLocation,
    String? promotionCode,
  }) {
    final items = _items
        .map((it) => {
      'productId': it.product.id,
      'quantity': it.quantity,
      'unitPrice': it.product.price,
    })
        .toList();

    return {
      'userId': userId,
      'items': items,
      'total': total,
      'deliveryLocation': deliveryLocation,
      if (promotionCode != null && promotionCode.isNotEmpty) 'promotionCode': promotionCode,
      // add other fields required by your backend (shippingAddress, paymentMethod, etc.)
    };
  }

  /// Checkout: call backend API to create order / checkout cart.
  /// Returns whatever the ApiService returns (usually order object or success response).
  Future<Map<String, dynamic>> checkout({
    required int userId,
    required String deliveryLocation,
    String? promotionCode,
  }) async {
    if (_items.isEmpty) {
      throw Exception('Cart is empty');
    }
    final payload = createOrderPayload(
      userId: userId,
      deliveryLocation: deliveryLocation,
      promotionCode: promotionCode,
    );
    // your ApiService might have checkoutCart() or createOrder()
    // prefer checkoutCart if it maps to /api/user/cart/checkout
    try {
      final res = await api.createOrder(payload);
      return res;
    } catch (e) {
      // bubble up error so UI can show error message
      rethrow;
    }
  }

  Future<Map<String, dynamic>> payAllPendingOrders({
    required int userId,
    required String paymentMethod,
  }) async {
    try {
      final res = await api.payAllOrders(userId: userId, paymentMethod: paymentMethod);
      return res;
    } catch (e) {
      rethrow;
    }
  }
}
