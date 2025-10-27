// lib/screens/comments_section.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../models/comment.dart';
import '../services/signalr_service.dart';

class CommentsSection extends StatefulWidget {
  final int productId;
  const CommentsSection({super.key, required this.productId});
  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final TextEditingController _ctl = TextEditingController();
  final List<CommentModel> _comments = [];
  bool _loading = true;
  SignalRService? _hubService;

  @override
  void initState() {
    super.initState();
    _loadComments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectHub();
    });
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.getComments(widget.productId);
      _comments.clear();
      for (final e in list) {
        try {
          _comments.add(CommentModel.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {
          // ignore malformed item
        }
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectHub() async {
    try {
      final sr = Provider.of<SignalRService>(context, listen: false);
      _hubService = sr;

      // register handler BEFORE start (safe)
      _hubService!.on('ReceiveComment', (args) {
        if (args == null || args.isEmpty) return;
        final obj = args.first;
        if (obj is Map) {
          try {
            final cm = CommentModel.fromJson(Map<String, dynamic>.from(obj));
            if (mounted) setState(() => _comments.insert(0, cm));
          } catch (_) {}
        } else if (obj is String) {
          // server might send JSON string
          try {
            final parsed = obj.isNotEmpty ? Map<String, dynamic>.from(jsonDecode(obj)) : null;
            if (parsed != null) {
              final cm = CommentModel.fromJson(parsed);
              if (mounted) setState(() => _comments.insert(0, cm));
            }
          } catch (_) {
            if (mounted) setState(() => _comments.insert(0, CommentModel(id: 0, productId: widget.productId, content: obj, userName: 'User', createdAt: DateTime.now())));
          }
        } else {
          if (mounted) setState(() => _comments.insert(0, CommentModel(id: 0, productId: widget.productId, content: obj.toString(), userName: 'User', createdAt: DateTime.now())));
        }
      });

      // start connection to commenthub (this uses ApiService.getToken internally)
      await _hubService!.start(hubPath: '/commenthub');
    } catch (e) {
      // ignore connection error for now
      // ignore: avoid_print
      print('CommentsSection _connectHub error: $e');
    }
  }

  Future<void> _postComment() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final payload = {'productId': widget.productId, 'content': text};
      await api.postComment(payload);
      _ctl.clear();
      // optimistic UI: add temporary comment (server should broadcast actual one)
      if (mounted) {
        _comments.insert(0, CommentModel(id: 0, productId: widget.productId, content: text, userName: 'You', createdAt: DateTime.now()));
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Send comment failed')));
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Comments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _loading
          ? const Center(child: CircularProgressIndicator())
          : _comments.isEmpty
          ? const Text('No comments yet')
          : ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _comments.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, i) {
          final c = _comments[i];
          return ListTile(
            title: Text(c.userName ?? 'User'),
            subtitle: Text(c.content),
            trailing: Text(c.createdAt.toLocal().toString().split(' ')[0]),
          );
        },
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: _ctl, decoration: const InputDecoration(hintText: 'Write a comment'))),
        IconButton(onPressed: _postComment, icon: const Icon(Icons.send))
      ]),
    ]);
  }
}
