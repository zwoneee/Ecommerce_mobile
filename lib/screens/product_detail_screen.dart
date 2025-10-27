// lib/screens/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'comments_section.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _loading = true;
  Product? _product;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.getProductDetail(widget.productId);
      if (data != null) {
        _product = Product.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      // ignore: avoid_print
      print('Load product error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addToCart() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (_product != null) {
      cart.addToCart(_product!, qty: 1);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_product == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Not found')));

    final p = _product!;
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          p.thumbnailUrl.isNotEmpty
              ? Image.network(p.thumbnailUrl, height: 240, width: double.infinity, fit: BoxFit.cover)
              : Container(height: 240, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('\$${p.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, color: Colors.green)),
          const SizedBox(height: 12),
          Text(p.description),
          const SizedBox(height: 16),
          Row(children: [
            ElevatedButton.icon(onPressed: _addToCart, icon: const Icon(Icons.add_shopping_cart), label: const Text('Add to cart')),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (!auth.isAuthenticated) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen(nextRoute: '/chat')));
                } else {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
                }
              },
              icon: const Icon(Icons.chat),
              label: const Text('Chat'),
            ),
          ]),
          const SizedBox(height: 24),
          CommentsSection(productId: p.id),
        ]),
      ),
    );
  }
}
