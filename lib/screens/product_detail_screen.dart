// lib/screens/product_detail_screen.dart
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'comments_section.dart';
import 'cart_screen.dart';

enum _ProductType { phone, laptop, tablet, other }

class _SpecItem {
  final String key;
  final String value;

  const _SpecItem(this.key, this.value);
}

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _loading = true;
  Product? _product;

  static const Map<String, List<String>> _phoneSections = {
    'Cấu hình & Bộ nhớ': [
      'Hệ điều hành',
      'Chip xử lý (CPU)',
      'Tốc độ CPU',
      'Chip đồ họa (GPU)',
      'RAM',
      'Dung lượng lưu trữ',
      'Dung lượng còn lại (khả dụng) khoảng',
      'Danh bạ',
    ],
    'Camera & Màn hình': [
      'Độ phân giải camera sau',
      'Quay phim camera sau',
      'Đèn Flash camera sau',
      'Tính năng camera sau',
      'Độ phân giải camera trước',
      'Tính năng camera trước',
      'Công nghệ màn hình',
      'Độ phân giải màn hình',
      'Màn hình rộng',
      'Độ sáng tối đa',
      'Mặt kính cảm ứng',
    ],
    'Pin & Sạc': [
      'Dung lượng pin',
      'Loại pin',
      'Hỗ trợ sạc tối đa',
      'Công nghệ pin',
    ],
    'Tiện ích': [
      'Bảo mật nâng cao',
      'Tính năng đặc biệt',
      'Kháng nước, bụi',
      'Ghi âm',
      'Xem phim',
      'Nghe nhạc',
    ],
    'Kết nối': [
      'Mạng di động',
      'SIM',
      'Wifi',
      'GPS',
      'Bluetooth',
      'Cổng kết nối/sạc',
      'Jack tai nghe',
      'Kết nối khác',
    ],
    'Thiết kế & Chất liệu': [
      'Thiết kế',
      'Chất liệu',
      'Kích thước, khối lượng',
      'Thời điểm ra mắt',
      'Hãng',
    ],
  };

  static const Map<String, List<String>> _laptopSections = {
    'Bộ xử lý': [
      'Công nghệ CPU',
      'Số nhân',
      'Số luồng',
      'Tốc độ CPU',
    ],
    'Đồ hoạ (GPU)': [
      'Card màn hình',
      'Số nhân GPU',
      'Công suất đồ hoạ - TGP',
      'Hiệu năng xử lý AI (TOPS)',
    ],
    'Bộ nhớ RAM, Ổ cứng': [
      'RAM',
      'Loại RAM',
      'Tốc độ Bus RAM',
      'Hỗ trợ RAM tối đa',
      'Ổ cứng',
    ],
    'Màn hình': [
      'Màn hình',
    ],
    'Cổng kết nối & tính năng mở rộng': [
      'Cổng giao tiếp',
      'Kết nối không dây',
      'Webcam',
      'Đèn bàn phím',
      'Bảo mật',
      'Công nghệ âm thanh',
      'Tản nhiệt',
      'Tính năng khác',
    ],
    'Kích thước - Khối lượng - Pin': [
      'Thông tin Pin',
      'Hệ điều hành',
      'Thời điểm ra mắt',
      'Kích thước',
      'Chất liệu',
    ],
  };

  static const List<String> _tabletOrder = [
    'Màn hình',
    'Hệ điều hành',
    'Chip',
    'RAM',
    'Dung lượng lưu trữ',
    'Kết nối',
    'Camera sau',
    'Camera trước',
    'Pin, Sạc',
    'Hãng',
  ];

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
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          Consumer<CartProvider>(
            builder: (_, cart, __) => IconButton(
              tooltip: 'Giỏ hàng',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  if (cart.items.isNotEmpty)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
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
          ),
        ],
      ),
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
            _buildProductDescription(p),
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

  _ProductType _detectProductType(Product product) {
    final lowerName = product.name.toLowerCase();
    if (lowerName.contains('điện thoại') || lowerName.contains('iphone') || lowerName.contains('phone')) return _ProductType.phone;
    if (lowerName.contains('laptop') || lowerName.contains('macbook') || lowerName.contains('notebook')) return _ProductType.laptop;
    if (lowerName.contains('ipad') || lowerName.contains('tablet')) return _ProductType.tablet;
    switch (product.categoryId) {
      case 1:
        return _ProductType.phone;
      case 2:
        return _ProductType.laptop;
      case 3:
        return _ProductType.tablet;
    }
    return _ProductType.other;
  }

  List<_SpecItem> _parseDescription(String description) {
    final List<_SpecItem> items = [];
    String? currentKey;
    final buffer = StringBuffer();

    void flush() {
      if (currentKey != null && buffer.isNotEmpty) {
        items.add(_SpecItem(currentKey!, buffer.toString().trim()));
      } else if (buffer.isNotEmpty) {
        items.add(_SpecItem('Thông tin', buffer.toString().trim()));
      }
      currentKey = null;
      buffer.clear();
    }

    final lines = description.split(RegExp(r'\r?\n')).map((e) => e.trim());
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = RegExp(r'^([^:]+):\s*(.*)$').firstMatch(line);
      final hasUrl = line.contains('://');
      if (match != null && !hasUrl) {
        flush();
        currentKey = match.group(1)!.trim();
        final value = match.group(2)!.trim();
        if (value.isNotEmpty) buffer.write(value);
        continue;
      }

      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(line);
    }

    flush();
    return items;
  }

  Widget _buildProductDescription(Product product) {
    if (product.description.trim().isEmpty) {
      return const Text('Chưa có mô tả cho sản phẩm này.');
    }

    final type = _detectProductType(product);
    final specs = _parseDescription(product.description);

    switch (type) {
      case _ProductType.phone:
        return _buildPhoneDescription(specs);
      case _ProductType.laptop:
        return _buildLaptopDescription(specs);
      case _ProductType.tablet:
        return _buildTabletDescription(specs);
      case _ProductType.other:
        return Text(product.description);
    }
  }

  Widget _buildPhoneDescription(List<_SpecItem> specs) {
    return _buildSectionedExpansion(_phoneSections, specs);
  }

  Widget _buildLaptopDescription(List<_SpecItem> specs) {
    return _buildSectionedExpansion(_laptopSections, specs);
  }

  Widget _buildTabletDescription(List<_SpecItem> specs) {
    final specMap = _toSpecMap(specs);
    final rows = <TableRow>[];

    for (final key in _tabletOrder) {
      final item = specMap.remove(key);
      if (item != null && item.value.trim().isNotEmpty) {
        rows.add(_buildTabletRow(item.key, item.value));
      }
    }

    for (final item in specMap.values) {
      if (item.value.trim().isEmpty) continue;
      rows.add(_buildTabletRow(item.key, item.value));
    }

    if (rows.isEmpty) {
      return const Text('Thông số kỹ thuật đang được cập nhật.');
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('THÔNG SỐ KỸ THUẬT', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.8),
              },
              border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300)),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: rows,
            ),
          ],
        ),
      ),
    );
  }

  LinkedHashMap<String, _SpecItem> _toSpecMap(List<_SpecItem> specs) {
    final map = LinkedHashMap<String, _SpecItem>();
    for (final item in specs) {
      map.putIfAbsent(item.key, () => item);
    }
    return map;
  }

  Widget _buildSectionedExpansion(
      Map<String, List<String>> sections,
      List<_SpecItem> specs, {
        String fallbackTitle = 'Thông tin khác',
      }) {
    final specMap = _toSpecMap(specs);
    final tiles = <Widget>[];

    sections.forEach((title, keys) {
      final items = <_SpecItem>[];
      for (final key in keys) {
        final item = specMap.remove(key);
        if (item != null && item.value.trim().isNotEmpty) {
          items.add(item);
        }
      }
      if (items.isNotEmpty) {
        tiles.add(_buildExpansionSection(title, items));
      }
    });

    final remaining = specMap.values.where((item) => item.value.trim().isNotEmpty).toList();
    if (remaining.isNotEmpty) {
      tiles.add(_buildExpansionSection(fallbackTitle, remaining));
    }

    if (tiles.isEmpty) {
      return const Text('Thông số kỹ thuật đang được cập nhật.');
    }

    return Column(children: tiles);
  }

  TableRow _buildTabletRow(String title, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _buildValueText(value),
        ),
      ],
    );
  }

  Widget _buildExpansionSection(String title, List<_SpecItem> items) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: items
            .map(
              (item) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                _buildValueText(item.value),
              ],
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildValueText(String value) {
    final lines = value.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

    if (lines.length <= 1) {
      // Nếu chỉ có một dòng mô tả, hiển thị như bình thường
      return Text(value.trim());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(lines[i])),
              ],
            ),
          ),
      ],
    );
  }
}