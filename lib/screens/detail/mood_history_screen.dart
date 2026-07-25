import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Journal des humeurs — lecture des entrées passées avec note, facteurs,
// score, et analyse de pattern sur les 30 derniers jours.
// ─────────────────────────────────────────────────────────────────────────────

class MoodHistoryScreen extends ConsumerStatefulWidget {
  const MoodHistoryScreen({super.key});
  @override
  ConsumerState<MoodHistoryScreen> createState() =>
      _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends ConsumerState<MoodHistoryScreen> {
  String? _filterFactor;

  @override
  void initState() {
    super.initState();
    // Charger 30 jours d'historique pour le journal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(moodProvider.notifier).loadExtendedHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(moodProvider).history;
    final content  = ref.watch(contentProvider);

    // Trie du plus récent au plus ancien
    final sorted = [...history]..sort((a, b) {
        final da = DateTime.tryParse(
                a['createdAt']?.toString() ?? '') ??
            DateTime(2000);
        final db = DateTime.tryParse(
                b['createdAt']?.toString() ?? '') ??
            DateTime(2000);
        return db.compareTo(da);
      });

    // Facteurs uniques présents dans l'historique
    final allFactors = <String>{};
    for (final e in sorted) {
      final f = e['factors'];
      if (f is List) {
        for (final x in f) allFactors.add(x.toString());
      }
    }

    // Filtre
    final filtered = _filterFactor == null
        ? sorted
        : sorted.where((e) {
            final f = e['factors'];
            return f is List && f.contains(_filterFactor);
          }).toList();

    // Pattern analyse (30 derniers jours)
    final pattern = _analyzePattern(sorted);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon journal'),
        centerTitle: true,
        leading: const BackButton(),
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),
      body: history.isEmpty
          ? _buildEmpty()
          : CustomScrollView(slivers: [
              // ── Carte de résumé / pattern ──────────────────────────────
              SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _PatternCard(pattern: pattern),
              )),

              // ── Filtre par facteur ─────────────────────────────────────
              if (allFactors.isNotEmpty)
                SliverToBoxAdapter(
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
                  child: _FactorFilter(
                    factors: allFactors.toList(),
                    active: _filterFactor,
                    onSelect: (f) =>
                        setState(() => _filterFactor = f),
                  ),
                )),

