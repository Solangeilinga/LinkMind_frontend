import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/theme.dart';
import '../../services/api.service.dart';

// ─── Post type config ─────────────────────────────────────────────────────────
const _postTypeConfig = {
  'feeling':       (emoji: '💬', label: 'Je ressens',  color: AppColors.primary),
  'question':      (emoji: '❓', label: 'Question',    color: AppColors.accentOrange),
  'support':       (emoji: '🤝', label: 'Soutien',     color: AppColors.secondary),
  'success':       (emoji: '🎉', label: 'Réussite',    color: AppColors.accent),
  'tip':           (emoji: '💡', label: 'Conseil',     color: AppColors.accentRed),
  // Legacy types from old data
  'general':       (emoji: '💬', label: 'Partage',     color: AppColors.primary),
  'mood_share':    (emoji: '😊', label: 'Humeur',      color: AppColors.accentOrange),
  'achievement':   (emoji: '🏆', label: 'Réussite',    color: AppColors.accent),
  'challenge_completed': (emoji: '✅', label: 'Défi',  color: AppColors.secondary),
};

// Returns alias if set, otherwise generic anonymous label
String _anonName(String id, {String? alias}) {
  if (alias != null && alias.trim().isNotEmpty) return alias.trim();
  return '👤 Anonyme';
}

String _fmtDate(dynamic d) {
  if (d == null) return '';
  final dt = DateTime.tryParse(d.toString());
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}j';
  return '${(diff.inDays / 7).floor()}sem';
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _allPosts = [];
  List<Map<String, dynamic>> _myPosts  = [];
  bool _isLoadingAll  = true;
  bool _isLoadingMine = true;
  bool _isPosting     = false;
  String? _activeFilter;
  late final TabController _tabController;
  final _postCtrl = TextEditingController();
  String _selectedPostType = 'feeling';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() { if (!_tabController.indexIsChanging && mounted) setState(() {}); });
    _loadFeed();
    _loadMyPosts();
  }

  @override
  void dispose() { _postCtrl.dispose(); _tabController.dispose(); super.dispose(); }

  Future<void> _loadFeed() async {
    setState(() => _isLoadingAll = true);
    try {
      final data = await ApiService().getFeed();
      debugPrint('getFeed response: ${data['posts']?.length ?? 0} posts');
      if (mounted) setState(() {
        _allPosts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
        _isLoadingAll = false;
      });
    } catch (e) {
      debugPrint('loadFeed error: $e');
      if (mounted) setState(() => _isLoadingAll = false);
    }
  }

  Future<void> _loadMyPosts() async {
    setState(() => _isLoadingMine = true);
    try {
      final data = await ApiService().getMyPosts();
      if (mounted) setState(() {
        _myPosts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
        _isLoadingMine = false;
      });
    } catch (e) {
      debugPrint('loadMyPosts: $e');
      if (mounted) setState(() => _isLoadingMine = false);
    }
  }

  Future<void> _submitPost() async {
    final content = _postCtrl.text.trim();
    if (content.isEmpty) return;
    setState(() => _isPosting = true);
    try {
      await ApiService().createPost(content: content, postType: _selectedPostType, isAnonymous: true);
      _postCtrl.clear();
      if (mounted) {
        setState(() { _isPosting = false; _selectedPostType = 'feeling'; });
        Navigator.pop(context);
        _loadFeed();
        _loadMyPosts();
      }
    } catch (_) { if (mounted) setState(() => _isPosting = false); }
  }

  void _optimisticLike(String postId, List<Map<String, dynamic>> list) {
    final idx = list.indexWhere((p) => (p['_id'] ?? p['id'])?.toString() == postId);
    if (idx == -1) return;
    final liked = list[idx]['isLiked'] == true;
    list[idx] = {
      ...list[idx],
      'isLiked': !liked,
      'likesCount': ((list[idx]['likesCount'] ?? 0) as int) + (liked ? -1 : 1),
    };
  }

  Future<void> _togglePostLike(String postId) async {
    setState(() { _optimisticLike(postId, _allPosts); _optimisticLike(postId, _myPosts); });
    try {
      final r = await ApiService().toggleLike(postId);
      setState(() {
        for (final list in [_allPosts, _myPosts]) {
          final idx = list.indexWhere((p) => (p['_id'] ?? p['id'])?.toString() == postId);
          if (idx != -1) list[idx] = {...list[idx], 'isLiked': r['liked'], 'likesCount': r['likesCount']};
        }
      });
    } catch (_) {
      setState(() { _optimisticLike(postId, _allPosts); _optimisticLike(postId, _myPosts); });
    }
  }

  void _showComposeSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _ComposeSheet(
        ctrl: _postCtrl, selectedType: _selectedPostType, isPosting: _isPosting,
        onTypeChanged: (t) => setState(() => _selectedPostType = t),
        onSubmit: _submitPost,
      ),
    );
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> posts) =>
      _activeFilter == null ? posts : posts.where((p) => p['postType'] == _activeFilter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Column(children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Communauté 🌍', style: AppTextStyles.h2),
                Text('Espace sécurisé · Tout est anonyme',
                    style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
              ]),
              ElevatedButton.icon(
                onPressed: _showComposeSheet,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Partager'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14)),
              ),
            ]),
            const SizedBox(height: 14),
            // Tabs
            Container(
              height: 38,
              decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.full),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.full),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.onSurfaceMuted,
                labelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w800),
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(text: 'Communauté'),
                  Tab(text: 'Mes posts${_myPosts.isNotEmpty ? " (${_myPosts.length})" : ""}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterChip(label: 'Tous', emoji: '🌐', isSelected: _activeFilter == null,
                    color: AppColors.primary, onTap: () => setState(() => _activeFilter = null)),
                const SizedBox(width: 8),
                ..._postTypeConfig.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: e.value.label, emoji: e.value.emoji,
                    isSelected: _activeFilter == e.key, color: e.value.color,
                    onTap: () => setState(() => _activeFilter = _activeFilter == e.key ? null : e.key)),
                )),
              ]),
            ),
            const SizedBox(height: 4),
          ]),
        ),
        // Feed
        Expanded(child: TabBarView(
          controller: _tabController,
          children: [
            _FeedList(
              posts: _filtered(_allPosts), isLoading: _isLoadingAll,
              onRefresh: _loadFeed, onLike: _togglePostLike,
              onCompose: _showComposeSheet,
              emptyMessage: _activeFilter != null ? 'Aucun partage de ce type' : 'La communauté t\'attend',
            ),
            _FeedList(
              posts: _filtered(_myPosts), isLoading: _isLoadingMine,
              onRefresh: _loadMyPosts, onLike: _togglePostLike,
              onCompose: _showComposeSheet, emptyMessage: 'Tu n\'as encore rien partagé',
            ),
          ],
        )),
      ])),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label, emoji;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.emoji,
      required this.isSelected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surfaceVariant,
        borderRadius: AppRadius.full,
        border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5)),
      child: Text('$emoji $label', style: AppTextStyles.caption.copyWith(
        color: isSelected ? color : AppColors.onSurfaceMuted,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600)),
    ),
  );
}

