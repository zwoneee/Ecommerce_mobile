// lib/services/signalr_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:signalr_core/signalr_core.dart';
import 'api_service.dart';

typedef HubHandler = void Function(List<Object?>? args);

class SignalRService {
  final ApiService api;
  HubConnection? _connection;

  // stream để UI (ChatScreen, CommentsSection...) lắng nghe message
  final StreamController<Map<String, dynamic>> _messagesController = StreamController.broadcast();

  static const List<String> _defaultBroadcastMethods = [
    'ReceiveMessage',
    'ReceiveMessageToCustomer',
    'ReceiveCustomerMessage',
    'ReceiveMessageFromAdmin',
    'ReceiveSupportMessage',
    'ReceiveChatMessage',
    'ReceiveMessageToClient',
    'ReceiveComment',
  ];

  // lưu handlers nếu register trước khi connection sẵn sàng
  final Map<String, HubHandler> _pendingHandlers = {};

  SignalRService({required this.api});

  /// Public: stream message (map). UI dùng .listen(...)
  Stream<Map<String, dynamic>> get messagesStream => _messagesController.stream;

  HubConnectionState? get connectionState => _connection?.state;

  /// Start connection to a hub path (default '/chathub').
  Future<void> start({String hubPath = '/chathub'}) async {
    // already connected?
    if (_connection != null && _connection!.state == HubConnectionState.connected) return;

    final base = api.baseUrl.replaceAll(RegExp(r'/$'), '');
    final hubUrl = '$base${hubPath.startsWith('/') ? hubPath : '/$hubPath'}';

    // stop old if any
    if (_connection != null) {
      try {
        await _connection!.stop();
      } catch (_) {}
      _connection = null;
    }

    _connection = HubConnectionBuilder().withUrl(
      hubUrl,
      HttpConnectionOptions(
        accessTokenFactory: () async {
          try {
            final token = await api.getToken();
            // do not print token value in production
            // ignore: avoid_print
            print('SignalR: accessToken available=${token != null && token.isNotEmpty}');
            return token ?? '';
          } catch (_) {
            return '';
          }
        },
      ),
    ).build();

    // attach pending handlers
    _pendingHandlers.forEach((method, handler) {
      try {
        _connection!.on(method, handler);
      } catch (e) {
        // ignore registration error
        // ignore: avoid_print
        print('SignalR register handler error for $method: $e');
      }
    });

    // default onclose: try reconnect
    _connection!.onclose((error) {
      // ignore: avoid_print
      print('SignalR onclose: $error');
      _tryReconnect(hubPath: hubPath);
    });

    // default handler: if server sends generic messages we push into messagesStream
    // but we DO NOT override handlers registered via on(...)
    for (final method in _defaultBroadcastMethods) {
      try {
        _connection!.on(method, (args) => _handleIncoming(method, args));
      } catch (e) {
        // ignore: avoid_print
        print('SignalR register default handler error for $method: $e');
      }
    }

    try {
      await _connection!.start();
      // ignore: avoid_print
      print('SignalR connected to $hubUrl (state=${_connection!.state})');
    } catch (e) {
      // ignore: avoid_print
      print('SignalR start error: $e');
      rethrow;
    }
  }

  /// Register a handler for a server-invoked method (e.g. 'ReceiveComment').
  /// If connection exists and is connected, registers immediately; otherwise stores pending.
  void on(String method, HubHandler handler) {
    _pendingHandlers[method] = handler;
    try {
      if (_connection != null && _connection!.state == HubConnectionState.connected) {
        _connection!.on(method, handler);
      }
    } catch (e) {
      // ignore: avoid_print
      print('SignalR.on register error: $e');
    }
  }

  /// Invoke hub method.
  Future<dynamic> invoke(String methodName, {List<Object?>? args}) async {
    if (_connection == null || _connection!.state != HubConnectionState.connected) {
      await start(); // best-effort start
    }
    return await _connection?.invoke(methodName, args: args);
  }

