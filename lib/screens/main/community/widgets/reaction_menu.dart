import 'package:flutter/material.dart';
import '../../../../utils/theme.dart';

class ReactionItem extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const ReactionItem({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 24)),
      title: Text(label, style: AppTextStyles.bodySmall),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

void showReactionMenu(
  BuildContext context,
  String postId,
  VoidCallback onLike,
  VoidCallback onSameFeeling,
  Function(String) onReaction,
) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Wrap(
        children: [
          ReactionItem(emoji: '❤️', label: 'J\'aime', onTap: onLike),
          ReactionItem(emoji: '🤝', label: 'Moi aussi', onTap: onSameFeeling),
          // ✅ Types compatibles avec le backend
          ReactionItem(emoji: '😮', label: 'Wow', onTap: () => onReaction('fire')),
          ReactionItem(emoji: '😢', label: 'Triste', onTap: () => onReaction('heart')),
          ReactionItem(emoji: '🔥', label: 'Fier', onTap: () => onReaction('strong')),
          ReactionItem(emoji: '💪', label: 'Fort', onTap: () => onReaction('hug')),
        ],
      ),
    ),
  );
}