// ─── Feed List ────────────────────────────────────────────────────────────────
class _FeedList extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Function(String) onLike;
  final VoidCallback onCompose;
  final String emptyMessage;

  const _FeedList({required this.posts, required this.isLoading,
      required this.onRefresh, required this.onLike,
      required this.onCompose, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (posts.isEmpty) return _EmptyFeed(onCompose: onCompose, message: emptyMessage);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: posts.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PostCard(
            post: posts[i],
            onLike: () => onLike((posts[i]['_id'] ?? posts[i]['id'] ?? '').toString()),
            isMine: posts[i]['isMine'] == true,
          ),
        ),
      ),
    );
  }
}


// Helper: deep cast a comment map and its replies from API response
Map<String, dynamic> _deepCastComment(dynamic raw) {
  final m = Map<String, dynamic>.from(raw as Map);
  m['replies'] = (m['replies'] as List? ?? [])
      .map((r) => _deepCastComment(r))
      .toList();
  return m;
}

// ─── Post Card ────────────────────────────────────────────────────────────────
class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final bool isMine;
  const _PostCard({required this.post, required this.onLike, required this.isMine});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _expanded = false;
  bool _showComments = false;
  bool _loadingComments = false;
  bool _commentsLoaded = false;
  List<Map<String, dynamic>> _comments = [];

  // Local like state for instant feedback
  late bool _isLiked;
  late int _likesCount;

  String get _postId => (widget.post['_id'] ?? widget.post['id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _isLiked    = widget.post['isLiked'] == true;
    _likesCount = (widget.post['likesCount'] ?? 0) as int;
  }

  @override
  void didUpdateWidget(_PostCard old) {
    super.didUpdateWidget(old);
    _isLiked    = widget.post['isLiked'] == true;
    _likesCount = (widget.post['likesCount'] ?? 0) as int;
  }

  void _handlePostLike() {
    setState(() {
      if (_isLiked) { _isLiked = false; _likesCount = (_likesCount - 1).clamp(0, 999999); }
      else           { _isLiked = true;  _likesCount += 1; }
    });
    widget.onLike(); // fire API in background
  }

  Future<void> _loadComments() async {
    if (_commentsLoaded || _loadingComments) return;
    setState(() => _loadingComments = true);
    try {
      final data = await ApiService().get('/community/posts/$_postId/comments');
      if (mounted) setState(() {
        _comments = (data['comments'] as List? ?? [])
            .map((c) => _deepCastComment(c))
            .toList();
        _loadingComments = false;
        _commentsLoaded = true;
      });
    } catch (_) { if (mounted) setState(() => _loadingComments = false); }
  }

  void _toggleComments() {
    if (!_showComments) _loadComments();
    setState(() => _showComments = !_showComments);
  }

  void _onCommentPosted(Map<String, dynamic> comment, String? parentId) {
    setState(() {
      if (parentId != null) {
        // Add as reply to parent
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

  void _onCommentLiked(String commentId, bool liked, int count) {
    setState(() => _updateCommentLike(_comments, commentId, liked, count));
  }

  // Tree helpers
  Map<String, dynamic>? _findComment(List list, String id) {
    for (final c in list) {
      if ((c['_id'] ?? '').toString() == id) return c;
      final found = _findComment((c['replies'] as List? ?? []).map((r) => Map<String, dynamic>.from(r as Map)).toList(), id);
      if (found != null) return found;
    }
    return null;
  }

  bool _replaceComment(List list, String id, Map<String, dynamic> replacement) {
    for (int i = 0; i < list.length; i++) {
      if ((list[i]['_id'] ?? '').toString() == id) { list[i] = replacement; return true; }
      if (_replaceComment((list[i]['replies'] as List? ?? []).map((r) => Map<String, dynamic>.from(r as Map)).toList(), id, replacement)) {
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
      // Recurse into replies — must update in-place on the same list reference
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
    final typeConf = _postTypeConfig[postType] ?? _postTypeConfig['feeling']!;
    final isLiked = _isLiked;
    final likesCount = _likesCount;
    final commentsCount = (post['commentsCount'] ?? 0) as int;
    final content = post['content'] as String? ?? '';
    final isLong = content.length > 300;
    final displayContent = isLong && !_expanded ? '${content.substring(0, 300)}…' : content;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: widget.isMine
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5)
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: typeConf.color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Center(child: Text(typeConf.emoji,
                  style: const TextStyle(fontSize: 20)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(
                  _anonName(_postId, alias: (widget.post['anonymousAlias']
                      ?? (widget.post['author'] as Map?)?['anonymousAlias']) as String?),
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: typeConf.color.withValues(alpha: 0.12),
                      borderRadius: AppRadius.full),
                  child: Text(typeConf.label, style: AppTextStyles.caption.copyWith(
                      color: typeConf.color, fontWeight: FontWeight.w700, fontSize: 10))),
              ]),
              Text(_fmtDate(post['createdAt']), style: AppTextStyles.caption.copyWith(
                  color: AppColors.onSurfaceMuted, fontSize: 11)),
            ])),
          ]),
        ),

        // ── Content ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(displayContent, style: AppTextStyles.body.copyWith(
                color: AppColors.onSurface, height: 1.6)),
            if (isLong) GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_expanded ? 'Voir moins ▲' : 'Lire la suite ▼',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w800)),
              )),
          ]),
        ),

        // ── Reaction counts ──
        if (likesCount > 0 || commentsCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(children: [
              if (likesCount > 0) ...[
                const Text('❤️', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text('$likesCount', style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceMuted)),
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
                        decorationColor: AppColors.onSurfaceMuted)),
                ),
            ]),
          ),

        // ── Divider ──
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Divider(color: AppColors.divider, height: 1)),

        // ── Action buttons ──
        Row(children: [
          Expanded(child: TextButton.icon(
            onPressed: _handlePostLike,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(isLiked),
                size: 18,
                color: isLiked ? AppColors.accent : AppColors.onSurfaceMuted)),
            label: Text("J'aime", style: AppTextStyles.bodySmall.copyWith(
                color: isLiked ? AppColors.accent : AppColors.onSurfaceMuted,
                fontWeight: isLiked ? FontWeight.w800 : FontWeight.w600)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
          )),
          Container(width: 1, height: 20, color: AppColors.divider),
          Expanded(child: TextButton.icon(
            onPressed: _toggleComments,
            icon: Icon(Icons.chat_bubble_outline, size: 18,
                color: _showComments ? AppColors.primary : AppColors.onSurfaceMuted),
            label: Text('Commenter', style: AppTextStyles.bodySmall.copyWith(
                color: _showComments ? AppColors.primary : AppColors.onSurfaceMuted,
                fontWeight: _showComments ? FontWeight.w800 : FontWeight.w600)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
          )),
        ]),

        // ── Comments section ──
        if (_showComments)
          _CommentsSection(
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

// ─── Comments Section ─────────────────────────────────────────────────────────
class _CommentsSection extends StatefulWidget {
  final String postId;
  final List<Map<String, dynamic>> comments;
  final bool isLoading;
  final Function(Map<String, dynamic>, String?) onCommentPosted;
  final Function(String, bool, int) onCommentLiked;
  final VoidCallback onHide;

  const _CommentsSection({
    required this.postId, required this.comments, required this.isLoading,
    required this.onCommentPosted, required this.onCommentLiked, required this.onHide,
  });

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;
  bool _isPrivate = false;
  String? _replyToId;    // commentId being replied to
  String? _replyToLabel; // display label

  @override
  void dispose() { _ctrl.dispose(); _focusNode.dispose(); super.dispose(); }

  void _startReply(String commentId, String label) {
    setState(() { _replyToId = commentId; _replyToLabel = label; });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _cancelReply() => setState(() { _replyToId = null; _replyToLabel = null; _ctrl.clear(); });

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
      if (mounted) setState(() { _sending = false; _replyToId = null; _replyToLabel = null; });
    } catch (_) { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _likeComment(String commentId) async {
    // Optimistic update handled inside _CommentItem itself
    // Just sync with server response
    try {
      final r = await ApiService().post(
          '/community/posts/${widget.postId}/comments/$commentId/like', {});
      widget.onCommentLiked(commentId, r['liked'] as bool, r['likesCount'] as int);
    } catch (_) {
      // On error, revert by calling onCommentLiked with inverted state
      // _CommentItem handles its own optimistic state, so no action needed here
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Comments header with hide button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(children: [
            Text('Commentaires',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceMuted, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: widget.onHide,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Masquer', style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceMuted)),
                const SizedBox(width: 2),
                const Icon(Icons.expand_less, size: 16, color: AppColors.onSurfaceMuted),
              ]),
            ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: Divider(color: AppColors.divider, height: 1)),

        // ── Comment list ──
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
            child: Column(
              children: widget.comments.map((c) => _CommentItem(
                comment: c,
                depth: 0,
                onReply: _startReply,
                onLike: _likeComment,
              )).toList(),
            ),
          ),

        // ── Reply indicator ──
        if (_replyToId != null)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
            child: Row(children: [
              const Icon(Icons.reply, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text('Répondre à ${_replyToLabel ?? "un commentaire"}',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700))),
              GestureDetector(onTap: _cancelReply,
                  child: const Icon(Icons.close, size: 14, color: AppColors.onSurfaceMuted)),
            ]),
          ),

        // ── Visibility toggle ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(children: [
            _VisChip(label: '🌐 Public', selected: !_isPrivate, color: AppColors.secondary,
                onTap: () => setState(() => _isPrivate = false)),
            const SizedBox(width: 8),
            _VisChip(label: '🔒 Privé', selected: _isPrivate, color: AppColors.primary,
                onTap: () => setState(() => _isPrivate = true)),
          ]),
        ),

        // ── Input row ──
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
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? (_isPrivate ? AppColors.primary : AppColors.secondary).withValues(alpha: 0.5)
                        : AppColors.divider)),
                child: TextField(
                  controller: _ctrl, focusNode: _focusNode,
                  maxLines: 4, minLines: 1,
                  style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                  decoration: InputDecoration(
                    hintText: _replyToId != null
                        ? 'Réponds à ${_replyToLabel ?? "ce commentaire"}…'
                        : (_isPrivate ? 'Message privé à l\'auteur…' : 'Écris un commentaire…'),
                    hintStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurfaceMuted.withValues(alpha: 0.6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: InputBorder.none, isDense: true,
                  ),
                ),
              ),
            ),
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
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 16),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Comment Item (recursive — handles replies) ───────────────────────────────
class _CommentItem extends StatefulWidget {
  final Map<String, dynamic> comment;
  final int depth;
  final Function(String, String) onReply;
  final Function(String) onLike;

