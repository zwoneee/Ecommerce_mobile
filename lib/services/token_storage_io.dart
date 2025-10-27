// lib/services/token_storage_io.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Implementation for non-web platforms (Android/iOS)
class TokenStorage {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _secure.write(key: 'access_token', value: token);
  }

  Future<String?> readToken() async {
    return await _secure.read(key: 'access_token');
  }

  Future<void> clearToken() async {
    await _secure.delete(key: 'access_token');
  }
}
