import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../utils/theme.dart';

// ─── Mapping réactions ────────────────────────────────────────────────────────
const kReactionEmojis = {
  'heart':  '❤️',
  'hug':    '🤗',
  'strong': '💪',
  'fire':   '🔥',
};

const kReactionLabels = {
  'heart':  'J\'aime',
  'hug':    'Câlin',
  'strong': 'Courage',
  'fire':   'Fier',
};

// ─── Superposition d'icônes de réactions (Facebook-style) ────────────────────
class ReactionStack extends StatelessWidget {
  final List<Map<String, dynamic>> reactions; // [{type, count, isMine}]
  final int totalCount;

  const ReactionStack({super.key, required this.reactions, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0) return const SizedBox.shrink();

    // Top 3 réactions par count
    final sorted = [...reactions]..sort((a, b) =>
        (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0));
    final top = sorted.take(3).toList();

    return Row(mainAxisSize: MainAxisSize.min, children: [
      // Icônes superposées
      SizedBox(
        width: top.length * 16.0 + 4,
        height: 22,
        child: Stack(
          children: top.asMap().entries.map((e) {
            final emoji = kReactionEmojis[e.value['type']] ?? '👍';
            return Positioned(
              left: e.key * 14.0,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider, width: 1),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 12)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(width: 4),
      Text(
        '$totalCount',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.onSurfaceMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ]);
  }
}

// ─── Overlay réactions flottant (Facebook-style long press) ───────────────────
class ReactionOverlay extends StatefulWidget {
  final String? currentReaction; // type actuel de l'utilisateur (null = pas de réaction)
  final Function(String?) onReactionSelected; // null = unlike/remove

  const ReactionOverlay({
    super.key,
    required this.currentReaction,
    required this.onReactionSelected,
  });

  @override
  State<ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends State<ReactionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  String? _hovered;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      alignment: Alignment.bottomLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: kReactionEmojis.entries.map((e) {
            final isActive = widget.currentReaction == e.key;
            final isHovered = _hovered == e.key;
            return GestureDetector(
              onTap: () {
                // Si même réaction → unlike, sinon → nouvelle réaction
                widget.onReactionSelected(isActive ? null : e.key);
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovered = e.key),
                onExit: (_) => setState(() => _hovered = null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : isHovered
                            ? AppColors.surfaceVariant
                            : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedScale(
                      scale: isHovered || isActive ? 1.3 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Text(e.value, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kReactionLabels[e.key] ?? '',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 9,
                        color: isActive ? AppColors.primary : AppColors.onSurfaceMuted,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Bouton J'aime avec overlay long press ────────────────────────────────────
class LikeButton extends StatefulWidget {
  final bool isLiked;
  final String? myReactionType; // type de la réaction de l'utilisateur connecté
  final List<Map<String, dynamic>> reactions;
  final int totalCount;
  final VoidCallback onTap;
  final Function(String?) onReactionSelected; // null = retirer la réaction

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.myReactionType,
    required this.reactions,
    required this.totalCount,
    required this.onTap,
    required this.onReactionSelected,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  OverlayEntry? _overlayEntry;
  bool _overlayVisible = false;

  void _showOverlay() {
    if (_overlayVisible) return;
    HapticFeedback.mediumImpact();

    final box = context.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: position.dx,
        top: position.dy - 90,
        child: Material(
          color: Colors.transparent,
          child: ReactionOverlay(
            currentReaction: widget.myReactionType,
            onReactionSelected: (type) {
              _hideOverlay();
              widget.onReactionSelected(type);
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _overlayVisible = true);

    // Auto-fermer après 4 secondes
    Future.delayed(const Duration(seconds: 4), _hideOverlay);
  }

  void _hideOverlay() {
    if (!_overlayVisible) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _overlayVisible = false);
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  String get _currentEmoji => kReactionEmojis[widget.myReactionType] ?? '❤️';
  bool get _hasReaction => widget.myReactionType != null || widget.isLiked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_overlayVisible) {
          _hideOverlay();
        } else {
          widget.onTap();
        }
      },
      onLongPress: _showOverlay,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Icône cœur ou emoji de la réaction choisie
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _hasReaction
                ? Text(
                    _currentEmoji,
                    key: ValueKey(widget.myReactionType ?? 'liked'),
                    style: const TextStyle(fontSize: 18),
                  )
                : const Icon(
                    Icons.favorite_border,
                    key: ValueKey('not_liked'),
                    size: 20,
                    color: AppColors.onSurfaceMuted,
                  ),
          ),
          const SizedBox(width: 6),
          if (widget.totalCount > 0)
            ReactionStack(reactions: widget.reactions, totalCount: widget.totalCount)
          else
            Text(
              'J\'aime',
              style: AppTextStyles.caption.copyWith(
                color: _hasReaction ? AppColors.accent : AppColors.onSurfaceMuted,
                fontWeight: _hasReaction ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
        ]),
      ),
    );
  }
}

// Compatibilité avec l'ancien code (peut être supprimé après migration)
void showReactionMenu(
  BuildContext context,
  String postId,
  VoidCallback onLike,
  VoidCallback onSameFeeling,
  Function(String) onReaction,
) {}