  const _CommentItem({
    required this.comment, required this.depth,
    required this.onReply, required this.onLike,
  });

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  late bool _isLiked;
  late int _likesCount;
  late List<Map<String, dynamic>> _replies; // cached + deep-cast once

  @override
  void initState() {
    super.initState();
    _isLiked    = widget.comment['isLiked'] == true;
    _likesCount = (widget.comment['likesCount'] ?? 0) as int;
    _replies    = _castReplies(widget.comment['replies']);
  }

  @override
  void didUpdateWidget(_CommentItem old) {
    super.didUpdateWidget(old);
    // Only sync likes if they actually changed from parent (server confirm)
    final newLiked = widget.comment['isLiked'] == true;
    final newCount = (widget.comment['likesCount'] ?? 0) as int;
    final oldLiked = old.comment['isLiked'] == true;
    final oldCount = (old.comment['likesCount'] ?? 0) as int;
    if (newLiked != oldLiked || newCount != oldCount) {
      _isLiked    = newLiked;
      _likesCount = newCount;
    }
    // Re-cast replies only if the replies list reference actually changed
    if (!identical(widget.comment['replies'], old.comment['replies'])) {
      _replies = _castReplies(widget.comment['replies']);
    }
  }

  static List<Map<String, dynamic>> _castReplies(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((r) => _deepCastComment(r)).toList();
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
    final commentId = (widget.comment['_id'] ?? '').toString();
    widget.onLike(commentId);
  }

