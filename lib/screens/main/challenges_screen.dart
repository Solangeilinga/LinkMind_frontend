import 'package:flutter/material.dart';
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

class _ChallengesScreenState extends ConsumerState<ChallengesScreen>
    with TickerProviderStateMixin {
  bool _isRefreshing = false;

  // Animation de complétion (confetti léger)
  late AnimationController _completionController;
  late Animation<double> _completionAnim;
  bool _showCompletion = false;
  String? _lastCompletedTitle;

  @override
  void initState() {
    super.initState();
    _completionController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _completionAnim = CurvedAnimation(
        parent: _completionController, curve: Curves.elasticOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contentProvider.notifier).load();
      _refreshData();
    });
  }

  @override
  void dispose() {
    _completionController.dispose();
    super.dispose();
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

  // Appelé par ChallengeDetailScreen via pop — rafraîchit et anime si complété
  void _onChallengeReturned(String? completedTitle) {
    if (completedTitle != null) {
      setState(() {
        _lastCompletedTitle = completedTitle;
        _showCompletion = true;
      });
      _completionController.forward(from: 0);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showCompletion = false);
      });
    }
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(moodProvider, (previous, next) {
      if (previous?.todayMood != next.todayMood && mounted) _refreshData();
    });

    final state       = ref.watch(challengesProvider);
    final contentState = ref.watch(contentProvider);
    final moodState   = ref.watch(moodProvider);
    final user        = ref.watch(authProvider).user;

    final categoryMap   = {for (final c in contentState.challengeCategories) c.id: c};
    final difficultyMap = {for (final d in contentState.challengeDifficulties) d.id: d};

    // Humeur du jour (pour l'explication de personnalisation)
    final todayMoodLabel = moodState.todayMood?['label'] as String?;
    final todayMoodEmoji = _moodEmoji(todayMoodLabel);

    List<Challenge> challenges = [];
    try {
      if (state.daily.isNotEmpty) {
        challenges = state.daily.take(2).map((c) {
          final Map<String, dynamic> m =
              Map<String, dynamic>.from(c as Map<dynamic, dynamic>);
          return Challenge.fromJson(m);
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
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: (_isRefreshing || state.isLoading) ? null : _refreshData,
          ),
        ],
      ),
      body: Stack(children: [
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refreshData,
          child: CustomScrollView(slivers: [

            // ── Header ──────────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Défis du jour', style: AppTextStyles.h2),
                  SizedBox(height: 4),
                  Text('Des activités choisies pour toi', style: AppTextStyles.body),
                ]),
              ),
            ),

            // ── Erreur ──────────────────────────────────────────────────────
            if (state.error != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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

            // ── Barre de progression ─────────────────────────────────────────
            if (!state.isLoading && challenges.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _DailyProgressBar(
                    completed: challenges.where((c) => c.isCompleted).length,
                    total: challenges.length,
                    streakDays: user?.streakDays ?? 0,
                  ),
                ),
              ),

            // ── Explication de personnalisation ──────────────────────────────
            if (!state.isLoading && challenges.isNotEmpty && todayMoodLabel != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _PersonalisationBanner(
                    moodLabel: todayMoodLabel,
                    moodEmoji: todayMoodEmoji,
                    challenges: challenges,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Skeleton ou liste ────────────────────────────────────────────
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
                child: _EmptyState(
                  onRefresh: _refreshData,
                  hasMood: moodState.todayMood != null,
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Activités personnalisées',
                      style: AppTextStyles.h3),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final challenge = challenges[i];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20,
                          i < challenges.length - 1 ? 12 : 0),
                      child: _ChallengeCard(
                        challenge: challenge,
                        category: categoryMap[challenge.category],
                        difficulty: difficultyMap[challenge.difficulty],
                        onTap: () async {
                          SecurityService.recordActivity(
                              type: 'open_challenge',
                              metadata: {'challengeId': challenge.id});
                          if (context.mounted) {
                            final result = await context
                                .push('/challenges/${challenge.id}');
                            if (mounted) {
                              _onChallengeReturned(
                                  result is String ? result : null);
                            }
                          }
                        },
                      ),
                    );
                  },
                  childCount: challenges.length,
                ),
              ),
            ],

            // ── Défi de la semaine ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _WeeklyChallengeBanner(streak: user?.streakDays ?? 0),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ]),
        ),

        // ── Overlay de complétion ─────────────────────────────────────────────
        if (_showCompletion)
          Positioned(
            bottom: 100,
            left: 20, right: 20,
            child: ScaleTransition(
              scale: _completionAnim,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: AppRadius.lg,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(children: [
                  const Text('🎉', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Bien joué !',
                          style: AppTextStyles.body.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      if (_lastCompletedTitle != null)
                        Text('"$_lastCompletedTitle" accompli.',
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.white70)),
                    ]),
                  ),
                  const Icon(Icons.check_circle,
                      color: Colors.white, size: 22),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  String _moodEmoji(String? moodId) {
    const map = {
      'happy': '😄', 'calm': '😌', 'excited': '🤩', 'content': '🙂',
      'neutral': '😐', 'sad': '😔', 'anxious': '😰', 'angry': '😠',
      'stressed': '😤', 'tired': '😴',
    };
    return map[moodId] ?? '😐';
  }
}

