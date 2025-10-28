// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/signalr_service.dart';
import '../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final SignalRService sr;
  final TextEditingController _ctrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();

    sr = Provider.of<SignalRService>(context, listen: false);

    // Đăng ký stream message
    sr.messagesStream.listen((m) {
      if (mounted) {
        setState(() => _messages.insert(0, m));
        _scrollToBottom();
      }
    });

    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final shouldStart = auth == null ? true : (auth.isAuthenticated == true);

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

    try {
      await sr.invoke('SendMessageToAdmin', args: [
        {'message': text}
      ]);
      _ctrl.clear();
    } catch (e) {
      print('Error sending message: $e');
      try {
        await sr.sendChatViaRest({'message': text});
        _ctrl.clear();
      } catch (restError) {
        _showErrorSnackBar('Failed to send message');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    _ctrl.dispose();
    _scrollController.dispose();
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
        final isAdmin = m['isAdmin'] ?? false;
        final message = m['message']?.toString() ?? '';
        final userName = m['user']?.toString() ?? 'Support';
        final timestamp = m['timestamp'] as DateTime? ?? DateTime.now();

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
                  color: _isConnected && _ctrl.text.isNotEmpty
                      ? Colors.blue.shade500
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (_isConnected && _ctrl.text.isNotEmpty && !_isLoading)
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
}