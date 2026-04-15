import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api.service.dart';

class FeedState {
  final bool isLoadingAll;
  final bool isPaginatingAll;
  final List<Map<String, dynamic>> allPosts;
  final int allPage;
  final bool allHasMore;

  final bool isLoadingMine;
  final bool isPaginatingMine;
  final List<Map<String, dynamic>> myPosts;
  final int myPage;
  final bool myHasMore;

  FeedState({
    this.isLoadingAll = true,
    this.isPaginatingAll = false,
    this.allPosts = const [],
    this.allPage = 1,
    this.allHasMore = true,
    this.isLoadingMine = true,
    this.isPaginatingMine = false,
    this.myPosts = const [],
    this.myPage = 1,
    this.myHasMore = true,
  });

  FeedState copyWith({
    bool? isLoadingAll,
    bool? isPaginatingAll,
    List<Map<String, dynamic>>? allPosts,
    int? allPage,
    bool? allHasMore,
    bool? isLoadingMine,
    bool? isPaginatingMine,
    List<Map<String, dynamic>>? myPosts,
    int? myPage,
    bool? myHasMore,
  }) {
    return FeedState(
      isLoadingAll: isLoadingAll ?? this.isLoadingAll,
      isPaginatingAll: isPaginatingAll ?? this.isPaginatingAll,
      allPosts: allPosts ?? this.allPosts,
      allPage: allPage ?? this.allPage,
      allHasMore: allHasMore ?? this.allHasMore,
      isLoadingMine: isLoadingMine ?? this.isLoadingMine,
      isPaginatingMine: isPaginatingMine ?? this.isPaginatingMine,
      myPosts: myPosts ?? this.myPosts,
      myPage: myPage ?? this.myPage,
      myHasMore: myHasMore ?? this.myHasMore,
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  final ApiService _api = ApiService();
  String? _currentFilter;

  FeedNotifier() : super(FeedState()) {
    loadAllPosts();
    loadMyPosts();
  }

  // ─── Flux Global ───
  Future<void> loadAllPosts({String? filter}) async {
    _currentFilter = filter;
    print('🔄 [FEED] loadAllPosts with filter: $filter');
    state = state.copyWith(isLoadingAll: true, allPage: 1);
    try {
      final data = await _api.getFeed(page: 1, limit: 20, type: filter);
      final posts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
      print('✅ [FEED] Chargé ${posts.length} posts');
      state = state.copyWith(
        isLoadingAll: false,
        allPosts: posts,
        allHasMore: posts.length == 20,
      );
    } catch (e) {
      print('❌ [FEED] loadAllPosts error: $e');
      state = state.copyWith(isLoadingAll: false, allPosts: []);
    }
  }

  Future<void> loadMoreAllPosts() async {
    if (!state.allHasMore || state.isPaginatingAll || state.isLoadingAll) return;
    state = state.copyWith(isPaginatingAll: true);
    try {
      final nextPage = state.allPage + 1;
      final data = await _api.getFeed(page: nextPage, limit: 20, type: _currentFilter);
      final newPosts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
      state = state.copyWith(
        isPaginatingAll: false,
        allPage: nextPage,
        allPosts: [...state.allPosts, ...newPosts],
        allHasMore: newPosts.length == 20,
      );
    } catch (e) {
      print('❌ [FEED] loadMoreAllPosts error: $e');
      state = state.copyWith(isPaginatingAll: false);
    }
  }

  // ─── Mes Posts ───
  Future<void> loadMyPosts() async {
    state = state.copyWith(isLoadingMine: true, myPage: 1);
    try {
      final data = await _api.getMyPosts(page: 1, limit: 20);
      final posts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
      state = state.copyWith(
        isLoadingMine: false,
        myPosts: posts,
        myHasMore: posts.length == 20,
      );
    } catch (e) {
      print('❌ [FEED] loadMyPosts error: $e');
      state = state.copyWith(isLoadingMine: false, myPosts: []);
    }
  }

  Future<void> loadMoreMyPosts() async {
    if (!state.myHasMore || state.isPaginatingMine || state.isLoadingMine) return;
    state = state.copyWith(isPaginatingMine: true);
    try {
      final nextPage = state.myPage + 1;
      final data = await _api.getMyPosts(page: nextPage, limit: 20);
      final newPosts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
      state = state.copyWith(
        isPaginatingMine: false,
        myPage: nextPage,
        myPosts: [...state.myPosts, ...newPosts],
        myHasMore: newPosts.length == 20,
      );
    } catch (e) {
      print('❌ [FEED] loadMoreMyPosts error: $e');
      state = state.copyWith(isPaginatingMine: false);
    }
  }

  // ─── Créer un post ───
  Future<bool> createPost(String content, String type, String? moodEmoji) async {
    try {
      await _api.createPost(
        content: content,
        postType: type,
        isAnonymous: true,
        moodEmoji: moodEmoji,
      );
      // Recharger les deux flux
      await loadAllPosts(filter: _currentFilter);
      await loadMyPosts();
      return true;
    } catch (e) {
      print('❌ [FEED] createPost error: $e');
      return false;
    }
  }

  // ─── Liker / réagir ───
  Future<void> toggleLike(String postId) async {
    // Sauvegarde avant modification
    final oldAllPosts = List<Map<String, dynamic>>.from(state.allPosts);
    final oldMyPosts = List<Map<String, dynamic>>.from(state.myPosts);

    void updateList(List<Map<String, dynamic>> posts) {
      final idx = posts.indexWhere((p) => (p['_id'] ?? p['id']).toString() == postId);
      if (idx != -1) {
        final post = posts[idx];
        final isLiked = post['isLiked'] == true;
        posts[idx] = {
          ...post,
          'isLiked': !isLiked,
          'likesCount': ((post['likesCount'] ?? 0) as int) + (isLiked ? -1 : 1),
        };
      }
    }

    updateList(state.allPosts);
    updateList(state.myPosts);
    state = state.copyWith(allPosts: state.allPosts, myPosts: state.myPosts);

    try {
      final response = await _api.toggleLike(postId);
      final newLiked = response['liked'] as bool;
      final newCount = response['likesCount'] as int;
      void finalUpdate(List<Map<String, dynamic>> posts) {
        final idx = posts.indexWhere((p) => (p['_id'] ?? p['id']).toString() == postId);
        if (idx != -1) {
          posts[idx] = {...posts[idx], 'isLiked': newLiked, 'likesCount': newCount};
        }
      }
      finalUpdate(state.allPosts);
      finalUpdate(state.myPosts);
      state = state.copyWith(allPosts: state.allPosts, myPosts: state.myPosts);
    } catch (e) {
      // Rollback
      state = state.copyWith(allPosts: oldAllPosts, myPosts: oldMyPosts);
    }
  }

  // ─── Supprimer un post ───
  Future<void> deletePost(String postId) async {
    final newAllPosts = state.allPosts.where((p) => (p['_id'] ?? p['id']).toString() != postId).toList();
    final newMyPosts = state.myPosts.where((p) => (p['_id'] ?? p['id']).toString() != postId).toList();
    state = state.copyWith(allPosts: newAllPosts, myPosts: newMyPosts);

    try {
      await _api.deletePost(postId);
    } catch (e) {
      await loadAllPosts(filter: _currentFilter);
      await loadMyPosts();
    }
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) => FeedNotifier());