// ─── Bannière de personnalisation ────────────────────────────────────────────
class _PersonalisationBanner extends StatelessWidget {
  final String moodLabel;
  final String moodEmoji;
  final List<Challenge> challenges;

  const _PersonalisationBanner({
    required this.moodLabel,
    required this.moodEmoji,
    required this.challenges,
  });

  String _moodName(String id) {
    const names = {
      'happy': 'heureux/heureuse', 'calm': 'calme', 'excited': 'enthousiaste',
      'content': 'bien dans ta peau', 'neutral': 'neutre', 'sad': 'triste',
      'anxious': 'anxieux/anxieuse', 'angry': 'irrité(e)',
      'stressed': 'stressé(e)', 'tired': 'fatigué(e)',
    };
    return names[id] ?? id;
  }

  String _categoryExplanation(List<Challenge> cs) {
    if (cs.isEmpty) return '';
    final cats = cs.map((c) => c.category).toSet().toList();
    if (cats.length == 1) return 'catégorie : ${cats[0]}';
    return 'catégories : ${cats.join(' & ')}';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: AppRadius.md,
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(moodEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurface, height: 1.5),
                children: [
                  const TextSpan(text: 'Ces défis ont été choisis parce que tu te sens '),
                  TextSpan(
                    text: _moodName(moodLabel),
                    style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                  ),
                  TextSpan(
                      text:
                          ' — ${_categoryExplanation(challenges)} adaptée à ton état du moment.'),
                ],
              ),
            ),
          ),
        ]),
      );
}

// ─── Défi de la semaine ──────────────────────────────────────────────────────
class _WeeklyChallengeBanner extends StatelessWidget {
  final int streak;
  const _WeeklyChallengeBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    final daysLeft = 7 - (DateTime.now().weekday % 7);
    final progress = (7 - daysLeft) / 7;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.12),
                borderRadius: AppRadius.md),
            child: const Text('🗓️', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Défi de la semaine',
                  style: AppTextStyles.h4),
              Text('Cette semaine : une entrée d\'humeur chaque jour',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.onSurfaceMuted)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(progress * 7).floor()} / 7 jours',
              style: AppTextStyles.caption
                  .copyWith(fontWeight: FontWeight.w800)),
          Text('$daysLeft jour${daysLeft > 1 ? 's' : ''} restant${daysLeft > 1 ? 's' : ''}',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.onSurfaceMuted)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: AppRadius.full,
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.divider,
            color: progress >= 1.0
                ? AppColors.secondary
                : AppColors.accentOrange,
            minHeight: 8,
          ),
        ),
        if (progress >= 1.0) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: AppRadius.md,
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3))),
            child: const Text('✅ Défi de la semaine accompli !',
                style: AppTextStyles.body,
                textAlign: TextAlign.center),
          ),
        ],
        if (streak >= 7) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text('$streak jours de streak — continue !',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.accentOrange,
                    fontWeight: FontWeight.w700)),
          ]),
        ],
      ]),
    );
  }
}

