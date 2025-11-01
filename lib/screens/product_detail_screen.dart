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
  int _quantity = 1;
  int? _userRating;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);

      // Lấy chi tiết sản phẩm (bao gồm rating trung bình)
      final data = await api.getProductDetail(widget.productId);
      if (mounted && data != null) {
        _product = Product.fromJson(Map<String, dynamic>.from(data), baseUrl: api.baseUrl);
      }

      // Nếu đã đăng nhập, lấy rating của user cho sản phẩm này
      if (auth.isAuthenticated) {
        final ratingData = await api.getUserRating(widget.productId);
        if (mounted && ratingData['value'] is int) {
          setState(() {
            _userRating = ratingData['value'] as int?;
          });
        }
      }
    } catch (e) {
      print('Load product error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addToCart() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (_product != null) {
      cart.addToCart(_product!, qty: _quantity);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Đã thêm $_quantity sản phẩm vào giỏ hàng'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Gửi đánh giá mới lên server
  Future<void> _submitRating(int newRating) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final response = await api.rateProduct(widget.productId, newRating);
      if (mounted) {
        final newAverage = response['average'];
        setState(() {
          _userRating = newRating;
          if (newAverage is num) {
            _product = _product?.copyWith(rating: newAverage.toDouble());
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cảm ơn bạn đã đánh giá sản phẩm!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi gửi đánh giá: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue.shade600),
              const SizedBox(height: 16),
              Text(
                'Đang tải...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Không tìm thấy sản phẩm',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final p = _product!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // App bar với hình ảnh sản phẩm
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'product_${p.id}',
                child: p.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        p.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
              ),
            ),
          ),

          // Nội dung chi tiết
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin sản phẩm
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tên sản phẩm
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Giá và Rating trung bình
                        Row(
                          children: [
                            Text(
                              '\$${p.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const Spacer(),
                            // Chỉ hiển thị rating trung bình
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star, size: 18, color: Colors.amber.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    p.rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Số lượng
                        Row(
                          children: [
                            Text(
                              'Số lượng',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      if (_quantity > 1) {
                                        setState(() => _quantity--);
                                      }
                                    },
                                    icon: Icon(
                                      Icons.remove,
                                      color: _quantity > 1 ? Colors.blue.shade700 : Colors.grey.shade400,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      _quantity.toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => _quantity++);
                                    },
                                    icon: Icon(Icons.add, color: Colors.blue.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Divider
                        Divider(color: Colors.grey.shade200, height: 1),
                        const SizedBox(height: 24),

                        // Mô tả
                        Text(
                          'Mô tả sản phẩm',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.description,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Chat button
                        InkWell(
                          onTap: () {
                            if (!auth.isAuthenticated) {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const LoginScreen(nextRoute: '/chat')),
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ChatScreen()),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.chat_bubble_outline, color: Colors.blue.shade700),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cần tư vấn?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                      Text(
                                        'Chat với chúng tôi ngay',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue.shade700),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // --- PHẦN ĐÁNH GIÁ VÀ BÌNH LUẬN ---
                  Container(
                    color: Colors.grey.shade50,
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                'Đánh giá của bạn',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                ),
                                ),
                                const SizedBox(height: 12),
                                auth.isAuthenticated
                                ? RatingBar(
                                    initialRating: _userRating ?? 0,
                                    onRatingUpdate: (rating) {
                                    _submitRating(rating);
                                    },
                                )
                                : TextButton(
                                    onPressed: () {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                                    );
                                    },
                                    child: const Text('Vui lòng đăng nhập để đánh giá sản phẩm.'),
                                ),
                            ],
                          ),
                        ),
                        Divider(height: 1, indent: 20, endIndent: 20),
                        CommentsSection(productId: p.id),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Tổng tiền
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng cộng',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '\$${(p.price * _quantity).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Add to cart button
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _addToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined),
                      SizedBox(width: 8),
                      Text(
                        'Thêm vào giỏ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget để hiển thị các ngôi sao cho việc rating
class RatingBar extends StatelessWidget {
  final int initialRating;
  final Function(int) onRatingUpdate;
  final double size;

  const RatingBar({
    super.key,
    required this.initialRating,
    required this.onRatingUpdate,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final rating = index + 1;
        return IconButton(
          onPressed: () => onRatingUpdate(rating),
          icon: Icon(
            rating <= initialRating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
        );
      }),
    );
  }
}

// Extension để thêm hàm copyWith cho Product model
extension on Product {
  Product copyWith({double? rating}) {
    return Product(
      id: id,
      name: name,
      price: price,
      description: description,
      thumbnailUrl: thumbnailUrl,
      categoryId: categoryId,
      rating: rating ?? this.rating,
      isPromoted: isPromoted,
      qrCode: qrCode,
      stock: stock,
      slug: slug,
    );
  }
}