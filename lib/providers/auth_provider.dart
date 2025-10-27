// lib/providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService api;
  final SignalRService? signalR;

  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  String? _token;

  AuthProvider({required this.api, this.signalR}) {
    _initialize();
  }

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;
  String? get token => _token;

  Future<void> _initialize() async {
    final t = await api.getToken();
    if (t != null && t.isNotEmpty) {
      _token = t;
      _isAuthenticated = true;
      _tryDecodeUserFromToken(t);
      notifyListeners();
      try {
        if (signalR != null) await signalR!.start();
      } catch (_) {}
    } else {
      _isAuthenticated = false;
      _user = null;
      _token = null;
    }
  }

  void _tryDecodeUserFromToken(String t) {
    try {
      final parts = t.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> map = jsonDecode(decoded);
        if (map.containsKey('user')) {
          _user = Map<String, dynamic>.from(map['user']);
        } else {
          _user = {};
          if (map.containsKey('name')) _user!['name'] = map['name'];
          if (map.containsKey('email')) _user!['email'] = map['email'];
          if (map.containsKey('sub')) _user!['id'] = map['sub'];
        }
      }
    } catch (_) {
      _user = null;
    }
  }

  /// Login: gọi ApiService.login và start SignalR nếu thành công.
  Future<bool> login(String usernameOrEmail, String password) async {
    try {
      final token = await api.login(usernameOrEmail, password);
      if (token != null) {
        _token = token;
        _isAuthenticated = true;
        _tryDecodeUserFromToken(token);
        notifyListeners();
        if (signalR != null) {
          try {
            await signalR!.start();
          } catch (_) {}
        }
        return true;
      } else {
        return false;
      }
    } catch (e) {
      // ignore: avoid_print
      print('AuthProvider.login error: $e');
      return false;
    }
  }

  /// Set token manually (nếu cần)
  Future<void> setToken(String tokenStr) async {
    await api.saveToken(tokenStr);
    _token = tokenStr;
    _isAuthenticated = true;
    _tryDecodeUserFromToken(tokenStr);
    notifyListeners();
    if (signalR != null) {
      try {
        await signalR!.start();
      } catch (_) {}
    }
  }

  Future<void> logout() async {
    await api.clearToken();
    _token = null;
    _isAuthenticated = false;
    _user = null;
    if (signalR != null) {
      try {
        await signalR!.stop();
      } catch (_) {}
    }
    notifyListeners();
  }
}