  @override
  Widget build(BuildContext context) {
    final commentId   = (widget.comment['_id'] ?? '').toString();
    final content     = widget.comment['content'] as String? ?? '';
    final isPrivate   = widget.comment['isPrivate'] == true;
    final replies = _replies;
    final date        = _fmtDate(widget.comment['createdAt']);
    final alias       = (widget.comment['author'] as Map?)?['anonymousAlias'] as String?;
    final displayName = _anonName(commentId, alias: alias);
    final accentColor = isPrivate ? AppColors.primary : AppColors.secondary;
    final leftPad     = widget.depth * 20.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPad, bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar
          Container(
            width: widget.depth == 0 ? 32 : 26,
            height: widget.depth == 0 ? 32 : 26,
            decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(child: Text(isPrivate ? '🔒' : '🌿',
                style: TextStyle(fontSize: widget.depth == 0 ? 14.0 : 11.0)))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Bubble
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
                    : null,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(isPrivate ? '🔒 ${displayName}' : displayName,
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
              ]),
            ),
            // Actions: J'aime · Répondre · date
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 5),
              child: Row(children: [
                // Like button — instant feedback
                GestureDetector(
                  onTap: _handleLike,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      key: ValueKey(_isLiked),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: _isLiked ? AppColors.accent : AppColors.onSurfaceMuted),
                        if (_likesCount > 0) ...[
                          const SizedBox(width: 3),
                          Text('$_likesCount',
                              style: AppTextStyles.caption.copyWith(
                                color: _isLiked ? AppColors.accent : AppColors.onSurfaceMuted,
                                fontWeight: FontWeight.w700, fontSize: 11)),
                        ],
                        const SizedBox(width: 5),
                        Text("J'aime",
                            style: AppTextStyles.caption.copyWith(
                              color: _isLiked ? AppColors.accent : AppColors.onSurfaceMuted,
                              fontWeight: _isLiked ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Répondre
                if (widget.depth < 2)
                  GestureDetector(
                    onTap: () => widget.onReply(
                        commentId, isPrivate ? '🔒 Privé' : _anonName(commentId,
                            alias: widget.comment['author']?['anonymousAlias'] as String?)),
                    child: Text('Répondre',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                const SizedBox(width: 12),
                Text(date,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onSurfaceMuted.withValues(alpha: 0.5),
                      fontSize: 10)),
              ]),
            ),
          ])),
        ]),

        // ── Nested replies ──
        if (replies.isNotEmpty)
          Column(children: replies.map((r) => _CommentItem(
            comment: r, depth: widget.depth + 1,
            onReply: widget.onReply, onLike: widget.onLike,
          )).toList()),
      ]),
    );
  }
}

