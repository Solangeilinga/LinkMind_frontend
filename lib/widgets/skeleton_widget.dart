import 'package:flutter/material.dart';
import '../utils/theme.dart';

// ─── Widget skeleton de base ──────────────────────────────────────────────────
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  final bool isCircle;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = 8,
    this.isCircle = false,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.isCircle ? widget.height : widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: _anim.value),
          borderRadius: widget.isCircle
              ? BorderRadius.circular(widget.height / 2)
              : BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ─── Skeleton carte professionnel ─────────────────────────────────────────────
class SkeletonProCard extends StatelessWidget {
  const SkeletonProCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SkeletonBox(width: 56, height: 56, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SkeletonBox(height: 15, radius: 6),
            const SizedBox(height: 7),
            const SkeletonBox(width: 120, height: 12, radius: 5),
            const SizedBox(height: 10),
            Row(children: const [
              SkeletonBox(width: 60, height: 22, radius: 11),
              SizedBox(width: 8),
              SkeletonBox(width: 75, height: 22, radius: 11),
            ]),
          ]),
        ),
        const SizedBox(width: 12),
        const SkeletonBox(width: 70, height: 32, radius: 8),
      ]),
    );
  }
}

// ─── Skeleton post communauté ─────────────────────────────────────────────────
class SkeletonPostCard extends StatelessWidget {
  const SkeletonPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SkeletonBox(height: 36, radius: 18, isCircle: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              SkeletonBox(width: 120, height: 13, radius: 5),
              SizedBox(height: 5),
              SkeletonBox(width: 80, height: 11, radius: 4),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        const SkeletonBox(height: 13, radius: 5),
        const SizedBox(height: 6),
        const SkeletonBox(width: 240, height: 13, radius: 5),
        const SizedBox(height: 6),
        const SkeletonBox(width: 180, height: 13, radius: 5),
        const SizedBox(height: 12),
        Row(children: const [
          SkeletonBox(width: 44, height: 22, radius: 11),
          SizedBox(width: 12),
          SkeletonBox(width: 44, height: 22, radius: 11),
          SizedBox(width: 12),
          SkeletonBox(width: 44, height: 22, radius: 11),
        ]),
      ]),
    );
  }
}

// ─── Skeleton booking card ────────────────────────────────────────────────────
class SkeletonBookingCard extends StatelessWidget {
  const SkeletonBookingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            SkeletonBox(width: 140, height: 15, radius: 6),
            SizedBox(height: 7),
            SkeletonBox(width: 90, height: 12, radius: 5),
          ])),
          const SkeletonBox(width: 70, height: 24, radius: 12),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const SkeletonBox(height: 36, radius: 18, isCircle: true),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            SkeletonBox(width: 130, height: 13, radius: 5),
            SizedBox(height: 5),
            SkeletonBox(width: 90, height: 11, radius: 4),
          ])),
        ]),
        const SizedBox(height: 12),
        const SkeletonBox(height: 36, radius: 10),
      ]),
    );
  }
}

// ─── Skeleton liste générique ─────────────────────────────────────────────────
class SkeletonList extends StatelessWidget {
  final Widget Function() itemBuilder;
  final int count;
  final EdgeInsets padding;

  const SkeletonList({
    super.key,
    required this.itemBuilder,
    this.count = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, __) => itemBuilder(),
    );
  }
}

// ─── Skeleton home humeur ─────────────────────────────────────────────────────
class SkeletonMoodScreen extends StatelessWidget {
  const SkeletonMoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Carte message du jour
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            SkeletonBox(width: 100, height: 12, radius: 4),
            SizedBox(height: 10),
            SkeletonBox(height: 15, radius: 6),
            SizedBox(height: 6),
            SkeletonBox(width: 200, height: 15, radius: 6),
          ]),
        ),
        const SizedBox(height: 12),
        // Grille émojis humeur
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SkeletonBox(width: 150, height: 13, radius: 5),
            const SizedBox(height: 12),
            Row(children: List.generate(5, (_) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: const SkeletonBox(height: 52, radius: 10),
              ),
            ))),
          ]),
        ),
        const SizedBox(height: 12),
        // Challenge du jour
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            SkeletonBox(width: 120, height: 13, radius: 5),
            SizedBox(height: 10),
            SkeletonBox(height: 14, radius: 5),
            SizedBox(height: 6),
            SkeletonBox(width: 220, height: 14, radius: 5),
            SizedBox(height: 6),
            SkeletonBox(width: 180, height: 14, radius: 5),
            SizedBox(height: 14),
            SkeletonBox(height: 44, radius: 12),
          ]),
        ),
      ]),
    );
  }
}