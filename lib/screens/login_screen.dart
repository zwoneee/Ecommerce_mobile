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

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  void _handleSuccessNavigation() {
    if (Navigator.canPop(context)) Navigator.of(context).pop();
    if (widget.nextRoute != null) {
      Navigator.of(context).pushNamed(widget.nextRoute!);
    }
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final username = _userCtl.text.trim();
    final password = _passCtl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnack('Vui lòng nhập tên đăng nhập và mật khẩu.', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.login(username, password);
      if (success) {
        _handleSuccessNavigation();
      } else {
        _showSnack('Đăng nhập không thành công.', isError: true);
      }
    } catch (e) {
      _showSnack('Đã xảy ra lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRegister() async {
    if (_loading) return;
    final result = await Navigator.of(context).pushNamed<bool>('/register');
    if (result == true) {
      _handleSuccessNavigation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                TextField(
                controller: _userCtl,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Username'),
                enabled: !_loading,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtl,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                enabled: !_loading,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Login'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading ? null : _openRegister,
                child: const Text('Chưa có tài khoản? Đăng ký'),
              ),
                ],
              ),
            ),
        ),
    );
  }
}