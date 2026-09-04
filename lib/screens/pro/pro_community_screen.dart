import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../services/pro_api.service.dart';
import '../main/community/models/post_type_config.dart';
import '../main/community/widgets/filter_chip.dart' as custom;
import 'pro_compose_page.dart';

const _reactionEmojis = {
  'heart':  '❤️',
  'hug':    '🤗',
  'strong': '💪',
  'fire':   '🔥',
};

class ProCommunityScreen extends StatefulWidget {
  const ProCommunityScreen({super.key});

  @override
  State<ProCommunityScreen> createState() => _ProCommunityScreenState();
}

class _ProCommunityScreenState extends State<ProCommunityScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isLoading = true;
  String? _error;
  List<dynamic> _posts = [];
  List<dynamic> _myPosts = [];
  bool _myPostsLoaded = false;

  String? _activeFilter;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isSearching = false;
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_tabController.indexIsChanging) return;
        if (_tabController.index == 1 && !_myPostsLoaded) _loadMyPosts();
      });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!await ProApiService().isLoggedIn()) {
      if (mounted) context.go('/pro/login');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final posts = await ProApiService().getCommunityFeed(postType: _activeFilter);
      setState(() { _posts = posts; _isLoading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMyPosts() async {
    setState(() => _myPostsLoaded = true);
    try {
      final posts = await ProApiService().getMyCommunityPosts();
      if (mounted) setState(() => _myPosts = posts);
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _performSearch(value.trim()));
  }

  Future<void> _performSearch(String query) async {
    setState(() => _searchQuery = query);
    if (query.length < 2) {
      setState(() { _isSearching = false; _searchResults = []; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await ProApiService().searchCommunityPosts(query, postType: _activeFilter);
      if (mounted && _searchQuery == query) {
        setState(() { _searchResults = results; _isSearching = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() { _searchQuery = ''; _searchResults = []; _isSearching = false; });
  }

  void _setFilter(String? type) {
    setState(() => _activeFilter = type);
    _load();
    if (_searchQuery.isNotEmpty) _performSearch(_searchQuery);
  }

  Future<void> _publish(String content, String postType) async {
    await ProApiService().createCommunityPost(content, postType: postType);
    await _load();
    if (_myPostsLoaded) await _loadMyPosts();
  }

  void _openComposePage() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ProComposePage(onSubmit: _publish),
    ));
  }

  void _updatePostInLists(String postId, Map<String, dynamic> Function(Map<String, dynamic>) update) {
    setState(() {
      for (final list in [_posts, _myPosts, _searchResults]) {
        final i = list.indexWhere((p) => p['_id'] == postId);
        if (i != -1) list[i] = update(Map<String, dynamic>.from(list[i] as Map));
      }
    });
  }

  Future<void> _react(String postId, String type) async {
    try {
      final result = await ProApiService().toggleReaction(postId, type);
      _updatePostInLists(postId, (p) => p
        ..['reactions'] = result['reactions']
        ..['myReactionType'] = result['myReaction']);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _toggleSameFeeling(String postId) async {
    try {
      final isNow = await ProApiService().toggleSameFeeling(postId);
      _updatePostInLists(postId, (p) => p
        ..['isSameFeeling'] = isNow
        ..['sameFeelingsCount'] = (p['sameFeelingsCount'] ?? 0) + (isNow ? 1 : -1));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Text('Supprimer ce post ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ProApiService().deleteCommunityPost(postId);
      setState(() {
        _posts.removeWhere((p) => p['_id'] == postId);
        _myPosts.removeWhere((p) => p['_id'] == postId);
        _searchResults.removeWhere((p) => p['_id'] == postId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _openComments(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(postId: post['_id'] as String, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedPosts = _searchQuery.length >= 2 ? _searchResults : _posts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Communauté', style: AppTextStyles.h3),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceMuted,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Fil'), Tab(text: 'Mes posts')],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // ── Onglet Fil ──────────────────────────────────────────────
            Column(
              children: [
                const SizedBox(height: 8),
                _buildSearchBar(),
                _buildFilterChips(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _buildFeedList(displayedPosts, isLoading: _isLoading || _isSearching, error: _error),
                  ),
                ),
              ],
            ),

            // ── Onglet Mes posts ─────────────────────────────────────────
            RefreshIndicator(
              onRefresh: _loadMyPosts,
              child: _buildFeedList(_myPosts, isLoading: !_myPostsLoaded, error: null, emptyText: 'Tu n\'as encore rien publié.'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openComposePage,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher dans la communauté...',
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.onSurfaceMuted),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : (_searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _clearSearch)
                  : null),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: AppRadius.full, borderSide: const BorderSide(color: AppColors.divider)),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final types = postTypeConfig.keys.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          custom.FilterChip(
            label: 'Tout',
            emoji: '🌐',
            isSelected: _activeFilter == null,
            color: AppColors.primary,
            onTap: () => _setFilter(null),
          ),
          const SizedBox(width: 8),
          ...types.map((id) {
            final conf = postTypeConfig[id]!;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: custom.FilterChip(
                label: conf.label,
                emoji: conf.emoji,
                isSelected: _activeFilter == id,
                color: conf.color,
                onTap: () => _setFilter(id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeedList(List<dynamic> posts, {required bool isLoading, String? error, String emptyText = 'Aucun post pour l\'instant.'}) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error)));
    if (posts.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          Center(child: Text(emptyText, style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted))),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: posts.length,
      itemBuilder: (context, index) => _PostCard(
        post: posts[index] as Map<String, dynamic>,
        onReact: (type) => _react(posts[index]['_id'] as String, type),
        onSameFeeling: () => _toggleSameFeeling(posts[index]['_id'] as String),
        onComment: () => _openComments(posts[index] as Map<String, dynamic>),
        onDelete: () => _deletePost(posts[index]['_id'] as String),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final void Function(String type) onReact;
  final VoidCallback onSameFeeling;
  final VoidCallback onComment;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.onReact,
    required this.onSameFeeling,
    required this.onComment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final author = post['author'] as Map<String, dynamic>?;
    final isProfessional = author?['isProfessional'] == true;
    final displayName = isProfessional
        ? (author?['name'] as String? ?? 'Professionnel partenaire')
        : (author?['anonymousAlias'] as String? ?? 'Anonyme');
    final content = post['content'] as String? ?? '';
    final isMine = post['isMine'] == true;
    final myReaction = post['myReactionType'] as String?;
    final reactions = (post['reactions'] as List<dynamic>? ?? []);
    final isSameFeeling = post['isSameFeeling'] == true;
    final sameFeelingsCount = post['sameFeelingsCount'] ?? 0;
    final commentsCount = post['commentsCount'] ?? 0;
    final postType = post['postType'] as String?;
    final typeConf = postType != null ? postTypeConfig[postType] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: isProfessional ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isProfessional) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.full),
                        child: const Text('Professionnel',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
              ),
              if (typeConf != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(color: typeConf.color.withValues(alpha: 0.12), borderRadius: AppRadius.full),
                  child: Text('${typeConf.emoji} ${typeConf.label}',
                      style: TextStyle(color: typeConf.color, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              if (isMine)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: AppColors.onSurfaceMuted, size: 20),
                  onSelected: (v) { if (v == 'delete') onDelete(); },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: AppTextStyles.body),
          const SizedBox(height: 12),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._reactionEmojis.entries.map((e) {
                final data = reactions.firstWhere((r) => r['type'] == e.key, orElse: () => null);
                final count = data != null ? (data['count'] ?? 0) : 0;
                final mine = myReaction == e.key;
                if (count == 0 && !mine) return const SizedBox.shrink();
                return _Chip(label: '${e.value}${count > 0 ? ' $count' : ''}', isActive: mine, onTap: () => onReact(e.key));
              }),
              if (myReaction == null)
                _Chip(label: 'Réagir', isActive: false, onTap: () => onReact('heart')),
              _Chip(
                label: 'Même ressenti${sameFeelingsCount > 0 ? ' $sameFeelingsCount' : ''}',
                isActive: isSameFeeling,
                onTap: onSameFeeling,
              ),
              _Chip(label: '${commentsCount > 0 ? commentsCount : 'Commenter'}', isActive: false, onTap: onComment),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceVariant,
          borderRadius: AppRadius.full,
          border: isActive ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isActive ? AppColors.primary : AppColors.onSurfaceMuted,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Feuille de commentaires — fil + réponses + like par commentaire.
// ═══════════════════════════════════════════════════════════════════════════
class _CommentsSheet extends StatefulWidget {
  final String postId;
  final VoidCallback onChanged;
  const _CommentsSheet({required this.postId, required this.onChanged});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  bool _isLoading = true;
  List<dynamic> _comments = [];
  final _inputController = TextEditingController();
  String? _replyingToId;
  String? _replyingToName;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final comments = await ProApiService().getComments(widget.postId);
      setState(() { _comments = comments; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await ProApiService().addCommunityComment(widget.postId, text, parentCommentId: _replyingToId);
      _inputController.clear();
      setState(() { _replyingToId = null; _replyingToName = null; });
      await _load();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _like(String commentId) async {
    try {
      await ProApiService().toggleCommentLike(widget.postId, commentId);
      _load();
    } catch (_) {}
  }

  void _startReply(String commentId, String name) {
    setState(() { _replyingToId = commentId; _replyingToName = name; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: AppRadius.full)),
              const SizedBox(height: 12),
              const Text('Commentaires', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _comments.isEmpty
                        ? Center(child: Text('Aucun commentaire pour l\'instant.', style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)))
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _comments.length,
                            itemBuilder: (context, i) => _CommentTile(
                              comment: _comments[i] as Map<String, dynamic>,
                              onLike: _like,
                              onReply: _startReply,
                            ),
                          ),
              ),
              if (_replyingToId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: AppColors.surfaceVariant,
                  child: Row(
                    children: [
                      Expanded(child: Text('Réponse à $_replyingToName', style: AppTextStyles.caption)),
                      IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() { _replyingToId = null; _replyingToName = null; })),
                    ],
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          decoration: InputDecoration(
                            hintText: 'Écrire un commentaire...',
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: AppRadius.full, borderSide: const BorderSide(color: AppColors.divider)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _isSending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send, color: AppColors.primary),
                        onPressed: _isSending ? null : _send,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final void Function(String commentId) onLike;
  final void Function(String commentId, String name) onReply;
  final int depth;

  const _CommentTile({required this.comment, required this.onLike, required this.onReply, this.depth = 0});

  @override
  Widget build(BuildContext context) {
    final author = comment['author'] as Map<String, dynamic>?;
    final isProfessional = author?['isProfessional'] == true;
    final name = isProfessional
        ? (author?['name'] as String? ?? 'Professionnel')
        : (author?['anonymousAlias'] as String? ?? 'Anonyme');
    final content = comment['content'] as String? ?? '';
    final isLiked = comment['isLiked'] == true;
    final likesCount = comment['likesCount'] ?? 0;
    final replies = (comment['replies'] as List<dynamic>? ?? []);
    final id = comment['_id'] as String;

    // Plafonné à 4 niveaux : au-delà, un fil très profond finirait par
    // écraser le contenu utile sur les écrans étroits.
    final indent = math.min(depth, 4) * 24.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 10, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
              if (isProfessional) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.full),
                  child: const Text('Pro', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(content, style: AppTextStyles.body),
          const SizedBox(height: 4),
          Row(
            children: [
              GestureDetector(
                onTap: () => onLike(id),
                child: Row(
                  children: [
                    Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 14, color: isLiked ? AppColors.primary : AppColors.onSurfaceMuted),
                    if (likesCount > 0) ...[
                      const SizedBox(width: 3),
                      Text('$likesCount', style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => onReply(id, name),
                child: Text('Répondre', style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
              ),
            ],
          ),
          ...replies.map((r) => _CommentTile(comment: r as Map<String, dynamic>, onLike: onLike, onReply: onReply, depth: depth + 1)),
        ],
      ),
    );
  }
}