// lib/services/api_service.dart
// Đầy đủ ApiService sử dụng Dio + TokenStorage (conditional)
// Put this file under lib/services/api_service.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'token_storage.dart';

class ApiService {
  final Dio _dio;
  final TokenStorage _storage = TokenStorage();

  ApiService({required String baseUrl})
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
    responseType: ResponseType.json,
  )) {
    // Attach token automatically on every request if present
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      try {
        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {}
      handler.next(options);
    }, onError: (err, handler) {
      // You can handle refresh token logic here if backend provides refresh endpoint
      handler.next(err);
    }));
  }

  String get baseUrl => _dio.options.baseUrl ?? '';

  // -------------------------
  // Token helpers (delegate to TokenStorage)
  // -------------------------
  Future<void> saveToken(String token) async => await _storage.saveToken(token);
  Future<String?> getToken() async => await _storage.readToken();
  Future<void> clearToken() async => await _storage.clearToken();

  // -------------------------
  // AUTH
  // - login: thử gửi variants để tránh mismatch email/username field
  // - loginRaw: trả toàn bộ response
  // -------------------------
  Future<String?> login(String usernameOrEmail, String password) async {
    final variants = <Map<String, dynamic>>[
      {'username': usernameOrEmail, 'email': usernameOrEmail, 'password': password},
      {'email': usernameOrEmail, 'password': password},
      {'username': usernameOrEmail, 'password': password},
    ];

    for (final payload in variants) {
      try {
        final r = await _dio.post(
          '/api/auth/login',
          data: payload,
          options: Options(
            headers: {'Content-Type': 'application/json'},
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        // debug
        // ignore: avoid_print
        print('Login attempt keys=${payload.keys.toList()} status=${r.statusCode}');

        if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300) {
          // tìm token
          if (r.data is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(r.data);
            final token = map['access_token'] ?? map['token'] ?? map['data'] ?? map['tokenString'];
            if (token != null) {
              final tokenStr = token.toString();
              await saveToken(tokenStr);
              // ignore: avoid_print
              print('✅ Stored token (len=${tokenStr.length})');
              return tokenStr;
            }
            // nếu server trả { token: "...", user: {...} }
            if (map.containsKey('token') && map['token'] != null) {
              final tokenStr = map['token'].toString();
              await saveToken(tokenStr);
              return tokenStr;
            }
          } else if (r.data != null) {
            final tokenStr = r.data.toString();
            await saveToken(tokenStr);
            // ignore: avoid_print
            print('✅ Stored token (len=${tokenStr.length}) (string response)');
            return tokenStr;
          }
          return null; // 2xx nhưng không thấy token
        } else {
          // non-2xx: debug thông báo server
          // ignore: avoid_print
          print('Login failed keys=${payload.keys.toList()} status=${r.statusCode} body=${r.data}');
        }
      } on DioException catch (e) {
        // ignore: avoid_print
        print('DioException login keys=${payload.keys.toList()} status=${e.response?.statusCode} body=${e.response?.data}');
        // nếu server error lớn hơn 500 thì rethrow
        if (e.response?.statusCode == null || (e.response!.statusCode! >= 500)) rethrow;
      } catch (e) {
        // ignore: avoid_print
        print('Unknown login error: $e');
      }
    }

    return null;
  }

  Future<Map<String, dynamic>> loginRaw(String usernameOrEmail, String password) async {
    final token = await login(usernameOrEmail, password);
    return {'token': token};
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String name,
    required String email,
  }) async {
    try {
      final response = await _dio.post(
        '/api/auth/register',
        data: {
          'userName': username,
          'password': password,
          'name': name,
          'email': email,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final success = response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300;
      String? message;

      final data = response.data;
      if (data is Map<String, dynamic>) {
        message = data['message']?.toString() ?? data['error']?.toString();
      } else if (data != null) {
        message = data.toString();
      }

      return {
        'success': success,
        if (message != null && message.isNotEmpty) 'message': message,
      };
    } on DioException catch (e) {
      String? message;
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        message = data['message']?.toString() ?? data['error']?.toString();
      } else if (data != null) {
        message = data.toString();
      }
      return {
        'success': false,
        if (message != null && message.isNotEmpty) 'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<void> logout() async {
    await clearToken();
  }

  // -------------------------
  // PRODUCTS
  // -------------------------
  Future<Map<String, dynamic>> fetchProducts({int page = 1, int pageSize = 20}) async {
    final r = await _dio.get('/api/public/products', queryParameters: {'page': page, 'pageSize': pageSize});
    if (r.data is Map<String, dynamic>) return Map<String, dynamic>.from(r.data);
    return {'products': r.data};
  }

  Future<Map<String, dynamic>?> getProductDetail(int id) async {
    final r = await _dio.get('/api/public/products/$id');
    if (r.data == null) return null;
    return Map<String, dynamic>.from(r.data);
  }

  // -------------------------
  // COMMENTS
  // -------------------------
  Future<List<dynamic>> getComments(int productId) async {
    final r = await _dio.get('/api/Comments/product/$productId');
    return r.data as List<dynamic>;
  }

  Future<dynamic> postComment(Map<String, dynamic> payload) async => (await _dio.post('/api/Comments', data: payload)).data;

  // -------------------------
  // CART / ORDERS
  // -------------------------
  Future<dynamic> getCart() async => (await _dio.get('/api/user/cart')).data;
  Future<dynamic> addToCart({required int productId, required int quantity}) async => (await _dio.post('/api/user/cart/items', data: {'productId': productId, 'quantity': quantity})).data;
  Future<dynamic> removeFromCart(int productId) async => (await _dio.delete('/api/user/cart/items/$productId')).data;
  Future<int> getCartCount() async {
    final r = await _dio.get('/api/user/cart/count');
    return (r.data is int) ? r.data as int : int.tryParse(r.data.toString()) ?? 0;
  }
  Future<dynamic> checkoutCart(Map<String, dynamic> payload) async => (await _dio.post('/api/user/cart/checkout', data: payload)).data;

// -------------------------
// CHAT (REST)
// -------------------------
  Future<Map<String, dynamic>> sendChatAsCustomer(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '/api/chat/customer/send',
      data: payload,
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data as Map);
    }

    if (response.data is String && (response.data as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(response.data as String);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return {
      ...payload,
      'sentAt': DateTime.now().toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> getChatHistory({int? withUserId, int? limit}) async {
    final params = <String, dynamic>{};
    if (withUserId != null) params['withUserId'] = withUserId;
    if (limit != null) params['limit'] = limit;

    final response = await _dio.get(
      '/api/chat/history',
      queryParameters: params.isEmpty ? null : params,
    );

    if (response.data is List) {
      return (response.data as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (response.data is String) {
      try {
        final decoded = jsonDecode(response.data as String);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }

    return const <Map<String, dynamic>>[];
  }
  Future<List<dynamic>> getChatUsers() async => (await _dio.get('/api/chat/users')).data as List<dynamic>;

  Future<dynamic> uploadChatFile(String filePath) async {
    final file = await MultipartFile.fromFile(filePath, filename: filePath.split('/').last);
    final form = FormData.fromMap({'file': file});
    final r = await _dio.post('/api/chat/upload', data: form);
    return r.data;
  }

  // -------------------------
  // ADMIN helpers
  // -------------------------
  Future<Map<String, dynamic>> getAdminStatistics() async => Map<String, dynamic>.from((await _dio.get('/api/admin/statistics')).data);
  Future<List<dynamic>> getAdminInventory() async => (await _dio.get('/api/admin/inventory')).data as List<dynamic>;
  Future<List<dynamic>> getAdminChatHistory() async => (await _dio.get('/api/admin/chat/history')).data as List<dynamic>;
  Future<dynamic> adminSendChat(Map<String, dynamic> payload) async => (await _dio.post('/api/admin/chat/send', data: payload)).data;
}