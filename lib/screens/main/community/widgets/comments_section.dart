import 'package:flutter/material.dart';
import '../../../../utils/theme.dart';
import '../../../../services/api.service.dart';
import 'comment_item.dart';
import '../utils/helpers.dart';

class CommentsSection extends StatefulWidget {
  final String postId;
  final List<Map<String, dynamic>> comments;
  final bool isLoading;
  final Function(Map<String, dynamic>, String?) onCommentPosted;
  final Function(String, bool, int) onCommentLiked;
  final VoidCallback onHide;

  const CommentsSection({
    super.key,
    required this.postId,
    required this.comments,
    required this.isLoading,
    required this.onCommentPosted,
    required this.onCommentLiked,
    required this.onHide,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;
  bool _isPrivate = false;
  String? _replyToId;
  String? _replyToLabel;

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startReply(String commentId, String label) {
    setState(() {
      _replyToId = commentId;
      _replyToLabel = label;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _cancelReply() => setState(() {
    _replyToId = null;
    _replyToLabel = null;
    _ctrl.clear();
  });

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final body = {
        'content': text,
        'isAnonymous': true,
        'isPrivate': _isPrivate,
        if (_replyToId != null) 'parentCommentId': _replyToId,
      };
      final result = await ApiService().post('/community/posts/${widget.postId}/comments', body);
      final comment = Map<String, dynamic>.from(result['comment'] ?? {});
      if (comment['content'] == null) {
        comment['content'] = text;
        comment['createdAt'] = DateTime.now().toIso8601String();
        comment['isPrivate'] = _isPrivate;
        comment['likesCount'] = 0;
        comment['isLiked'] = false;
      }
      widget.onCommentPosted(comment, _replyToId);
      _ctrl.clear();
      _focusNode.unfocus();
      if (mounted) setState(() {
        _sending = false;
        _replyToId = null;
        _replyToLabel = null;
      });
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _likeComment(String commentId) async {
    try {
      final r = await ApiService().post(
          '/community/posts/${widget.postId}/comments/$commentId/like', {});
      widget.onCommentLiked(commentId, r['liked'] as bool, r['likesCount'] as int);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(children: [
            Text('Commentaires', style: AppTextStyles.caption.copyWith(
                color: AppColors.onSurfaceMuted, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: widget.onHide,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Masquer', style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceMuted)),
                const SizedBox(width: 2),
                const Icon(Icons.expand_less, size: 16, color: AppColors.onSurfaceMuted),
              ])),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: Divider(color: AppColors.divider, height: 1)),
        if (widget.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))))
        else if (widget.comments.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text("Sois le premier à commenter…",
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceMuted, fontStyle: FontStyle.italic)))
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(children: widget.comments.map((c) => CommentItem(
              comment: c, depth: 0,
              onReply: _startReply, onLike: _likeComment)).toList())),
        if (_replyToId != null)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07), borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
            child: Row(children: [
              const Icon(Icons.reply, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text('Répondre à ${_replyToLabel ?? "un commentaire"}',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700))),
              GestureDetector(onTap: _cancelReply,
                  child: const Icon(Icons.close, size: 14, color: AppColors.onSurfaceMuted)),
            ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(children: [
            _VisChip(label: '🌐 Public', selected: !_isPrivate, color: AppColors.secondary,
                onTap: () => setState(() => _isPrivate = false)),
            const SizedBox(width: 8),
            _VisChip(label: '🔒 Privé', selected: _isPrivate, color: AppColors.primary,
                onTap: () => setState(() => _isPrivate = true)),
          ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Center(child: Text('👤', style: TextStyle(fontSize: 14)))),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _focusNode.hasFocus
                      ? (_isPrivate ? AppColors.primary : AppColors.secondary).withValues(alpha: 0.5)
                      : AppColors.divider)),
                child: TextField(
                  controller: _ctrl, focusNode: _focusNode, maxLines: 4, minLines: 1,
                  style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                  decoration: InputDecoration(
                    hintText: _replyToId != null
                        ? 'Réponds à ${_replyToLabel ?? "ce commentaire"}…'
                        : (_isPrivate ? "Message privé à l'auteur…" : 'Écris un commentaire…'),
                    hintStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurfaceMuted.withValues(alpha: 0.6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: InputBorder.none, isDense: true),
                ),
              )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: (_isPrivate ? AppColors.primary : AppColors.secondary).withValues(alpha: 0.9),
                    shape: BoxShape.circle),
                child: _sending
                    ? const Padding(padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 16))),
          ])),
      ]),
    );
  }
}

class _VisChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _VisChip({required this.label, required this.selected,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: AppRadius.full,
        border: Border.all(color: selected ? color.withValues(alpha: 0.4) : AppColors.divider)),
      child: Text(label, style: AppTextStyles.caption.copyWith(
          color: selected ? color : AppColors.onSurfaceMuted,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 11)),
    ),
  );
}