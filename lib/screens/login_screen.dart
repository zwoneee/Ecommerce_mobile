// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  final String? nextRoute;
  const LoginScreen({super.key, this.nextRoute});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _userCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.login(_userCtl.text.trim(), _passCtl.text.trim());
      if (success) {
        // đóng màn hình login
        if (Navigator.canPop(context)) Navigator.of(context).pop();
        // chuyển route nếu cần
        if (widget.nextRoute != null) Navigator.of(context).pushNamed(widget.nextRoute!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _userCtl, decoration: const InputDecoration(labelText: 'Username')),
            const SizedBox(height: 8),
            TextField(controller: _passCtl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
