import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _paymentCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _paymentCtrl.dispose();
    super.dispose();
  }

  /// Hàm tính giảm giá (nếu tổng >= 500 thì giảm 10%)
  Map<String, double> _calculateDiscount(double total) {
    const discountThreshold = 500.0;
    const discountPercent = 10.0;

    if (total >= discountThreshold) {
      final discountAmount = total * discountPercent / 100;
      final finalTotal = total - discountAmount;
      return {
        'percent': discountPercent,
        'amount': discountAmount,
        'finalTotal': finalTotal,
      };
    } else {
      return {
        'percent': 0,
        'amount': 0,
        'finalTotal': total,
      };
    }
  }

  Future<void> _checkout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để tiếp tục thanh toán.')),
      );
      return;
    }

    final userId = auth.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xác định người dùng. Vui lòng đăng nhập lại.')),
      );
      return;
    }

    final delivery = _addressCtrl.text.trim();
    if (delivery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa điểm giao hàng.')),
      );
      return;
    }

    // Tính giảm giá
    final discountData = _calculateDiscount(cart.total);
    final discountPercent = discountData['percent']!;
    final discountAmount = discountData['amount']!;
    final finalTotal = discountData['finalTotal']!;

    setState(() => _loading = true);

    try {
      final payload = {
        'userId': userId,
        'items': cart.items
            .map((it) => {
          'productId': it.product.id,
          'quantity': it.quantity,
          'price': it.product.price,
        })
            .toList(),
        'total': finalTotal,
        'deliveryLocation': delivery,
        'paymentMethod': _paymentCtrl.text.isEmpty ? 'COD' : _paymentCtrl.text,
      };

      final res = await ApiService(baseUrl: 'https://your-api-domain.com')
          .createOrder(payload);

      if (res.isNotEmpty && res['id'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Đơn hàng #${res['id']} đã được tạo thành công.\n'
                  'Giảm giá: ${discountPercent.toInt()}% (${discountAmount.toStringAsFixed(2)}đ)',
            ),
          ),
        );

        cart.clear();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Lỗi khi tạo đơn hàng.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Thanh toán thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final discountData = _calculateDiscount(cart.total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- Danh sách sản phẩm ---
            Expanded(
              child: ListView.builder(
                itemCount: cart.items.length,
                itemBuilder: (context, index) {
                  final item = cart.items[index];
                  return ListTile(
                    leading: item.product.thumbnailUrl.isNotEmpty
                        ? Image.network(item.product.thumbnailUrl, width: 60, fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported),
                    title: Text(item.product.name),
                    subtitle: Text(
                      '${item.quantity} x ${item.product.price.toStringAsFixed(0)}đ',
                    ),
                    trailing: Text(
                      '${(item.product.price * item.quantity).toStringAsFixed(0)}đ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // --- Tổng tiền + giảm giá ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tổng tiền: ${cart.total.toStringAsFixed(0)}đ'),
                if (discountData['percent']! > 0)
                  Text(
                    'Giảm giá: ${discountData['percent']}% (-${discountData['amount']!.toStringAsFixed(0)}đ)',
                    style: const TextStyle(color: Colors.green),
                  ),
                Text(
                  'Thành tiền: ${discountData['finalTotal']!.toStringAsFixed(0)}đ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- Nhập địa chỉ giao hàng ---
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Địa điểm giao hàng',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            // --- Nhập phương thức thanh toán ---
            TextField(
              controller: _paymentCtrl,
              decoration: const InputDecoration(
                labelText: 'Phương thức thanh toán (ví dụ: COD, Momo...)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // --- Nút xác nhận thanh toán ---
            ElevatedButton.icon(
              onPressed: _checkout,
              icon: const Icon(Icons.payment),
              label: const Text('Xác nhận & Thanh toán'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
