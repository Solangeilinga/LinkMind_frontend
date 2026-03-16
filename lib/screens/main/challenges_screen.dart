import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  static const _categoryColors = {
    'breathing':  AppColors.primary,
    'meditation': AppColors.primary,
    'journaling': AppColors.primary,
    'gratitude':  AppColors.primary,
    'movement':   AppColors.primary,
    'social':     AppColors.primary,
    'creativity': AppColors.primary,
    'game':       AppColors.primary,
  };

  static const _categoryLabels = {
    'breathing': 'Respiration',
    'meditation': 'Méditation',
    'journaling': 'Journal',
    'gratitude': 'Gratitude',
    'movement': 'Mouvement',
    'social': 'Social',
    'creativity': 'Créativité',
    'game': 'Mini-jeu',
  };

  static const _difficultyLabels = {
    'easy': ('Facile', Color(0xFF6BCF7F)),
    'medium': ('Moyen', Color(0xFFFFD93D)),
    'hard': ('Difficile', Color(0xFFFF7675)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(challengesProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(challengesProvider.notifier).loadDaily(),
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Défis du jour', style: AppTextStyles.h2),
                      const SizedBox(height: 4),
                      Text('Complète des défis pour gagner des points',
                          style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
                    ],
                  ),
                ),
              ),

              // Daily XP bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DailyProgressBar(
                    completed: state.daily.where((c) => c['isCompleted'] == true).length,
                    total: state.daily.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              // Section title
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Activités personnalisées', style: AppTextStyles.h3),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Challenge list
              if (state.isLoading)
                const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )),
                )
              else if (state.daily.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyState(onRefresh: () => ref.read(challengesProvider.notifier).loadDaily()),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final challenge = state.daily[i];
                      return Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, i < state.daily.length - 1 ? 12 : 0),
                        child: _ChallengeCard(
                          challenge: challenge,
                          categoryColors: _categoryColors,
                          categoryLabels: _categoryLabels,
                          difficultyLabels: _difficultyLabels,
                          onTap: () => context.push('/challenges/${challenge['_id'] ?? challenge['id']}'),
                        ),
                      );
                    },
                    childCount: state.daily.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompleteDialog(BuildContext context, Map<String, dynamic> result, Map<String, dynamic> challenge) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Text('🎉 Défi accompli !', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(challenge['icon'] ?? '⚡', style: const TextStyle(fontSize: 48), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('+${challenge['points']} points gagnés',
                style: AppTextStyles.h3.copyWith(color: AppColors.primary), textAlign: TextAlign.center),
            if (result['newBadges'] is List && (result['newBadges'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              ...((result['newBadges'] as List).map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(b['icon'] ?? '🏅', style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text('Badge "${b['name']}" débloqué !',
                        style: AppTextStyles.body.copyWith(color: AppColors.accentOrange, fontWeight: FontWeight.w700)),
                  ],
                ),
              ))),
            ],
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
              child: const Text('Continuer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final Map<String, Color> categoryColors;
  final Map<String, String> categoryLabels;
  final Map<String, (String, Color)> difficultyLabels;
  final VoidCallback onTap;

  const _ChallengeCard({
    required this.challenge,
    required this.categoryColors,
    required this.categoryLabels,
    required this.difficultyLabels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = challenge['category'] as String? ?? '';
    final isCompleted = challenge['isCompleted'] == true;
    final catColor = categoryColors[category] ?? AppColors.primary;
    final (diffLabel, diffColor) = difficultyLabels[challenge['difficulty']] ?? ('Facile', AppColors.secondary);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.secondary.withValues(alpha: 0.05) : AppColors.surface,
          borderRadius: AppRadius.lg,
          border: Border.all(
            color: isCompleted ? AppColors.secondary : AppColors.divider,
            width: 1.5,
          ),
          boxShadow: isCompleted ? null : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.15),
                borderRadius: AppRadius.md,
              ),
              child: Center(child: Text(challenge['icon'] ?? '⚡', style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(challenge['title'] ?? '', style: AppTextStyles.h4),
                  const SizedBox(height: 3),
                  Text(challenge['description'] ?? '',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _Tag(label: categoryLabels[category] ?? category, color: catColor),
                        const SizedBox(width: 6),
                        _Tag(label: diffLabel, color: diffColor),
                        const SizedBox(width: 6),
                        _Tag(label: '${challenge['durationMinutes']} min', color: AppColors.onSurfaceMuted),
                      ],
                    ),
                  ),
                  if (challenge['reason'] != null) ...[
                    const SizedBox(height: 6),
                    Text('💡 ${challenge['reason']}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Action button
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.full,
                  ),
                  child: Text('+${challenge['points']} pts',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.secondary.withValues(alpha: 0.12)
                        : AppColors.primary,
                    borderRadius: AppRadius.md,
                    border: isCompleted
                        ? Border.all(color: AppColors.secondary, width: 1.5)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCompleted ? '✅ Fait' : 'Démarrer',
                        style: AppTextStyles.caption.copyWith(
                          color: isCompleted ? AppColors.secondary : Colors.white,
                          fontWeight: FontWeight.w800)),
                      if (!isCompleted) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 12, color: Colors.white),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.full,
      ),
      child: Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _DailyProgressBar extends StatelessWidget {
  final int completed;
  final int total;
  const _DailyProgressBar({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? completed / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progression du jour',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
              Text('$completed / $total défis',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: AppRadius.full,
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: Colors.white,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreathingSpotlight extends StatelessWidget {
  const _BreathingSpotlight();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF74B9FF).withValues(alpha: 0.1),
        borderRadius: AppRadius.lg,
        border: Border.all(color: const Color(0xFF74B9FF).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF74B9FF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🌬️', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exercice rapide', style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF74B9FF), fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Respiration 4-7-8', style: AppTextStyles.h4),
                Text('Réduit le stress en 3 minutes',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF74B9FF),
              borderRadius: AppRadius.md,
            ),
            child: Text('Démarrer', style: AppTextStyles.button.copyWith(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Text('😴', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('Aucun défi disponible', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text('Enregistre ton humeur pour obtenir des défis personnalisés',
                style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRefresh, child: const Text('Actualiser')),
          ],
        ),
      ),
    );
  }
}