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
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  String? _selectedPaymentMethod = 'COD'; // Default method
  bool _loading = false;

  final List<String> _paymentMethods = ['-- Chọn --', 'COD', 'Chuyển khoản', 'VNPay'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);

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

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final delivery = _addressCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || mobile.isEmpty || delivery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final payload = {
        'userId': userId,
        'name': name,
        'email': email,
        'mobile': mobile,
        'items': cart.items
            .map((it) => {
          'productId': it.product.id,
          'quantity': it.quantity,
          'price': it.product.price,
        })
            .toList(),
        'total': cart.total,
        'deliveryLocation': delivery,
        'paymentMethod': _selectedPaymentMethod ?? 'COD',
      };

      final res = await api.createOrder(payload);

      if (res.isNotEmpty && res['id'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đơn hàng #${res['id']} đã được tạo thành công.'),
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
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

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
            // --- Thông tin người dùng ---
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _mobileCtrl,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // --- Địa chỉ giao hàng ---
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Địa điểm giao hàng',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // --- Chọn phương thức thanh toán ---
            DropdownButtonFormField<String>(
              value: _selectedPaymentMethod,
              decoration: const InputDecoration(
                labelText: 'Phương thức thanh toán',
                border: OutlineInputBorder(),
              ),
              items: _paymentMethods.map((String method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value;
                });
              },
            ),
            const SizedBox(height: 20),

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

            // --- Tổng tiền ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tổng tiền: ${cart.total.toStringAsFixed(0)}đ'),
                Text(
                  'Thành tiền: ${cart.total.toStringAsFixed(0)}đ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
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
