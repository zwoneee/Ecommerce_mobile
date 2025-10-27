// lib/screens/chat_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:signalr_core/signalr_core.dart';

import '../models/chat_message.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final SignalRService _signalRService;
  late final ApiService _apiService;
  AuthProvider? _auth;
  bool _wasAuthenticated = false;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = <ChatMessage>[];
  final DateFormat _timeFormatter = DateFormat('HH:mm dd/MM');

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  bool _loadingHistory = false;
  bool _sending = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _signalRService = Provider.of<SignalRService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    _auth = Provider.of<AuthProvider>(context, listen: false);
    _wasAuthenticated = _auth?.isAuthenticated ?? false;

    _messageSubscription = _signalRService.messagesStream.listen(_onRealtimeMessage);

    if (_wasAuthenticated) {
      _ensureConnection();
      _loadHistory();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    if (!identical(_auth, auth)) {
      _auth = auth;
    }

    final isAuthenticated = auth.isAuthenticated;
    if (isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      _ensureConnection();
      _loadHistory();
    } else if (!isAuthenticated && _wasAuthenticated) {
      _wasAuthenticated = false;
      setState(() {
        _messages.clear();
        _historyError = null;
        _loadingHistory = false;
      });
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureConnection() async {
    if (_auth?.isAuthenticated != true) return;
    if (_signalRService.connectionState == HubConnectionState.connected) return;

    try {
      await _signalRService.start();
    } catch (e) {
      // ignore: avoid_print
      print('SignalR start error: $e');
    }
  }

  Future<void> _loadHistory() async {
    if (_auth?.isAuthenticated != true) return;
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });

    try {
      final history = await _apiService.getChatHistory();
      final parsed = history.map(ChatMessage.fromJson).toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(parsed);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
      });
    }
  }

  void _onRealtimeMessage(Map<String, dynamic> payload) {
    try {
      final message = ChatMessage.fromJson(payload);
      final currentUserId = _auth?.userId;
      if (currentUserId != null) {
        final isParticipant = message.fromUserId == currentUserId || message.toUserId == currentUserId;
        if (!isParticipant) return;
      }
      _addOrUpdateMessage(message);
    } catch (e) {
      // ignore: avoid_print
      print('Không thể parse message realtime: $e');
    }
  }

  void _addOrUpdateMessage(ChatMessage message) {
    if (!mounted) return;
    setState(() {
      final existingIndex = _messages.indexWhere(
            (element) => element.id != null && message.id != null && element.id == message.id,
      );
      if (existingIndex >= 0) {
        _messages[existingIndex] = message;
      } else {
        _messages.add(message);
      }
      _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    if (_auth?.isAuthenticated != true) {
      _openLogin();
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final result = await _signalRService.sendChatViaRest({'content': text});
      final message = ChatMessage.fromJson(result);
      _addOrUpdateMessage(message);
      _messageController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gửi tin nhắn thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(nextRoute: '/chat'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = _auth?.isAuthenticated ?? false;
    final currentUserId = _auth?.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trò chuyện cùng cửa hàng'),
        actions: [
          if (isAuthenticated)
            IconButton(
              tooltip: 'Làm mới',
              onPressed: _loadingHistory ? null : _loadHistory,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildConversationArea(isAuthenticated, currentUserId)),
          _buildInputArea(isAuthenticated),
        ],
      ),
    );
  }

  Widget _buildConversationArea(bool isAuthenticated, int? currentUserId) {
    if (!isAuthenticated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Bạn cần đăng nhập để bắt đầu trò chuyện với đội ngũ hỗ trợ.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openLogin,
                child: const Text('Đăng nhập ngay'),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Không thể tải lịch sử chat.\n$_historyError',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadHistory,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Chưa có cuộc trò chuyện nào. Hãy gửi tin nhắn đầu tiên cho chúng tôi!',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        return _buildMessageBubble(message, currentUserId);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int? currentUserId) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMine = currentUserId != null && message.fromUserId == currentUserId;

    final bubbleColor = isMine ? scheme.primary : scheme.surfaceVariant;
    final textColor = isMine ? scheme.onPrimary : scheme.onSurface;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 18),
    );

    final children = <Widget>[];

    if (message.hasAttachment) {
      if (message.isImageAttachment) {
        children.add(
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              message.fileUrl!,
              width: 220,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 220,
                height: 120,
                color: scheme.errorContainer,
                alignment: Alignment.center,
                child: Text(
                  'Không hiển thị được ảnh',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          ),
        );
      } else {
        children.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                message.isVideoAttachment ? Icons.videocam_outlined : Icons.attach_file,
                color: textColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: SelectableText(
                  message.fileName ?? message.fileUrl ?? 'Tệp đính kèm',
                  style: TextStyle(
                    color: textColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      if (message.hasText) {
        children.add(const SizedBox(height: 8));
      }
    }

    if (message.hasText) {
      children.add(
        SelectableText(
          message.content,
          style: TextStyle(color: textColor),
        ),
      );
    }

    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          _timeFormatter.format(message.sentAt),
          style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11),
        ),
      ),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
        ),
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isAuthenticated) {
    if (!isAuthenticated) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Đăng nhập để trò chuyện cùng nhân viên hỗ trợ.'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openLogin,
                  child: const Text('Đăng nhập'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Nhập nội dung tin nhắn...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.send),
              color: Theme.of(context).colorScheme.primary,
              tooltip: 'Gửi tin nhắn',
            ),
          ],
        ),
      ),
    );
  }
}
