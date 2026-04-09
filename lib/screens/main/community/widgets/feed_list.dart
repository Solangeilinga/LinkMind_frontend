import 'package:flutter/material.dart';
import '../../../../utils/theme.dart';
import '../../../../widgets/ad_banner.dart';
import 'post_card.dart';
import 'empty_feed.dart';

class FeedList extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Function(String) onLike;
  final Function(String) onDelete;
  final VoidCallback onCompose;
  final String emptyMessage;

  const FeedList({
    super.key,
    required this.posts,
    required this.isLoading,
    required this.onRefresh,
    required this.onLike,
    required this.onDelete,
    required this.onCompose,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    
    if (posts.isEmpty) {
      return EmptyFeed(onCompose: onCompose, message: emptyMessage);
    }
    
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: posts.length + (posts.length ~/ 5),
        itemBuilder: (context, i) {
          final adEvery = 5;
          final adsInserted = i ~/ (adEvery + 1);
          final postIndex = i - adsInserted;
          
          if (i > 0 && (i + 1) % (adEvery + 1) == 0) {
            return const AdBanner(placement: 'community_feed');
          }
          
          if (postIndex >= posts.length) return const SizedBox.shrink();
          
          final postId = (posts[postIndex]['_id'] ?? posts[postIndex]['id'] ?? '').toString();
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(
              post: posts[postIndex],
              onLike: () => onLike(postId),
              onDelete: () => onDelete(postId),
              isMine: posts[postIndex]['isMine'] == true,
            ),
          );
        },
      ),
    );
  }
}