// ─── Skeleton carte défi ──────────────────────────────────────────────────────
class _SkeletonChallengeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          borderRadius: AppRadius.lg,
          border:
              Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SkeletonBox(width: 52, height: 52, radius: 10),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            const SkeletonBox(height: 15, radius: 6),
            const SizedBox(height: 7),
            const SkeletonBox(width: 200, height: 13, radius: 5),
            const SizedBox(height: 5),
            const SkeletonBox(width: 160, height: 13, radius: 5),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(children: const [
                SkeletonBox(width: 55, height: 20, radius: 10),
                SizedBox(width: 6),
                SkeletonBox(width: 65, height: 20, radius: 10),
                SizedBox(width: 6),
                SkeletonBox(width: 45, height: 20, radius: 10),
              ]),
            ),
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

// ─── Progress bar journalière ─────────────────────────────────────────────────
class _DailyProgressBar extends StatelessWidget {
  final int completed, total, streakDays;
  const _DailyProgressBar(
      {required this.completed,
      required this.total,
      required this.streakDays});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? completed / total : 0.0;
    final allDone = completed == total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lg,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Progression du jour',
              style: AppTextStyles.bodySmall
                  .copyWith(color: Colors.white70)),
          Text(
            allDone ? '🎉 Tous complétés !' : '$completed / $total défis',
            style: AppTextStyles.bodySmall
                .copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: AppRadius.full,
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            color: allDone ? const Color(0xFF6BCF7F) : Colors.white,
            minHeight: 8,
          ),
        ),
        if (streakDays > 0) ...[
          const SizedBox(height: 8),
          Text('🔥 $streakDays jours de suite',
              style: AppTextStyles.caption
                  .copyWith(color: Colors.white60)),
        ],
      ]),
    );
  }
}

// ─── Challenge card ───────────────────────────────────────────────────────────
class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final dynamic category;
  final dynamic difficulty;
  final VoidCallback onTap;

  const _ChallengeCard(
      {required this.challenge,
      required this.category,
      required this.difficulty,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final catColor = category != null
        ? Color(int.parse(category.colorHex.substring(1), radix: 16) +
            0xFF000000)
        : AppColors.primary;
    final diffColor = difficulty != null
        ? Color(int.parse(difficulty.colorHex.substring(1), radix: 16) +
            0xFF000000)
        : const Color(0xFF6BCF7F);
    final isCompleted = challenge.isCompleted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted
              ? AppColors.secondary.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: AppRadius.lg,
          border: Border.all(
              color: isCompleted ? AppColors.secondary : AppColors.divider,
              width: 1.5),
          boxShadow: isCompleted
              ? null
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 3))
                ],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.15),
                borderRadius: AppRadius.md),
            child: Center(
                child: Text(challenge.icon,
                    style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text(challenge.title, style: AppTextStyles.h4),
            const SizedBox(height: 3),
            Text(challenge.description,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.onSurfaceMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
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
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _Tag(
                        label: _getTypeLabel(challenge.completionType.type),
                        color: AppColors.accentOrange),
                  ),
              ]),
            ),
          ])),
          const SizedBox(width: 10),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.full),
              child: Text('+${challenge.points} pts',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.secondary.withValues(alpha: 0.12)
                    : AppColors.primary,
                borderRadius: AppRadius.md,
                border: isCompleted
                    ? Border.all(
                        color: AppColors.secondary, width: 1.5)
                    : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  isCompleted ? 'Terminé' : 'Démarrer',
                  style: AppTextStyles.caption.copyWith(
                      color: isCompleted
                          ? AppColors.secondary
                          : Colors.white,
                      fontWeight: FontWeight.w800),
                ),
                if (!isCompleted) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 12, color: Colors.white),
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppRadius.full),
        child: Text(label,
            style: AppTextStyles.caption.copyWith(
                color: color, fontWeight: FontWeight.w700)),
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool hasMood;
  const _EmptyState({required this.onRefresh, this.hasMood = false});

  @override
  Widget build(BuildContext context) => Center(
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
              style: AppTextStyles.body
                  .copyWith(color: AppColors.onSurfaceMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualiser'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12)),
            ),
            if (!hasMood) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/home'),
                icon: const Icon(Icons.mood, size: 18),
                label: const Text('Enregistrer mon humeur'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12)),
              ),
            ],
          ]),
        ),
      );
}