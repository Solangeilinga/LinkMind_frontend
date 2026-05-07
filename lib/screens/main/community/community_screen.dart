import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/theme.dart';
import '../../../services/api.service.dart';
import '../../../services/security.service.dart';
import 'widgets/feed_list.dart';
import 'widgets/filter_chip.dart' as custom;
import 'widgets/compose_page.dart';
import 'models/post_type_config.dart';
import '../../../widgets/report_button.dart';
import '../../../middleware/activity_recorder.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _allPosts = [];
  List<Map<String, dynamic>> _myPosts = [];
  bool _isLoadingAll = true;
  bool _isLoadingMine = true;
  String? _activeFilter;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging && mounted) setState(() {});
      });
    _loadFeed();
    _loadMyPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    if (!mounted) return;
    setState(() => _isLoadingAll = true);
    try {
      final data = await ApiService().getFeed(page: 1);
      if (mounted) {
        setState(() {
          _allPosts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
          _isLoadingAll = false;
        });
        SecurityService.recordActivity(type: 'view_feed');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement feed: $e');
      if (mounted) setState(() => _isLoadingAll = false);
    }
  }

  Future<void> _loadMyPosts() async {
    if (!mounted) return;
    setState(() => _isLoadingMine = true);
    try {
      final data = await ApiService().getMyPosts(page: 1);
      if (mounted) {
        setState(() {
          _myPosts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
          _isLoadingMine = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement mes posts: $e');
      if (mounted) setState(() => _isLoadingMine = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadFeed(), _loadMyPosts()]);
  }

  // Les réactions sont désormais gérées entièrement dans PostCard.
  // Cette méthode est conservée pour la compatibilité avec FeedList,
  // mais elle ne fait rien car PostCard ne l'appelle plus.
  Future<void> _toggleLike(String postId) async {
    // Aucune action nécessaire – PostCard gère lui-même ses réactions.
    // On garde juste l'enregistrement d'activité si souhaité.
    SecurityService.recordActivity(type: 'like', metadata: {'postId': postId});
  }

  Future<void> _deletePost(String postId) async {
    if (mounted) {
      setState(() {
        _allPosts.removeWhere((p) => (p['_id'] ?? p['id']).toString() == postId);
        _myPosts.removeWhere((p) => (p['_id'] ?? p['id']).toString() == postId);
      });
    }

    try {
      await ApiService().deletePost(postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post supprimé'), backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      if (mounted) {
        await _refreshAll();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur suppression'), backgroundColor: AppColors.accent),
        );
      }
    }
  }

  void _openComposePage() {
    SecurityService.recordActivity(type: 'open_compose');

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ComposePage(
          onSubmit: (content, type, moodEmoji) async {
            try {
              await ApiService().createPost(
                content: content,
                postType: type,
                isAnonymous: true,
                moodEmoji: moodEmoji,
              );
              if (mounted) {
                await _loadFeed();
                await _loadMyPosts();
              }
            } catch (e) {
              debugPrint('Erreur publication: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.accent),
                );
              }
            }
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> posts) {
    if (_activeFilter == null) return posts;
    return posts.where((p) => p['postType'] == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Communauté 🌍', style: AppTextStyles.h2),
                          Text('Espace sécurisé · Tout est anonyme',
                              style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
                        ],
                      ),
                      ActivityRecorder(
                        activityType: 'create_post_click',
                        child: ElevatedButton.icon(
                          onPressed: _openComposePage,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Partager'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
                      tabs: const [Tab(text: 'Communauté'), Tab(text: 'Mes posts')],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        custom.FilterChip(
                          label: 'Tous',
                          emoji: '🌐',
                          isSelected: _activeFilter == null,
                          color: AppColors.primary,
                          onTap: () {
                            setState(() => _activeFilter = null);
                            _loadFeed();
                          },
                        ),
                        const SizedBox(width: 8),
                        ...postTypeConfig.entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: custom.FilterChip(
                              label: e.value.label,
                              emoji: e.value.emoji,
                              isSelected: _activeFilter == e.key,
                              color: e.value.color,
                              onTap: () {
                                setState(() => _activeFilter = _activeFilter == e.key ? null : e.key);
                                _loadFeed();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  FeedList(
                    posts: _filtered(_allPosts),
                    isLoading: _isLoadingAll,
                    onRefresh: _loadFeed,
                    onLike: _toggleLike,   // conservé mais ne fait rien
                    onDelete: _deletePost,
                    onCompose: _openComposePage,
                    emptyMessage: _activeFilter != null
                        ? 'Aucun partage de ce type'
                        : 'La communauté t\'attend',
                  ),
                  FeedList(
                    posts: _filtered(_myPosts),
                    isLoading: _isLoadingMine,
                    onRefresh: _loadMyPosts,
                    onLike: _toggleLike,   // conservé mais ne fait rien
                    onDelete: _deletePost,
                    onCompose: _openComposePage,
                    emptyMessage: 'Tu n\'as encore rien partagé',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}