  Future<void> sendChatMessage(Map<String, dynamic> payload) async {
    final data = Map<String, dynamic>.from(payload);
    final methods = [
      'SendMessageToAdmin',
      'SendMessageToAdminAsync',
      'SendMessage',
      'SendMessageAsync',
      'SendCustomerMessage',
      'SendChatMessage',
    ];

    Object? lastError;
    for (final method in methods) {
      try {
        await invoke(method, args: [data]);
        return;
      } catch (e) {
        if (_isMethodMissingError(e)) {
          lastError = e;
          continue;
        }
        rethrow;
      }
    }
    if (lastError != null) {
      throw lastError!;
    }
  }

  bool _isMethodMissingError(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('method does not exist');
  }

  Future<List<Map<String, dynamic>>> fetchChatHistory({int? withUserId, int? limit}) async {
    final list = await api.getChatHistory(withUserId: withUserId, limit: limit);
    return list
        .map((e) {
      try {
        return Map<String, dynamic>.from(e);
      } catch (_) {
        return <String, dynamic>{};
      }
    })
        .where((element) => element.isNotEmpty)
        .toList();
  }

  /// Stop connection
  Future<void> stop() async {
    try {
      await _connection?.stop();
    } catch (_) {}
    _connection = null;
  }

  void dispose() {
    _messagesController.close();
    stop();
  }

  // Fallback: call REST endpoint to send chat (if hub not available)
  Future<Map<String, dynamic>> sendChatViaRest(Map<String, dynamic> payload) async {
    try {
      final message = await api.sendChatAsCustomer(payload);
      // Push to listeners so UI gets immediate update even without SignalR.
      final normalized = Map<String, dynamic>.from(message);
      normalized['__method'] = 'REST';
      _messagesController.add(normalized);
      return message;
    } catch (e) {
      rethrow;
    }
  }

  // internal: convert incoming args into Map and add to stream
  void _handleIncoming(String method, List<Object?>? args) {
    try {
      if (args == null || args.isEmpty) {
        _messagesController.add({'__method': method});
        return;
      }
      final first = args.first;
      if (first is Map) {
        final mapped = first.map((key, value) => MapEntry(key.toString(), value));
        mapped['__method'] = method;
        _messagesController.add(Map<String, dynamic>.from(mapped));
      } else if (first is String) {
        try {
          final decoded = jsonDecode(first);
          if (decoded is Map) {
            final mapped = decoded.map((key, value) => MapEntry(key.toString(), value));
            mapped['__method'] = method;
            _messagesController.add(Map<String, dynamic>.from(mapped));
          } else {
            _messagesController.add({'__method': method, 'message': first});
          }
        } catch (_) {
          // if cannot parse, wrap raw string
          _messagesController.add({'__method': method, 'message': first});
        }
      } else {
        _messagesController.add({'__method': method, 'payload': first.toString()});
      }
    } catch (_) {
      // ignore
    }
  }

  // simple reconnect with delays (ms)
  Future<void> _tryReconnect({String hubPath = '/chathub'}) async {
    const delays = [1000, 2000, 5000];

    for (final d in delays) {
      // Nếu connection đã bị null -> tạo mới lại luôn
      if (_connection == null) {
        print('⚠️ _connection is null, reinitializing...');
        await start(hubPath: hubPath);
        if (_connection?.state == HubConnectionState.connected) {
          print('✅ Reconnected successfully after reinit');
          return;
        }
      }

      // Nếu vẫn còn connection nhưng chưa connected -> thử restart
      if (_connection!.state != HubConnectionState.connected) {
        print('SignalR reconnect in ${d}ms...');
        await Future.delayed(Duration(milliseconds: d));

        try {
          await _connection!.start();
          print('✅ SignalR reconnected successfully.');
          return;
        } catch (e) {
          print('❌ Reconnect attempt failed: $e');
        }
      } else {
        print('ℹ️ Already connected, skip reconnect');
        return;
      }
    }

    print('❌ SignalR failed to reconnect after all attempts.');
  }
}
