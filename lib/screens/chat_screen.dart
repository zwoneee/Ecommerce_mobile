// lib/screens/chat_screen.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/auth_provider.dart';
import '../services/signalr_service.dart';

class _ChatMessageView {
  final String key;
  final String message;
  final bool isAdmin;
  final String userName;
  final DateTime timestamp;

  const _ChatMessageView({
    required this.key,
    required this.message,
    required this.isAdmin,
    required this.userName,
    required this.timestamp,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final SignalRService sr;
  final TextEditingController _ctrl = TextEditingController();
  final List<_ChatMessageView> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final Set<String> _messageKeys = <String>{};
  StreamSubscription<Map<String, dynamic>>? _messagesSubscription;
  bool _isLoading = false;
  bool _isConnected = false;
  bool _hasText = false;
  bool _isHistoryLoading = true;
  int? _currentUserId;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();

    sr = Provider.of<SignalRService>(context, listen: false);
    _ctrl.addListener(_onTextChanged);

    final auth = Provider.of<AuthProvider?>(context, listen: false);
    _currentUserId = auth?.userId;
    _currentUserName = auth?.user?['name']?.toString();

    // Đăng ký stream message
    _messagesSubscription = sr.messagesStream.listen((m) {
      final entry = _mapToViewModel(m);
      if (entry != null) {
        _addMessage(entry, scroll: true);
      }
    });

    final shouldStart = auth == null ? true : (auth.isAuthenticated == true);

    _loadInitialMessages();

    if (shouldStart) {
      if (sr.connectionState != HubConnectionState.connected) {
        _initializeConnection();
      } else {
        setState(() => _isConnected = true);
      }
    } else {
      print('ChatScreen: not authenticated, SignalR not started.');
    }
  }

  Future<void> _initializeConnection() async {
    try {
      await sr.start();
      if (mounted) {
        setState(() => _isConnected = true);
      }
    } catch (e) {
      print('SignalR start err: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to connect to chat');
      }
    }
  }

  Future<void> _loadInitialMessages() async {
    try {
      final history = await sr.fetchChatHistory(limit: 50);
      final items = <_ChatMessageView>[];
      for (final raw in history) {
        final view = _mapToViewModel({...raw, '__method': 'history'});
        if (view != null) {
          items.add(view);
        }
      }
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!mounted) return;
      setState(() {
        _isHistoryLoading = false;
        for (final entry in items) {
          if (_messageKeys.add(entry.key)) {
            _messages.add(entry);
          }
        }
        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() => _isHistoryLoading = false);
        _showErrorSnackBar('Failed to load chat history');
      }
    }
  }

  void _addMessage(_ChatMessageView entry, {bool scroll = false}) {
    if (!_messageKeys.add(entry.key)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _messages.insert(0, entry);
    });
    if (scroll) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    final payload = {
      'message': text,
      'content': text,
    };

    try {
      await sr.sendChatMessage(payload);
      _ctrl.clear();
    } catch (e) {
      debugPrint('SignalR send failed, falling back to REST: $e');
      try {
        await sr.sendChatViaRest(payload);
        _ctrl.clear();
      } catch (restError) {
        debugPrint('REST send failed: $restError');
        _showErrorSnackBar('Failed to send message');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onTextChanged() {
    final hasText = _ctrl.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chat Support',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'Online' : 'Connecting...',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isConnected ? Colors.green : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black87),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Chat with our support team'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isHistoryLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to start chatting',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        final isAdmin = m.isAdmin;
        final message = m.message;
        final userName = m.userName;
        final timestamp = m.timestamp;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _buildMessageBubble(
            message: message,
            isAdmin: isAdmin,
            userName: userName,
            timestamp: timestamp,
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isAdmin,
    required String userName,
    required DateTime timestamp,
  }) {
    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
          isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  userName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAdmin ? Colors.white : Colors.blue.shade500,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isAdmin ? Border.all(color: Colors.grey.shade200) : null,
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: isAdmin ? Colors.black87 : Colors.white,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                timeago.format(timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    minLines: 1,
                    enabled: _isConnected,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: _isConnected
                          ? 'Type a message...'
                          : 'Connecting...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _isConnected && _hasText
                      ? Colors.blue.shade500
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (_isConnected && _hasText && !_isLoading)
                        ? _send
                        : null,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _isLoading
                          ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                          : Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ChatMessageView? _mapToViewModel(Map<String, dynamic> raw) {
    try {
      final map = raw.map((key, value) => MapEntry(key.toString(), value));
      final method = map['__method']?.toString().toLowerCase();
      if (method != null && method.contains('comment')) {
        return null;
      }

      String? message = _firstNonEmptyString(map, const [
        'message',
        'content',
        'text',
        'body',
        'payload',
      ]);

      if (message == null || message.trim().isEmpty) {
        final data = map['data'];
        if (data is Map) {
          final mapped = Map<String, dynamic>.from(data.map((key, value) => MapEntry(key.toString(), value)));
          message = _firstNonEmptyString(mapped, const ['message', 'content', 'text']);
        }
      }

      if (message == null || message.trim().isEmpty) {
        return null;
      }

      final fromUserId = _parseInt(_firstNonEmpty(map, const [
        'fromUserId',
        'from',
        'senderId',
        'sender',
        'userId',
      ]));

      bool? isAdmin = _parseBool(_firstNonEmpty(map, const [
        'isAdmin',
        'fromAdmin',
        'isStaff',
        'isSupport',
        'fromSupport',
      ]));

      final senderRole = _firstNonEmptyString(map, const [
        'senderRole',
        'role',
        'fromRole',
      ]);
      if (isAdmin == null && senderRole != null) {
        final lower = senderRole.toLowerCase();
        if (lower.contains('admin') || lower.contains('staff') || lower.contains('support')) {
          isAdmin = true;
        } else if (lower.contains('customer') || lower.contains('user')) {
          isAdmin = false;
        }
      }

      if (isAdmin == null && _currentUserId != null && fromUserId != null) {
        isAdmin = fromUserId != _currentUserId;
      }

      final timestamp = _parseDate(_firstNonEmpty(map, const [
        'sentAt',
        'createdAt',
        'timestamp',
        'time',
        'sentAtUtc',
      ]));

      String? userName = _firstNonEmptyString(map, const [
        'userName',
        'username',
        'senderName',
        'fromName',
        'staffName',
        'adminName',
        'agentName',
        'supportName',
        'name',
      ]);

      if (userName == null || userName.isEmpty) {
        if (isAdmin == true) {
          userName = 'Support';
        } else if (_currentUserName != null && _currentUserName!.isNotEmpty) {
          userName = _currentUserName!;
        } else {
          userName = 'You';
        }
      }

      final idCandidate = _firstNonEmptyString(map, const [
        'id',
        'messageId',
        'chatId',
        'conversationId',
        'historyId',
      ]);

      final key = idCandidate ?? '${fromUserId ?? 'na'}-${timestamp.millisecondsSinceEpoch}-${message.hashCode}';

      return _ChatMessageView(
        key: key,
        message: message,
        isAdmin: isAdmin ?? false,
        userName: userName,
        timestamp: timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  dynamic _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final value = map[key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return value;
    }
    return null;
  }

  String? _firstNonEmptyString(Map<String, dynamic> map, List<String> keys) {
    final value = _firstNonEmpty(map, keys);
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {}
    }
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
      } catch (_) {}
    }
    return DateTime.now();
  }

  bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    if (value is num) {
      return value != 0;
    }
    return null;
  }
}