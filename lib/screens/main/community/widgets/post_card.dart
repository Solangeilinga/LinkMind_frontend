import 'package:flutter/material.dart';
import '../../../../utils/theme.dart';
import '../../../../services/api.service.dart';
import '../../../../widgets/report_button.dart';
import 'comments_section.dart';
import 'reaction_menu.dart';
import '../models/post_type_config.dart';
import '../utils/helpers.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;  // ✅ AJOUTÉ
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
  late bool _isLiked;
  late int _likesCount;
  late bool _isSameFeeling;
  late int _sameFeelingsCount;
  bool _isEditing = false;
  final _editController = TextEditingController();

  String get _postId => (widget.post['_id'] ?? widget.post['id'] ?? '').toString();
  String get _content => widget.post['content'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post['isLiked'] == true;
    _likesCount = (widget.post['likesCount'] ?? 0) as int;
    _isSameFeeling = widget.post['isSameFeeling'] == true;
    _sameFeelingsCount = (widget.post['sameFeelingsCount'] ?? 0) as int;
    _editController.text = _content;
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PostCard old) {
    super.didUpdateWidget(old);
    _isLiked = widget.post['isLiked'] == true;
    _likesCount = (widget.post['likesCount'] ?? 0) as int;
    _isSameFeeling = widget.post['isSameFeeling'] == true;
    _sameFeelingsCount = (widget.post['sameFeelingsCount'] ?? 0) as int;
    if (_content != old.post['content']) {
      _editController.text = _content;
    }
  }

  void _handlePostLike() {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount = (_likesCount - 1).clamp(0, 999999);
      } else {
        _isLiked = true;
        _likesCount += 1;
      }
    });
    widget.onLike();
  }

  // ✅ AJOUTÉ: Gestion des réactions multiples
  Future<void> _handleReaction(String type) async {
    final postId = _postId;
    try {
      final response = await ApiService().toggleReaction(postId, type);
      if (mounted) {
        // Mettre à jour l'affichage des réactions
        setState(() {
          final reactions = response['reactions'] as List? ?? [];
          // Mettre à jour l'état local si nécessaire
        });
      }
    } catch (e) {
      debugPrint('Erreur réaction: $e');
    }
  }

  Future<void> _loadComments() async {
    if (_commentsLoaded || _loadingComments) return;
    setState(() => _loadingComments = true);
    try {
      final data = await ApiService().get('/community/posts/$_postId/comments');
      if (mounted) {
        setState(() {
          _comments = (data['comments'] as List? ?? []).map((c) => deepCastComment(c)).toList();
          _loadingComments = false;
          _commentsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  void _showReactionMenu() {
    showReactionMenu(
      context,
      _postId,
      _handlePostLike,
      _handleSameFeeling,
      _handleReaction,
    );
  }

  Future<void> _handleSameFeeling() async {
    final postId = _postId;
    setState(() {
      if (_isSameFeeling) {
        _isSameFeeling = false;
        _sameFeelingsCount = (_sameFeelingsCount - 1).clamp(0, 999999);
      } else {
        _isSameFeeling = true;
        _sameFeelingsCount += 1;
      }
    });
    try {
      final r = await ApiService().toggleSameFeeling(postId);
      setState(() {
        _isSameFeeling = r['sameFeeling'] as bool;
        _sameFeelingsCount = r['sameFeelingsCount'] as int;
      });
    } catch (_) {
      setState(() {
        if (_isSameFeeling) {
          _isSameFeeling = false;
          _sameFeelingsCount = (_sameFeelingsCount - 1).clamp(0, 999999);
        } else {
          _isSameFeeling = true;
          _sameFeelingsCount += 1;
        }
      });
    }
  }

  // ✅ AJOUTÉ: Édition du post
  Future<void> _handleEdit() async {
    final newContent = _editController.text.trim();
    if (newContent.isEmpty || newContent == _content) {
      setState(() => _isEditing = false);
      return;
    }

    try {
      await ApiService().editPost(_postId, newContent);
      widget.post['content'] = newContent;
      widget.post['editedAt'] = DateTime.now().toIso8601String();
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post modifié avec succès'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    }
  }

  // ✅ AJOUTÉ: Vérifier si le post peut être édité (moins de 24h)
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (ok == true) {
      widget.onDelete();
    }
  }

  void _toggleComments() {
    if (!_showComments) _loadComments();
    setState(() => _showComments = !_showComments);
  }

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
        widget.post['commentsCount'] = ((widget.post['commentsCount'] ?? 0) as int) + 1;
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
      if (_replaceComment(
        (list[i]['replies'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList(),
        id,
        replacement,
      )) {
        list[i] = {...list[i], 'replies': list[i]['replies']};
        return true;
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
        _updateCommentLike(replies, id, liked, count);
      }
    }
  }

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
    final displayContent = isLong && !_expanded ? '${content.substring(0, 300)}…' : content;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: widget.isMine
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: typeConf.color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Center(child: Text(typeConf.emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      anonName(
                        _postId,
                        alias: (widget.post['anonymousAlias'] ??
                            (widget.post['author'] as Map?)?['anonymousAlias']) as String?,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: typeConf.color.withValues(alpha: 0.12), borderRadius: AppRadius.full),
                    child: Text(
                      typeConf.label,
                      style: AppTextStyles.caption.copyWith(
                          color: typeConf.color, fontWeight: FontWeight.w700, fontSize: 10),
                    ),
                  ),
                ]),
                Row(children: [
                  Text(
                    fmtDate(post['createdAt']),
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.onSurfaceMuted, fontSize: 11),
                  ),
                  if (editedAt != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(modifié)',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.onSurfaceMuted, fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ],
                ]),
              ]),
            ),
            // ✅ AJOUTÉ: Menu pour mes posts (édition/suppression)
            if (widget.isMine)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: AppColors.onSurfaceMuted),
                onSelected: (value) async {
                  if (value == 'edit' && _canEdit) {
                    setState(() => _isEditing = true);
                  } else if (value == 'edit' && !_canEdit) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('La modification n\'est possible que dans les 24h'),
                        backgroundColor: AppColors.accent,
                      ),
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
                        Icon(Icons.edit_outlined, size: 18, color: _canEdit ? AppColors.primary : AppColors.onSurfaceMuted),
                        const SizedBox(width: 8),
                        Text('Modifier', style: TextStyle(color: _canEdit ? AppColors.onSurface : AppColors.onSurfaceMuted)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.accent),
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
                borderRadius: AppRadius.full,
              ),
              child: Text(
                '$moodEmoji Je ressens ça',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_isEditing)
              Column(
                children: [
                  TextField(
                    controller: _editController,
                    maxLines: 10,
                    maxLength: 1500,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Modifie ton post...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _isEditing = false),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _handleEdit,
                        child: const Text('Enregistrer'),
                      ),
                    ],
                  ),
                ],
              )
            else ...[
              Text(
                displayContent,
                style: AppTextStyles.body.copyWith(color: AppColors.onSurface, height: 1.6),
              ),
              if (isLong)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _expanded ? 'Voir moins ▲' : 'Lire la suite ▼',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ]),
        ),
        if (_isLiked || _likesCount > 0 || commentsCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(children: [
              if (_likesCount > 0) ...[
                const Text('❤️', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '$_likesCount',
                  style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                ),
              ],
              const Spacer(),
              if (commentsCount > 0)
                GestureDetector(
                  onTap: _toggleComments,
                  child: Text(
                    '$commentsCount commentaire${commentsCount > 1 ? "s" : ""}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.onSurfaceMuted,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.onSurfaceMuted),
                  ),
                ),
            ]),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Divider(color: AppColors.divider, height: 1),
        ),
        // Actions
        Row(children: [
          // J'aime
          Expanded(
            child: GestureDetector(
              onTap: _handlePostLike,
              onLongPress: _showReactionMenu,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey(_isLiked),
                        size: 20,
                        color: _isLiked ? AppColors.accent : AppColors.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (_likesCount > 0)
                      Text(
                        '$_likesCount',
                        style: AppTextStyles.caption.copyWith(
                          color: _isLiked ? AppColors.accent : AppColors.onSurfaceMuted,
                          fontWeight: _isLiked ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.divider),
          // Moi aussi
          Expanded(
            child: GestureDetector(
              onTap: _handleSameFeeling,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🤝', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    if (_sameFeelingsCount > 0)
                      Text(
                        '$_sameFeelingsCount',
                        style: AppTextStyles.caption.copyWith(
                          color: _isSameFeeling ? AppColors.secondary : AppColors.onSurfaceMuted,
                          fontWeight: _isSameFeeling ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.divider),
          // Commenter
          Expanded(
            child: GestureDetector(
              onTap: _toggleComments,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 20,
                      color: _showComments ? AppColors.primary : AppColors.onSurfaceMuted,
                    ),
                    const SizedBox(width: 4),
                    if (commentsCount > 0)
                      Text(
                        '$commentsCount',
                        style: AppTextStyles.caption.copyWith(
                          color: _showComments ? AppColors.primary : AppColors.onSurfaceMuted,
                          fontWeight: _showComments ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.divider),
          // Signalement (uniquement si ce n'est pas mon post)
          if (!widget.isMine)
            ReportButton(
              targetType: 'post',
              targetId: _postId,
              isSmall: true,
            ),
          // ✅ SUPPRIMÉ: Bouton delete dans le menu maintenant
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