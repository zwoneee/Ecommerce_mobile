// lib/screens/product_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _pageSize = 20;
  final List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _fetch(page: 1);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_loadingMore && !_loading && _hasMore) {
          _loadMore();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetch({int page = 1, bool showMessageOnError = true}) async {
    if (mounted) setState(() {
      if (page == 1) _loading = true;
      else _loadingMore = true;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.fetchProducts(page: page, pageSize: _pageSize);
      // ignore: avoid_print
      print('fetchProducts response: $data');

      final raw = data['products'];
      final List<Product> list = [];

      if (raw != null && raw is List) {
        for (final e in raw) {
          try {
            if (e is Map) {
              list.add(Product.fromJson(Map<String, dynamic>.from(e)));
            } else if (e is Map<String, dynamic>) {
              list.add(Product.fromJson(e));
            }
          } catch (itemEx) {
            // ignore single item parse error
            // ignore: avoid_print
            print('product parse error: $itemEx for item $e');
          }
        }
      }

      if (mounted) {
        if (page == 1) {
          _products.clear();
          _products.addAll(list);
        } else {
          _products.addAll(list);
        }

        _page = page;
        _hasMore = list.length >= _pageSize;
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('Error fetching products: $e\n$st');
      if (showMessageOnError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải sản phẩm: $e')));
      }
    } finally {
      if (mounted) setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    final next = _page + 1;
    await _fetch(page: next, showMessageOnError: false);
  }

  Future<void> _refresh() async {
    await _fetch(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart),
                if (cart.items.isNotEmpty)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        cart.items.length.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          auth.isAuthenticated
              ? TextButton.icon(
            onPressed: () async {
              await auth.logout();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đăng xuất')));
              setState(() {});
            },
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Logout', style: TextStyle(color: Colors.white)),
          )
              : TextButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            icon: const Icon(Icons.login, color: Colors.white),
            label: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading && _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refresh,
        child: _products.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Không có sản phẩm')),
          ],
        )
            : ListView.builder(
          controller: _scrollController,
          itemCount: _products.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _products.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final p = _products[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: p.thumbnailUrl.isNotEmpty
                    ? Image.network(
                  p.thumbnailUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                )
                    : const SizedBox(width: 56, height: 56, child: Icon(Icons.image)),
                title: Text(p.name),
                subtitle: Text('\$${p.price.toStringAsFixed(2)}'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id)));
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
