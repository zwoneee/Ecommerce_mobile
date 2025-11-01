import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _isPosting = false;
  double _rating = 0;
  final List<File> _mediaFiles = [];
  final picker = ImagePicker();
  SignalRService? _hubService;

  @override
  void initState() {
    super.initState();
    _loadComments();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectHub());
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.getComments(widget.productId);
      _comments
        ..clear()
        ..addAll(list.map((e) => CommentModel.fromJson(Map<String, dynamic>.from(e))));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _connectHub() async {
    try {
      final sr = Provider.of<SignalRService>(context, listen: false);
      _hubService = sr;
      _hubService!.on('ReceiveComment', (args) {
        if (args == null || args.isEmpty) return;
        final obj = args.first;
        try {
          final cm = obj is String
              ? CommentModel.fromJson(jsonDecode(obj))
              : CommentModel.fromJson(Map<String, dynamic>.from(obj as Map? ?? {}));
          if (mounted) setState(() => _comments.insert(0, cm));
        } catch (_) {}
      });
      await _hubService!.start(hubPath: '/commenthub');
    } catch (e) {
      print('ConnectHub error: $e');
    }
  }

  Future<void> _pickMedia() async {
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => _mediaFiles.addAll(picked.map((x) => File(x.path))));
    }
  }

  Future<void> _postComment() async {
    final text = _ctl.text.trim();
    if (text.isEmpty && _mediaFiles.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final payload = {
        'productId': widget.productId,
        'content': text,
        'rating': _rating,
        // TODO: upload media to API and include URLs
      };

      await api.postComment(payload);
      _ctl.clear();
      _rating = 0;
      _mediaFiles.clear();

      setState(() {
        _comments.insert(
            0,
            CommentModel(
              id: 0,
              productId: widget.productId,
              content: text,
              userName: 'You',
              createdAt: DateTime.now(),
              rating: _rating,
              mediaUrls: [],
            ));
        _isPosting = false;
      });
    } catch (e) {
      setState(() => _isPosting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send comment: $e')),
      );
    }
  }

  void _editComment(CommentModel c) async {
    final ctl = TextEditingController(text: c.content);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(controller: ctl, maxLines: 5),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() => c.content = result.trim());
      // TODO: call API to update comment
    }
  }

  void _deleteComment(CommentModel c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _comments.remove(c));
      // TODO: call API to delete comment
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        _buildCommentInput(),
        const SizedBox(height: 8),
        _buildCommentsList(),
      ],
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      'Comments (${_comments.length})',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildCommentInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: List.generate(5, (i) {
              return IconButton(
                icon: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () => setState(() => _rating = i + 1.0),
              );
            }),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.photo),
                  onPressed: _pickMedia,
                ),
                _isPosting
                    ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _postComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('No comments yet.'),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (_, i) => _buildCommentCard(_comments[i]),
    );
  }

  Widget _buildCommentCard(CommentModel c) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              CircleAvatar(child: Text(c.userName[0].toUpperCase())),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(timeago.format(c.createdAt), style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.edit), onPressed: () => _editComment(c)),
              IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteComment(c)),
            ],
          ),
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < c.rating ? Icons.star : Icons.star_border,
                size: 16,
                color: Colors.amber,
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(c.content),
          if (c.mediaUrls.isNotEmpty)
            Wrap(
              spacing: 6,
              children: c.mediaUrls
                  .map((url) => Image.network(url, width: 80, height: 80, fit: BoxFit.cover))
                  .toList(),
            ),
        ]),
      ),
    );
  }
}
