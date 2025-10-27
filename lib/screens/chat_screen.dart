// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signalr_core/signalr_core.dart';

import '../services/signalr_service.dart';
import '../providers/auth_provider.dart'; // nếu bạn có AuthProvider

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final SignalRService sr;
  final TextEditingController _ctrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();

    // lấy service từ provider (listen: false vì ở initState)
    sr = Provider.of<SignalRService>(context, listen: false);

    // đăng ký stream message
    sr.messagesStream.listen((m) {
      if (mounted) {
        setState(() => _messages.insert(0, m));
      }
    });

    // nếu bạn có AuthProvider, chỉ start khi đã login
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final shouldStart =
    auth == null ? true : (auth.isAuthenticated == true);

    if (shouldStart) {
      // khởi động connection (nếu chưa connect)
      if (sr.connectionState != HubConnectionState.connected) {
        sr.start().catchError((e) => // ignore: avoid_print
        print('SignalR start err: $e'));
      }
    } else {
      // nếu chưa login, bạn có thể điều hướng tới login hoặc đợi login trigger
      // ignore: avoid_print
      print('ChatScreen: not authenticated, SignalR not started.');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    try {
      // gọi hub method (tên method phải khớp server)
      await sr.invoke('SendMessageToAdmin', args: [
        {'message': text}
      ]);
    } catch (e) {
      // fallback: gọi REST endpoint nếu hub không khả dụng
      await sr.sendChatViaRest({'message': text});
    }
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return ListTile(
                  title: Text(m['message']?.toString() ?? m.toString()),
                  subtitle: m.containsKey('user') ? Text(m['user'].toString()) : null,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(child: TextField(controller: _ctrl)),
                IconButton(icon: const Icon(Icons.send), onPressed: _send)
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