              // ── Compteur ──────────────────────────────────────────────
              SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  _filterFactor != null
                      ? '${filtered.length} entrée${filtered.length > 1 ? 's' : ''} avec "$_filterFactor"'
                      : '${sorted.length} entrée${sorted.length > 1 ? 's' : ''}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.onSurfaceMuted),
                ),
              )),

              // ── Liste des entrées ──────────────────────────────────────
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final entry = filtered[i];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20,
                          i < filtered.length - 1 ? 10 : 0),
                      child: _JournalEntry(
                        entry: entry,
                        content: content,
                        highlightFactor: _filterFactor,
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),

              const SliverToBoxAdapter(
                  child: SizedBox(height: 100)),
            ]),
    );
  }

  // ── Pattern sur les 30 derniers jours ─────────────────────────────────────
  _PatternData _analyzePattern(List<Map<String, dynamic>> sorted) {
    final now = DateTime.now();
    final recent = sorted.where((e) {
      final raw = e['createdAt']?.toString() ?? '';
      final dt = DateTime.tryParse(raw);
      return dt != null && now.difference(dt).inDays <= 29;
    }).toList();

    final logged = recent.length;
    if (logged == 0) {
      return _PatternData(logged: 0, avg: 0, topFactor: null, trend: 0);
    }

    final scores = recent
        .map((e) => (e['score'] as num?)?.toDouble() ?? 3.0)
        .toList();
    final avg = scores.reduce((a, b) => a + b) / scores.length;

    // Tendance (delta entre 1ère semaine et dernière semaine)
    double trend = 0;
    if (scores.length >= 4) {
      final mid = scores.length ~/ 2;
      final old = scores.sublist(mid).reduce((a, b) => a + b) /
          (scores.length - mid);
      final recent2 =
          scores.sublist(0, mid).reduce((a, b) => a + b) / mid;
      trend = recent2 - old;
    }

    // Facteur le plus fréquent
    final freq = <String, int>{};
    for (final e in recent) {
      final f = e['factors'];
      if (f is List) {
        for (final x in f) freq[x.toString()] = (freq[x.toString()] ?? 0) + 1;
      }
    }
    String? topFactor;
    if (freq.isNotEmpty) {
      topFactor =
          freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    return _PatternData(
        logged: logged, avg: avg, topFactor: topFactor, trend: trend);
  }

  Widget _buildEmpty() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📓', style: TextStyle(fontSize: 52)),
            SizedBox(height: 12),
            Text('Ton journal est vide',
                style: AppTextStyles.h3, textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text(
              'Enregistre ton humeur chaque jour\npour retrouver tes entrées ici.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ─── Data pattern ─────────────────────────────────────────────────────────────
class _PatternData {
  final int logged;
  final double avg;
  final String? topFactor;
  final double trend;
  const _PatternData(
      {required this.logged,
      required this.avg,
      required this.topFactor,
      required this.trend});
}

// ─── Carte de résumé pattern ──────────────────────────────────────────────────
class _PatternCard extends StatelessWidget {
  final _PatternData pattern;
  const _PatternCard({required this.pattern});

  @override
  Widget build(BuildContext context) {
    if (pattern.logged == 0) return const SizedBox.shrink();

    final trendIcon = pattern.trend >= 0.5
        ? '📈'
        : pattern.trend <= -0.5
            ? '📉'
            : '➡️';
    final trendText = pattern.trend >= 0.5
        ? 'En hausse'
        : pattern.trend <= -0.5
            ? 'En baisse'
            : 'Stable';
    final trendColor = pattern.trend >= 0.5
        ? const Color(0xFF6BCF7F)
        : pattern.trend <= -0.5
            ? const Color(0xFFFF7675)
            : AppColors.onSurfaceMuted;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.lg,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ces 30 derniers jours',
            style: AppTextStyles.caption
                .copyWith(color: Colors.white70)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _StatChip(
              label: 'Jours enregistrés',
              value: '${pattern.logged}',
              icon: '📅',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              label: 'Moyenne',
              value: pattern.avg.toStringAsFixed(1),
              icon: '⭐',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              label: 'Tendance',
              value: trendText,
              icon: trendIcon,
              valueColor: trendColor,
            ),
          ),
        ]),
        if (pattern.topFactor != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: AppRadius.md),
            child: Row(children: [
              const Text('🔁', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '"${pattern.topFactor}" revient le plus souvent dans tes entrées.',
                  style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value, icon;
  final Color? valueColor;
  const _StatChip(
      {required this.label,
      required this.value,
      required this.icon,
      this.valueColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: AppRadius.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(value,
              style: AppTextStyles.body.copyWith(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: Colors.white60, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

// ─── Filtre facteur ───────────────────────────────────────────────────────────
class _FactorFilter extends StatelessWidget {
  final List<String> factors;
  final String? active;
  final Function(String?) onSelect;
  const _FactorFilter(
      {required this.factors,
      required this.active,
      required this.onSelect});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 20),
        child: Row(children: [
          // "Tous" chip
          GestureDetector(
            onTap: () => onSelect(null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active == null
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: AppRadius.full,
                border: Border.all(
                    color: active == null
                        ? AppColors.primary
                        : AppColors.divider),
              ),
              child: Text('Tous',
                  style: AppTextStyles.caption.copyWith(
                      color: active == null
                          ? Colors.white
                          : AppColors.onSurface,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          ...factors.map((f) => GestureDetector(
                onTap: () => onSelect(active == f ? null : f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active == f
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius: AppRadius.full,
                    border: Border.all(
                        color: active == f
                            ? AppColors.primary
                            : AppColors.divider),
                  ),
                  child: Text(f,
                      style: AppTextStyles.caption.copyWith(
                          color: active == f
                              ? Colors.white
                              : AppColors.onSurface,
                          fontWeight: FontWeight.w700)),
                ),
              )),
        ]),
      );
}

// ─── Entrée journal ───────────────────────────────────────────────────────────
class _JournalEntry extends StatelessWidget {
  final Map<String, dynamic> entry;
  final ContentState content;
  final String? highlightFactor;

  const _JournalEntry({
    required this.entry,
    required this.content,
    this.highlightFactor,
  });

  @override
  Widget build(BuildContext context) {
    final score = (entry['score'] as num?)?.toInt() ?? 3;
    final label = entry['label'] as String? ?? 'neutral';
    final note = entry['note'] as String?;
    final factors = entry['factors'];
    final factorList = factors is List
        ? factors.map((f) => f.toString()).toList()
        : <String>[];
    final stressLevel = entry['stressLevel'] as int?;
    final date = DateTime.tryParse(
        entry['createdAt']?.toString() ?? '');

    // Trouve la définition de l'humeur
    final moodDef = content.loaded && content.moodDefinitions.isNotEmpty
        ? content.moodDefinitions.firstWhere(
            (m) => m.id == label,
            orElse: () => content.moodDefinitions.first)
        : null;

    final moodColor = moodDef?.color ?? AppColors.primary;
    final moodEmoji = moodDef?.emoji ?? '😐';
    final moodLabel = moodDef?.label ?? label;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: moodColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header : emoji + label + date ─────────────────────────────
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: moodColor.withValues(alpha: 0.15),
                borderRadius: AppRadius.md),
            child: Center(
                child: Text(moodEmoji,
                    style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(moodLabel,
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w800)),
              Text(_formatDate(date),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.onSurfaceMuted)),
            ]),
          ),
          // Score visuel (5 points)
          Row(
            children: List.generate(
                5,
                (s) => Icon(
                      s < score ? Icons.circle : Icons.circle_outlined,
                      size: 8,
                      color: s < score ? moodColor : AppColors.divider,
                    )),
          ),
        ]),

        // ── Note ──────────────────────────────────────────────────────
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.md),
            child: Text('"$note"',
                style: AppTextStyles.bodySmall.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.onSurface,
                    height: 1.4)),
          ),
        ],

        // ── Facteurs ──────────────────────────────────────────────────
        if (factorList.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 4,
            children: factorList.map((f) {
              final isHighlighted =
                  highlightFactor != null && f == highlightFactor;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: isHighlighted
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : moodColor.withValues(alpha: 0.08),
                    borderRadius: AppRadius.full,
                    border: Border.all(
                        color: isHighlighted
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : moodColor.withValues(alpha: 0.2))),
                child: Text(f,
                    style: AppTextStyles.caption.copyWith(
                        color: isHighlighted
                            ? AppColors.primary
                            : moodColor,
                        fontWeight: FontWeight.w700)),
              );
            }).toList(),
          ),
        ],

        // ── Niveau de stress ──────────────────────────────────────────
        if (stressLevel != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Text('Stress :',
                style: AppTextStyles.caption),
            const SizedBox(width: 6),
            ...List.generate(
                5,
                (i) => Container(
                      width: 16, height: 6,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                          color: i < stressLevel
                              ? _stressColor(stressLevel)
                              : AppColors.divider,
                          borderRadius: BorderRadius.circular(3)),
                    )),
            const SizedBox(width: 6),
            Text(_stressLabel(stressLevel),
                style: AppTextStyles.caption.copyWith(
                    color: _stressColor(stressLevel),
                    fontWeight: FontWeight.w700)),
          ]),
        ],
      ]),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Hier';
    if (diff < 7) return 'Il y a $diff jours';
    final months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Color _stressColor(int level) {
    const colors = [
      Color(0xFF6BCF7F), Color(0xFFFFD93D), Color(0xFFFFB347),
      Color(0xFFFF7675), Color(0xFFE84393),
    ];
    return colors[(level - 1).clamp(0, 4)];
  }

  String _stressLabel(int level) {
    const labels = ['Très bas', 'Bas', 'Modéré', 'Élevé', 'Très élevé'];
    return labels[(level - 1).clamp(0, 4)];
  }
}