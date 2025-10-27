// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: Column(
        children: [
          Expanded(
            child: cart.items.isEmpty
                ? const Center(child: Text('Giỏ hàng rỗng'))
                : ListView(
              children: cart.items
                  .map((it) => ListTile(
                leading: it.product.thumbnailUrl.isNotEmpty ? Image.network(it.product.thumbnailUrl, width: 56, height: 56, fit: BoxFit.cover) : null,
                title: Text(it.product.name),
                subtitle: Text('Qty: ${it.quantity}  \$${(it.product.price * it.quantity).toStringAsFixed(2)}'),
                trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => cart.removeFromCart(it.product.id)),
              ))
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Total: \$${cart.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen())), child: const Text('Checkout')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
