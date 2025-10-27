// lib/services/token_storage_web.dart
// Implementation for web using window.localStorage
import 'dart:html' show window;

class TokenStorage {
  Future<void> saveToken(String token) async {
    try {
      window.localStorage['access_token'] = token;
    } catch (_) {}
  }

  Future<String?> readToken() async {
    try {
      return window.localStorage['access_token'];
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken() async {
    try {
      window.localStorage.remove('access_token');
    } catch (_) {}
  }
}
