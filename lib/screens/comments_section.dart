// lib/screens/comments_section.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
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
  bool _isPosting = false;

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
        } catch (_) {}
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

      _hubService!.on('ReceiveComment', (args) {
        if (args == null || args.isEmpty) return;
        final obj = args.first;
        if (obj is Map) {
          try {
            final cm = CommentModel.fromJson(Map<String, dynamic>.from(obj));
            if (mounted) setState(() => _comments.insert(0, cm));
          } catch (_) {}
        } else if (obj is String) {
          try {
            final parsed = obj.isNotEmpty ? Map<String, dynamic>.from(jsonDecode(obj)) : null;
            if (parsed != null) {
              final cm = CommentModel.fromJson(parsed);
              if (mounted) setState(() => _comments.insert(0, cm));
            }
          } catch (_) {
            if (mounted) {
              setState(() => _comments.insert(
                  0,
                  CommentModel(
                      id: 0,
                      productId: widget.productId,
                      content: obj,
                      userName: 'User',
                      createdAt: DateTime.now())));
            }
          }
        }
      });

      await _hubService!.start(hubPath: '/commenthub');
    } catch (e) {
      print('CommentsSection _connectHub error: $e');
    }
  }

  Future<void> _postComment() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final payload = {'productId': widget.productId, 'content': text};
      await api.postComment(payload);
      _ctl.clear();
      if (mounted) {
        _comments.insert(
            0,
            CommentModel(
                id: 0,
                productId: widget.productId,
                content: text,
                userName: 'You',
                createdAt: DateTime.now()));
        setState(() => _isPosting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send comment'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_comments.length} comment${_comments.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildCommentInput(),
        const SizedBox(height: 12),
        _buildCommentsList(),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctl,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue,
                child: IconButton(
                  icon: _isPosting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: _isPosting ? null : _postComment,
                  padding: EdgeInsets.zero,
                  tooltip: 'Send',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.comment_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No comments yet',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to comment!',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (context, i) {
        final c = _comments[i];
        return _buildCommentCard(c);
      },
    );
  }

  Widget _buildCommentCard(CommentModel comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      (comment.userName ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.userName ?? 'User',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          timeago.format(comment.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('Report'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Comment reported')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                comment.content,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}