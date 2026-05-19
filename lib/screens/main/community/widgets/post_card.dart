import 'package:flutter/material.dart';
import '../../../../utils/theme.dart';
import '../../../../services/api.service.dart';
import '../../../../widgets/report_button.dart';
import 'comments_section.dart';
import 'reaction_menu.dart';
import '../models/post_type_config.dart';
import '../utils/helpers.dart';
import 'compose_page.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike; // conservé pour compatibilité (plus utilisé)
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final bool isMine;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onDelete,
    this.onEdit,
    required this.isMine,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _expanded = false;
  bool _showComments = false;
  bool _loadingComments = false;
  bool _commentsLoaded = false;
  List<Map<String, dynamic>> _comments = [];

  // États pour les réactions
  late bool _isLiked; // = _myReactionType == 'heart'
  late int _totalReactions;
  late List<Map<String, dynamic>> _reactions;
  String? _myReactionType;

  bool _isEditing = false;

  String get _postId =>
      (widget.post['_id'] ?? widget.post['id'] ?? '').toString();
  String get _content => widget.post['content'] as String? ?? '';

  void _updateReactionsFromPost() {
    final reactions = widget.post['reactions'] as List? ?? [];
    _reactions = reactions.map((r) => Map<String, dynamic>.from(r)).toList();
    _totalReactions =
        _reactions.fold<int>(0, (sum, r) => sum + (r['count'] as int? ?? 0));
    final myReaction = _reactions.firstWhere(
      (r) => r['isMine'] == true,
      orElse: () => {},
    );
    _myReactionType =
        myReaction.isNotEmpty ? myReaction['type'] as String? : null;
    _isLiked = _myReactionType == 'heart';
  }

  List<Map<String, dynamic>> _getTopReactions() {
    final Map<String, int> counts = {};
    for (final r in _reactions) {
      final type = r['type'] as String;
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTypes = sorted.take(3).map((e) => e.key).toList();

    const emojiMap = {
      'heart': '❤️',
      'hug': '🤗',
      'strong': '💪',
      'fire': '🔥',
    };

    return topTypes.map((type) {
      return {
        'type': type,
        'emoji': emojiMap[type] ?? '👍',
        'count': counts[type]!
      };
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _updateReactionsFromPost();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(PostCard old) {
    super.didUpdateWidget(old);
    _updateReactionsFromPost();
  }

  void _handlePostLike() {
    _handleReaction('heart');
  }

  Future<void> _handleReaction(String type) async {
    final previousTotal = _totalReactions;
    final previousReaction = _myReactionType;

    setState(() {
      if (_myReactionType == type) {
        _myReactionType = null;
        _totalReactions = (_totalReactions - 1).clamp(0, 999999);
      } else {
        if (_myReactionType == null) _totalReactions++;
        _myReactionType = type;
      }
      _isLiked = _myReactionType == 'heart';
    });

    try {
      final response = await ApiService().toggleReaction(_postId, type);
      if (mounted) {
        final reactions =
            List<Map<String, dynamic>>.from(response['reactions'] ?? []);
        final newTotal =
            reactions.fold<int>(0, (sum, r) => sum + (r['count'] as int));
        final myReaction = reactions.firstWhere(
          (r) => r['isMine'] == true,
          orElse: () => <String, dynamic>{},
        );
        setState(() {
          _reactions = reactions;
          _totalReactions = newTotal;
          _myReactionType =
              myReaction.isNotEmpty ? myReaction['type'] as String? : null;
          _isLiked = _myReactionType == 'heart';
        });
      }
    } catch (e) {
      setState(() {
        _totalReactions = previousTotal;
        _myReactionType = previousReaction;
        _isLiked = previousReaction == 'heart';
      });
      debugPrint('Erreur réaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erreur, réessaie plus tard'),
              backgroundColor: AppColors.accent),
        );
      }
    }
  }

  Future<void> _handleOverlayReaction(String? type) async {
    if (type == null) {
      if (_myReactionType != null) await _handleReaction(_myReactionType!);
    } else {
      await _handleReaction(type);
    }
  }

  // ==========================================================================
  // Commentaires
  // ==========================================================================
  Future<void> _loadComments() async {
    if (_commentsLoaded || _loadingComments) return;
    setState(() => _loadingComments = true);
    try {
      final data = await ApiService().get('/community/posts/$_postId/comments');
      if (mounted) {
        setState(() {
          _comments = (data['comments'] as List? ?? [])
              .map((c) => deepCastComment(c))
              .toList();
          _loadingComments = false;
          _commentsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  void _toggleComments() {
    if (!_showComments) _loadComments();
    setState(() => _showComments = !_showComments);
  }

  // ==========================================================================
  // Édition / Suppression
  // ==========================================================================
  Future<void> _openEditComposePage() async {
    if (_isEditing) return;
    setState(() => _isEditing = true);

    final postType = widget.post['postType'] as String? ?? 'feeling';

    // On pousse la page d'édition et on attend le résultat (booléen)
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ComposePage(
          isEditing: true,
          initialContent: _content,
          initialType: postType,
          onSubmit: (content, type, moodEmoji) async {
            // Ici on ne fait QUE l'appel API et la mise à jour locale
            // PAS de Navigator.pop ! C'est ComposePage qui fermera la page avec un résultat.
            await ApiService().editPost(_postId, content);
            // Mise à jour locale des données du post
            widget.post['content'] = content;
            widget.post['editedAt'] = DateTime.now().toIso8601String();
          },
        ),
      ),
    );

    if (mounted) {
      setState(() => _isEditing = false);
      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post modifié avec succès'),
            backgroundColor: AppColors.secondary,
          ),
        );
        // Notifier le parent si besoin
        widget.onEdit?.call();
      } else if (success == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la modification'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    }
  }

  bool get _canEdit {
    final createdAt = widget.post['createdAt'];
    if (createdAt == null) return false;
    final created = DateTime.tryParse(createdAt.toString());
    if (created == null) return false;
    final age = DateTime.now().difference(created);
    return age.inHours < 24;
  }

  Future<void> _handleDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce post ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDelete();
  }

  // ==========================================================================
  // Callbacks commentaires (gestion arborescente)
  // ==========================================================================
  void _onCommentPosted(Map<String, dynamic> comment, String? parentId) {
    setState(() {
      if (parentId != null) {
        final idx = _findComment(_comments, parentId);
        if (idx != null) {
          final parent = Map<String, dynamic>.from(idx);
          final replies = (parent['replies'] as List? ?? [])
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          replies.add({...comment, 'replies': []});
          parent['replies'] = replies;
          parent['repliesCount'] = (parent['repliesCount'] ?? 0) + 1;
          _replaceComment(_comments, parentId, parent);
        }
      } else {
        _comments.add({...comment, 'replies': []});
        widget.post['commentsCount'] =
            ((widget.post['commentsCount'] ?? 0) as int) + 1;
      }
    });
  }

  void _onCommentLiked(String commentId, bool liked, int count) =>
      setState(() => _updateCommentLike(_comments, commentId, liked, count));

  Map<String, dynamic>? _findComment(List list, String id) {
    for (final c in list) {
      if ((c['_id'] ?? '').toString() == id) return c;
      final found = _findComment(
        (c['replies'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList(),
        id,
      );
      if (found != null) return found;
    }
    return null;
  }

  bool _replaceComment(List list, String id, Map<String, dynamic> replacement) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i]['_id'] ?? '').toString() == id) {
        list[i] = replacement;
        return true;
      }
      final replies = list[i]['replies'];
      if (replies is List && replies.isNotEmpty) {
        if (_replaceComment(replies, id, replacement)) {
          list[i] = {...list[i], 'replies': List.from(replies)};
          return true;
        }
      }
    }
    return false;
  }

  void _updateCommentLike(List list, String id, bool liked, int count) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i]['_id'] ?? '').toString() == id) {
        list[i] = {...list[i], 'isLiked': liked, 'likesCount': count};
        return;
      }
      final replies = list[i]['replies'];
      if (replies is List && replies.isNotEmpty) {
        final before = list[i].toString();
        _updateCommentLike(replies, id, liked, count);
        if (list[i].toString() == before) {
          list[i] = {...list[i], 'replies': List.from(replies)};
        }
      }
    }
  }

  // ==========================================================================
  // Build
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final postType = post['postType'] as String? ?? 'feeling';
    final typeConf = postTypeConfig[postType] ?? postTypeConfig['feeling']!;
    final commentsCount = (post['commentsCount'] ?? 0) as int;
    final moodEmoji = post['moodEmoji'] as String?;
    final content = post['content'] as String? ?? '';
    final editedAt = post['editedAt'] as String?;
    final isLong = content.length > 300;
    final displayContent =
        isLong && !_expanded ? '${content.substring(0, 300)}…' : content;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: widget.isMine
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.25), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête (auteur, type, menu)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: typeConf.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: Center(
                  child: Text(typeConf.emoji,
                      style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          anonName(_postId,
                              alias: (widget.post['anonymousAlias'] ??
                                  (widget.post['author']
                                      as Map?)?['anonymousAlias']) as String?),
                          style: AppTextStyles.bodySmall
                              .copyWith(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: typeConf.color.withValues(alpha: 0.12),
                            borderRadius: AppRadius.full),
                        child: Text(typeConf.label,
                            style: AppTextStyles.caption.copyWith(
                                color: typeConf.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 10)),
                      ),
                    ]),
                    Row(children: [
                      Text(fmtDate(post['createdAt']),
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.onSurfaceMuted, fontSize: 11)),
                      if (editedAt != null) ...[
                        const SizedBox(width: 6),
                        Text('(modifié)',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.onSurfaceMuted,
                                fontSize: 10,
                                fontStyle: FontStyle.italic)),
                      ],
                    ]),
                  ]),
            ),
            if (widget.isMine)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 20, color: AppColors.onSurfaceMuted),
                onSelected: (value) async {
                  if (value == 'edit' && _canEdit) {
                    await _openEditComposePage();
                  } else if (value == 'edit' && !_canEdit) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'La modification n\'est possible que dans les 24h'),
                          backgroundColor: AppColors.accent),
                    );
                  } else if (value == 'delete') {
                    _handleDelete(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    enabled: _canEdit,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 18,
                            color: _canEdit
                                ? AppColors.primary
                                : AppColors.onSurfaceMuted),
                        const SizedBox(width: 8),
                        Text('Modifier',
                            style: TextStyle(
                                color: _canEdit
                                    ? AppColors.onSurface
                                    : AppColors.onSurfaceMuted)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: AppColors.accent),
                        SizedBox(width: 8),
                        Text('Supprimer'),
                      ],
                    ),
                  ),
                ],
              ),
          ]),
        ),
        if (moodEmoji != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: AppRadius.full),
              child: Text('$moodEmoji Je ressens ça',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(displayContent,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.onSurface, height: 1.6)),
            if (isLong)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_expanded ? 'Voir moins ▲' : 'Lire la suite ▼',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        ),
        const Divider(color: AppColors.divider, height: 1),
        // Boutons d'action : LikeButton gère l'affichage des réactions et du compteur
        Row(children: [
          Expanded(
            child: LikeButton(
              isLiked: _isLiked,
              myReactionType: _myReactionType,
              reactions: _reactions,
              totalCount: _totalReactions,
              onTap: _handlePostLike,
              onReactionSelected: _handleOverlayReaction,
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.divider),
          Expanded(
            child: GestureDetector(
              onTap: _toggleComments,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 20,
                        color: _showComments
                            ? AppColors.primary
                            : AppColors.onSurfaceMuted),
                    const SizedBox(width: 4),
                    if (commentsCount > 0)
                      Text(
                        '$commentsCount',
                        style: AppTextStyles.caption.copyWith(
                          color: _showComments
                              ? AppColors.primary
                              : AppColors.onSurfaceMuted,
                          fontWeight:
                              _showComments ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.divider),
          if (!widget.isMine)
            ReportButton(targetType: 'post', targetId: _postId, isSmall: true),
        ]),
        if (_showComments)
          CommentsSection(
            postId: _postId,
            comments: _comments,
            isLoading: _loadingComments,
            onCommentPosted: _onCommentPosted,
            onCommentLiked: _onCommentLiked,
            onHide: () => setState(() => _showComments = false),
          ),
      ]),
    );
  }
}