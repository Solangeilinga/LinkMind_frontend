import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_provider.dart';
import '../../models/challenge.dart';
import '../../services/security.service.dart';
import '../../widgets/skeleton_widget.dart';

class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});
  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contentProvider.notifier).load();
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await ref.read(challengesProvider.notifier).loadDaily();
    if (mounted) {
      setState(() => _isRefreshing = false);
      SecurityService.recordActivity(type: 'refresh_challenges');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(moodProvider, (previous, next) {
      if (previous?.todayMood != next.todayMood && mounted) {
        _refreshData();
      }
    });

    final state = ref.watch(challengesProvider);
    final contentState = ref.watch(contentProvider);
    final moodState = ref.watch(moodProvider);

    final categoryMap = {for (final c in contentState.challengeCategories) c.id: c};
    final difficultyMap = {for (final d in contentState.challengeDifficulties) d.id: d};

    List<Challenge> challenges = [];
    try {
      if (state.daily.isNotEmpty) {
        challenges = state.daily.take(2).map((c) {
          final Map<String, dynamic> convertedMap =
              Map<String, dynamic>.from(c as Map<dynamic, dynamic>);
          return Challenge.fromJson(convertedMap);
        }).toList();
      }
    } catch (e) {
      debugPrint('Erreur conversion défis: $e');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Défis du jour'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isRefreshing || state.isLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: (_isRefreshing || state.isLoading) ? null : _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Défis du jour', style: AppTextStyles.h2),
                  SizedBox(height: 4),
                  Text('Complète tes défis pour gagner des points', style: AppTextStyles.body),
                ]),
              ),
            ),

            if (state.error != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    borderRadius: AppRadius.md,
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.error!,
                        style: AppTextStyles.caption.copyWith(color: Colors.red),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),

            if (!state.isLoading && challenges.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _DailyProgressBar(
                    completed: challenges.where((c) => c.isCompleted).length,
                    total: challenges.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Skeleton au lieu du spinner ──────────────────────────────
            if (state.isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(children: [
                    _SkeletonChallengeCard(),
                    const SizedBox(height: 12),
                    _SkeletonChallengeCard(),
                  ]),
                ),
              )
            else if (challenges.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyState(onRefresh: _refreshData, hasMood: moodState.todayMood != null),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Activités personnalisées', style: AppTextStyles.h3),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final challenge = challenges[i];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, i < challenges.length - 1 ? 12 : 0),
                      child: _ChallengeCard(
                        challenge: challenge,
                        category: categoryMap[challenge.category],
                        difficulty: difficultyMap[challenge.difficulty],
                        onTap: () async {
                          SecurityService.recordActivity(type: 'open_challenge',
                              metadata: {'challengeId': challenge.id});
                          if (context.mounted) {
                            await context.push('/challenges/${challenge.id}');
                            if (mounted) _refreshData();
                          }
                        },
                      ),
                    );
                  },
                  childCount: challenges.length,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton carte défi ───────────────────────────────────────────────────────
class _SkeletonChallengeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SkeletonBox(width: 52, height: 52, radius: 10),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SkeletonBox(height: 15, radius: 6),
          const SizedBox(height: 7),
          const SkeletonBox(width: 200, height: 13, radius: 5),
          const SizedBox(height: 5),
          const SkeletonBox(width: 160, height: 13, radius: 5),
          const SizedBox(height: 10),
          Row(children: const [
            SkeletonBox(width: 55, height: 20, radius: 10),
            SizedBox(width: 6),
            SkeletonBox(width: 65, height: 20, radius: 10),
            SizedBox(width: 6),
            SkeletonBox(width: 45, height: 20, radius: 10),
          ]),
        ])),
        const SizedBox(width: 10),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
          SkeletonBox(width: 55, height: 22, radius: 11),
          SizedBox(height: 8),
          SkeletonBox(width: 70, height: 34, radius: 8),
        ]),
      ]),
    );
  }
}

// ── Widgets existants inchangés ───────────────────────────────────────────────
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
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lg,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Progression du jour',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
          Text('$completed / $total défis',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
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
      ]),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final dynamic category;
  final dynamic difficulty;
  final VoidCallback onTap;

  const _ChallengeCard({required this.challenge, required this.category,
      required this.difficulty, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final catColor = category != null
        ? Color(int.parse(category.colorHex.substring(1), radix: 16) + 0xFF000000)
        : AppColors.primary;
    final diffColor = difficulty != null
        ? Color(int.parse(difficulty.colorHex.substring(1), radix: 16) + 0xFF000000)
        : const Color(0xFF6BCF7F);
    final isCompleted = challenge.isCompleted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.secondary.withValues(alpha: 0.05) : AppColors.surface,
          borderRadius: AppRadius.lg,
          border: Border.all(
              color: isCompleted ? AppColors.secondary : AppColors.divider, width: 1.5),
          boxShadow: isCompleted ? null : [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.15), borderRadius: AppRadius.md),
            child: Center(child: Text(challenge.icon, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(challenge.title, style: AppTextStyles.h4),
            const SizedBox(height: 3),
            Text(challenge.description,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _Tag(label: category?.label ?? challenge.category, color: catColor),
                const SizedBox(width: 6),
                _Tag(label: difficulty?.label ?? challenge.difficulty, color: diffColor),
                const SizedBox(width: 6),
                _Tag(label: '${challenge.durationMinutes} min', color: AppColors.onSurfaceMuted),
                if (challenge.completionType.type != 'action')
                  Padding(padding: const EdgeInsets.only(left: 6),
                    child: _Tag(label: _getTypeLabel(challenge.completionType.type),
                        color: AppColors.accentOrange)),
              ]),
            ),
          ])),
          const SizedBox(width: 10),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1), borderRadius: AppRadius.full),
              child: Text('+${challenge.points} pts',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.secondary.withValues(alpha: 0.12) : AppColors.primary,
                borderRadius: AppRadius.md,
                border: isCompleted ? Border.all(color: AppColors.secondary, width: 1.5) : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(isCompleted ? 'Terminé' : 'Démarrer',
                    style: AppTextStyles.caption.copyWith(
                        color: isCompleted ? AppColors.secondary : Colors.white,
                        fontWeight: FontWeight.w800)),
                if (!isCompleted) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                ],
              ]),
            ),
          ]),
        ]),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'timer': return 'Chrono';
      case 'reflection': return 'Réflexion';
      case 'social': return 'Social';
      case 'exploration': return 'Découverte';
      default: return 'Action';
    }
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
          color: color.withValues(alpha: 0.12), borderRadius: AppRadius.full),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool hasMood;
  const _EmptyState({required this.onRefresh, this.hasMood = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          const SizedBox(height: 16),
          Text(hasMood ? 'Aucun défi disponible' : 'Enregistre ton humeur',
              style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            hasMood
                ? 'Aucun défi n\'est disponible pour ton humeur actuelle.'
                : 'Enregistre ton humeur pour obtenir des défis personnalisés.',
            style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Actualiser'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          ),
          if (!hasMood) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/home'),
              icon: const Icon(Icons.mood, size: 18),
              label: const Text('Enregistrer mon humeur'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
          ],
        ]),
      ),
    );
  }
}