// ─── Visibility Chip ──────────────────────────────────────────────────────────
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

// ─── Compose Sheet ────────────────────────────────────────────────────────────
class _ComposeSheet extends StatefulWidget {
  final TextEditingController ctrl;
  final String selectedType;
  final bool isPosting;
  final Function(String) onTypeChanged;
  final VoidCallback onSubmit;

  const _ComposeSheet({required this.ctrl, required this.selectedType,
      required this.isPosting, required this.onTypeChanged, required this.onSubmit});

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  late String _type;
  int _charCount = 0;
  static const _maxChars = 1500;

  @override
  void initState() {
    super.initState();
    _type = widget.selectedType;
    _charCount = widget.ctrl.text.length;
    widget.ctrl.addListener(() { if (mounted) setState(() => _charCount = widget.ctrl.text.length); });
  }

  @override
  Widget build(BuildContext context) {
    final typeConf = _postTypeConfig[_type] ?? _postTypeConfig['feeling']!;
    final canSubmit = _charCount > 0 && _charCount <= _maxChars && !widget.isPosting;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: AppRadius.full))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Nouveau partage', style: AppTextStyles.h3)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.full,
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🔒', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Text('Anonyme', style: AppTextStyles.caption.copyWith(
                    color: AppColors.secondary, fontWeight: FontWeight.w800)),
              ])),
          ]),
          const SizedBox(height: 4),
          Text('Personne ne verra ton identité. Exprime-toi librement.',
              style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 16),
          Text('Type de partage', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _postTypeConfig.entries.map((e) {
              final sel = _type == e.key;
              return Padding(padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () { setState(() => _type = e.key); widget.onTypeChanged(e.key); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? e.value.color.withValues(alpha: 0.15) : AppColors.surfaceVariant,
                      borderRadius: AppRadius.full,
                      border: Border.all(color: sel ? e.value.color : Colors.transparent, width: 1.5)),
                    child: Text('${e.value.emoji} ${e.value.label}',
                        style: AppTextStyles.caption.copyWith(
                          color: sel ? e.value.color : AppColors.onSurfaceMuted,
                          fontWeight: sel ? FontWeight.w900 : FontWeight.w600)),
                  ),
                ));
            }).toList()),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: typeConf.color.withValues(alpha: 0.04),
              borderRadius: AppRadius.md,
              border: Border.all(color: typeConf.color.withValues(alpha: 0.3), width: 1.5)),
            child: TextField(
              controller: widget.ctrl, maxLines: 8, minLines: 4,
              maxLength: _maxChars, autofocus: true,
              style: AppTextStyles.body.copyWith(height: 1.6),
              decoration: InputDecoration(
                hintText: 'Partage ce que tu ressens…',
                hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.onSurfaceMuted.withValues(alpha: 0.6), height: 1.6),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                counterStyle: AppTextStyles.caption.copyWith(
                    color: _charCount > _maxChars * 0.9 ? AppColors.accent : AppColors.onSurfaceMuted)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSubmit ? widget.onSubmit : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: typeConf.color,
                  minimumSize: const Size.fromHeight(52),
                  disabledBackgroundColor: AppColors.divider),
              child: widget.isPosting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Partager · ${typeConf.emoji} ${typeConf.label}',
                      style: AppTextStyles.button.copyWith(color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Empty Feed ───────────────────────────────────────────────────────────────
class _EmptyFeed extends StatelessWidget {
  final VoidCallback onCompose;
  final String message;
  const _EmptyFeed({required this.onCompose, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🌱', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(message, style: AppTextStyles.h3, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Sois le premier à partager.\nTu aideras sûrement quelqu\'un.',
            style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted, height: 1.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onCompose,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Partager anonymement')),
      ]),
    ),
  );
}