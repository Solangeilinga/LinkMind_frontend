import 'package:flutter/material.dart';
import '../../../../utils/theme.dart';
import '../../../../widgets/skeleton_widget.dart';
import 'post_card.dart';
import 'empty_feed.dart';

class FeedList extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final bool isLoading;
  final bool isPaginating;
  final Future<void> Function() onRefresh;
  final VoidCallback? onLoadMore;  // ✅ rendu optionnel
  final Function(String) onLike;
  final Function(String) onDelete;
  final VoidCallback onCompose;
  final String emptyMessage;

  const FeedList({
    super.key,
    required this.posts,
    required this.isLoading,
    this.isPaginating = false,
    required this.onRefresh,
    this.onLoadMore,  // optionnel
    required this.onLike,
    required this.onDelete,
    required this.onCompose,
    required this.emptyMessage,
  });

  @override
  State<FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<FeedList> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (widget.onLoadMore != null &&  // ✅ vérifier si non null
          _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
        widget.onLoadMore!();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return SkeletonList(itemBuilder: () => const SkeletonPostCard(), count: 4);
    }
    
    if (widget.posts.isEmpty) {
      return EmptyFeed(onCompose: widget.onCompose, message: widget.emptyMessage);
    }
    
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: widget.posts.length + (widget.isPaginating ? 1 : 0),
        itemBuilder: (context, i) {
          // Loader de pagination (seulement si onLoadMore existe)
          if (widget.onLoadMore != null && i == widget.posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            );
          }

          if (i >= widget.posts.length) return const SizedBox.shrink();

          final post = widget.posts[i];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(
              post: post,
              isMine: post['isMine'] == true,
              // ⚠️ CORRECTION : post['_id'] doit être un String. Le correctif
              // backend (serializePost/serializeComment) garantit maintenant
              // que c'est le cas, mais .toString() ici protège aussi contre
              // du contenu déjà en cache côté app avant la mise à jour du
              // serveur, ou tout autre cas de figure inattendu.
              onLike: () => widget.onLike((post['_id'] ?? post['id']).toString()),
              onDelete: () => widget.onDelete((post['_id'] ?? post['id']).toString()),
            ),
          );
        },
      ),
    );
  }
}