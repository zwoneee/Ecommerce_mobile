// lib/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _loading = false;
  final TextEditingController _promoCtrl = TextEditingController();

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    setState(() => _loading = true);
    final cart = Provider.of<CartProvider>(context, listen: false);
    try {
      final res = await cart.checkout(promotionCode: _promoCtrl.text.isEmpty ? null : _promoCtrl.text);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order created: ${res.toString()}')));
      cart.clear();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checkout failed')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return Scaffold(appBar: AppBar(title: const Text('Checkout')), body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Expanded(child: ListView(children: cart.items.map((it) => ListTile(leading: it.product.thumbnailUrl.isNotEmpty ? Image.network(it.product.thumbnailUrl, width: 56, height: 56, fit: BoxFit.cover) : null, title: Text(it.product.name), subtitle: Text('Qty: ${it.quantity}  \$${(it.product.price * it.quantity).toStringAsFixed(2)}'), )).toList())),
      Text('Total: \$${cart.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      TextField(controller: _promoCtrl, decoration: const InputDecoration(labelText: 'Promotion code')),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _checkout, child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm & Pay'))),
    ])));
  }
}
