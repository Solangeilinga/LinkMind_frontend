import 'package:flutter/material.dart';
import '../../../../utils/theme.dart';
import '../../../../widgets/report_button.dart';
import '../utils/helpers.dart';

class CommentItem extends StatefulWidget {
  final Map<String, dynamic> comment;
  final int depth;
  final Function(String, String) onReply;
  final Function(String) onLike;

  const CommentItem({
    super.key,
    required this.comment,
    required this.depth,
    required this.onReply,
    required this.onLike,
  });

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  late bool _isLiked;
  late int _likesCount;
  late List<Map<String, dynamic>> _replies;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment['isLiked'] == true;
    _likesCount = (widget.comment['likesCount'] ?? 0) as int;
    _replies = _castReplies(widget.comment['replies']);
  }

  @override
  void didUpdateWidget(CommentItem old) {
    super.didUpdateWidget(old);
    final newLiked = widget.comment['isLiked'] == true;
    final newCount = (widget.comment['likesCount'] ?? 0) as int;
    // Toujours synchroniser (l'optimistic update local peut diverger de la réponse serveur)
    _isLiked = newLiked;
    _likesCount = newCount;
    if (!identical(widget.comment['replies'], old.comment['replies'])) {
      _replies = _castReplies(widget.comment['replies']);
    }
  }

  static List<Map<String, dynamic>> _castReplies(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((r) => deepCastComment(r)).toList();
  }

  void _handleLike() {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount = (_likesCount - 1).clamp(0, 999999);
      } else {
        _isLiked = true;
        _likesCount += 1;
      }
    });
    widget.onLike((widget.comment['_id'] ?? '').toString());
  }

  @override
  Widget build(BuildContext context) {
    final commentId = (widget.comment['_id'] ?? '').toString();
    final content = widget.comment['content'] as String? ?? '';
    final isPrivate = widget.comment['isPrivate'] == true;
    final date = fmtDate(widget.comment['createdAt']);
    final alias = (widget.comment['author'] as Map?)?['anonymousAlias'] as String?;
    final displayName = anonName(commentId, alias: alias);
    final accentColor = isPrivate ? AppColors.primary : AppColors.secondary;
    final leftPad = widget.depth * 20.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPad, bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: widget.depth == 0 ? 32 : 26,
            height: widget.depth == 0 ? 32 : 26,
            decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(child: Text(isPrivate ? '🔒' : '🌿',
                style: TextStyle(fontSize: widget.depth == 0 ? 14.0 : 11.0)))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(
                    alpha: widget.depth == 0 ? 0.7 : 0.5),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14)),
                border: isPrivate
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.2))
                    : null),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(isPrivate ? '🔒 $displayName' : displayName,
                      style: AppTextStyles.caption.copyWith(
                          color: accentColor, fontWeight: FontWeight.w800, fontSize: 11)),
                  const Spacer(),
                  Text(date, style: AppTextStyles.caption.copyWith(
                      color: AppColors.onSurfaceMuted, fontSize: 10)),
                ]),
                const SizedBox(height: 3),
                Text(content, style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurface, height: 1.5,
                    fontSize: widget.depth == 0 ? 13.0 : 12.0)),
              ])),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 5),
              child: Row(children: [
                // J'aime
                GestureDetector(
                  onTap: _handleLike,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Row(key: ValueKey(_isLiked), mainAxisSize: MainAxisSize.min, children: [
                      Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: _isLiked ? AppColors.accent : AppColors.onSurfaceMuted),
                      if (_likesCount > 0) ...[
                        const SizedBox(width: 3),
                        Text('$_likesCount', style: AppTextStyles.caption.copyWith(
                          color: _isLiked ? AppColors.accent : AppColors.onSurfaceMuted,
                          fontWeight: FontWeight.w700, fontSize: 11)),
                      ],
                      const SizedBox(width: 5),
                      Text("J'aime", style: AppTextStyles.caption.copyWith(
                        color: _isLiked ? AppColors.accent : AppColors.onSurfaceMuted,
                        fontWeight: _isLiked ? FontWeight.w800 : FontWeight.w600, fontSize: 11)),
                    ]),
                  ),
                ),
                const SizedBox(width: 16),
                // Répondre
                if (widget.depth < 2)
                  GestureDetector(
                    onTap: () => widget.onReply(commentId,
                        isPrivate ? '🔒 Privé' : anonName(commentId, alias: alias)),
                    child: Text('Répondre', style: AppTextStyles.caption.copyWith(
                      color: AppColors.onSurfaceMuted,
                      fontWeight: FontWeight.w700, fontSize: 11))),
                // Signalement
                const SizedBox(width: 16),
                ReportButton(
                  targetType: 'comment',
                  targetId: commentId,
                  isSmall: true,
                ),
              ])),
          ])),
        ]),
        if (_replies.isNotEmpty)
          Column(children: _replies.map((r) => CommentItem(
            comment: r, depth: widget.depth + 1,
            onReply: widget.onReply, onLike: widget.onLike)).toList()),
      ]),
    );
  }
}