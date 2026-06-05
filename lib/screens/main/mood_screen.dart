import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../utils/icon_mapper.dart';
import '../../widgets/ad_banner.dart';
import '../../providers/auth_provider.dart';
import '../../services/api.service.dart';
import '../../providers/content_provider.dart';

class _WellnessTip {
  final String icon, title, desc;
  final String? route;
  const _WellnessTip(this.icon, this.title, this.desc, this.route);
}

class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});
  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> with SingleTickerProviderStateMixin {
  int? _selectedMoodIndex;
  bool _moodLogged  = false;
  bool _isLogging   = false;
  String? _note;
  int _stressLevel  = 3;
  final List<String> _selectedFactors = [];
  final _noteController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  String _todayMessage = 'Chaque jour est une nouvelle chance de prendre soin de toi. 🌱';
  Map<String, List<_WellnessTip>> _wellnessTips = {};

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _loadContent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final moodState = ref.read(moodProvider);
      if (moodState.todayMood != null) setState(() => _moodLogged = true);
    });
  }

  Future<void> _loadContent() async {
    try {
      final results = await Future.wait([
        ApiService().getDailyMessage(),
        ApiService().getWellnessTips(),
      ]);
      if (mounted) {
        setState(() {
          final msg = results[0]['message'];
          if (msg != null) _todayMessage = '${msg['text'] ?? ''} ${msg['emoji'] ?? ''}';
          // ✅ Conversion correcte de Map<dynamic, dynamic> -> Map<String, dynamic>
          final grouped = _castMap<String, dynamic>(results[1]['tips'] ?? {});
          _wellnessTips = grouped.map((mood, tips) {
            final tipsList = (tips as List?)?.map((t) {
              final tip = _castMap<String, dynamic>(t);
              return _WellnessTip(
                tip['emoji'] ?? '💡',
                tip['title'] ?? '',
                tip['description'] ?? '',
                tip['actionPath'] as String?
              );
            }).toList() ?? [];
            return MapEntry(mood, tipsList);
          });
        });
      }
    } catch (e) {
      debugPrint('⚠️ _loadContent error: $e');
    }
  }

  // ✅ Fonction utilitaire pour convertir Map<dynamic, dynamic> en Map<String, T>
  static Map<String, T> _castMap<K, T>(dynamic data) {
    if (data is Map<K, T>) return data as Map<String, T>;
    if (data is Map) {
      return Map<String, T>.from(
        data.map((k, v) => MapEntry(k.toString(), v as T))
      );
    }
    return {};
  }

  @override
  void dispose() { 
    _fadeController.dispose(); 
    _noteController.dispose(); 
    super.dispose(); 
  }

  Future<void> _logMood() async {
    if (_selectedMoodIndex == null) return;
    setState(() => _isLogging = true);
    final moods = ref.read(contentProvider).moodDefinitions;
    final mood  = moods[_selectedMoodIndex!];
    final result = await ref.read(moodProvider.notifier).logMood(
      score: mood.score, label: mood.id, note: _note, factors: _selectedFactors);
    setState(() { _isLogging = false; _moodLogged = result != null; });
    if (result != null && mounted) {
      ref.read(authProvider.notifier).loadDailyChallenges(moodLabel: mood.id);
      _showWellnessSheet(mood.id);
    }
  }

  void _showWellnessSheet(String moodId) {
    final tips = _wellnessTips[moodId] ?? _wellnessTips['neutral'] ?? [];
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _WellnessSheet(moodId: moodId, tips: tips));
  }

  List<_WellnessTip> get _currentTips {
    final moods = ref.read(contentProvider).moodDefinitions;
    if (_selectedMoodIndex == null) return _wellnessTips['neutral'] ?? [];
    return _wellnessTips[moods[_selectedMoodIndex!].id] ?? _wellnessTips['neutral'] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final content  = ref.watch(contentProvider);
    final moods    = content.moodDefinitions;
    final moodState = ref.watch(moodProvider);
    final user     = ref.watch(authProvider).user;
    final hour     = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';

    // Stress factors from DB with fallback
    final stressFactors = content.loaded && content.stressFactors.isNotEmpty
        ? content.stressFactors
        : <StressFactorDef>[];

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.read(moodProvider.notifier).reset();
              await _loadContent();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(), 
              slivers: [
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$greeting ${user?.name.split(' ').first ?? ''} 👋',
                          style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted)),
                      const Text('Comment te sens-tu ?', style: AppTextStyles.h2),
                    ])),
                    Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _PointsBadge(points: user?.totalPoints ?? 0),
                      if ((user?.streakDays ?? 0) > 0) ...[
                        const SizedBox(height: 4),
                        _StreakBadge(days: user!.streakDays),
                      ],
                    ])),
                  ]),
                )),

                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _DailyMessageCard(message: _todayMessage),
                )),

                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _MoodCard(
                    moods: moods,
                    selectedIndex: _selectedMoodIndex,
                    moodLogged: _moodLogged,
                    isLogging: _isLogging,
                    todayMood: moodState.todayMood,
                    onMoodSelected: (i) => setState(() { _selectedMoodIndex = i; _moodLogged = false; }),
                    onLog: _logMood,
                  ),
                )),

                if (_selectedMoodIndex != null && !_moodLogged) ...[
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _StressLevelSlider(
                      value: _stressLevel,
                      onChanged: (v) => setState(() => _stressLevel = v)),
                  )),
                  if (stressFactors.isNotEmpty)
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: _FactorSelector(
                        factors: stressFactors,
                        selected: _selectedFactors,
                        onToggle: (f) => setState(() =>
                          _selectedFactors.contains(f) ? _selectedFactors.remove(f) : _selectedFactors.add(f)),
                      ),
                    )),
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: TextField(
                      controller: _noteController, maxLines: 2, maxLength: 280,
                      decoration: const InputDecoration(
                        hintText: 'Ajoute une note libre... (optionnel)',
                        counterStyle: TextStyle(fontSize: 11)),
                      onChanged: (v) => _note = v.isEmpty ? null : v,
                      style: AppTextStyles.body,
                    ),
                  )),
                ],

                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _WeeklyMoodChart(history: moodState.history, stats: moodState.stats),
                )),

                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _WellnessTipsSection(
                    tips: _selectedMoodIndex != null && !_moodLogged
                        ? _currentTips
                        : (_wellnessTips[moodState.todayMood?['label']] ?? _wellnessTips['neutral'] ?? []),
                    moodId: _selectedMoodIndex != null
                        ? moods[_selectedMoodIndex!].id
                        : (moodState.todayMood?['label'] ?? 'neutral'),
                    moodColor: _selectedMoodIndex != null ? moods[_selectedMoodIndex!].color : AppColors.primary,
                  ),
                )),

                const SliverToBoxAdapter(child: AdBanner(placement: 'mood_screen')),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ]
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Daily Message Card ───────────────────────────────────────────────────────
class _DailyMessageCard extends StatelessWidget {
  final String message;
  const _DailyMessageCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.lg),
    child: Row(children: [
      IconMapper.getIcon('💬', size: 22, color: Colors.white),
      const SizedBox(width: 12),
      Expanded(child: Text(message, style: AppTextStyles.body.copyWith(
          color: Colors.white, fontWeight: FontWeight.w700, height: 1.4))),
    ]),
  );
}

// ─── Stress Level Slider ──────────────────────────────────────────────────────
class _StressLevelSlider extends StatelessWidget {
  final int value;
  final Function(int) onChanged;
  const _StressLevelSlider({required this.value, required this.onChanged});

  static const _labels = ['Très bas', 'Bas', 'Modéré', 'Élevé', 'Très élevé'];
  static const _colors = [
    Color(0xFF6BCF7F), Color(0xFFFFD93D), Color(0xFFFFB347),
    Color(0xFFFF7675), Color(0xFFE84393),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: AppRadius.lg,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Niveau de stress', style: AppTextStyles.h4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _colors[value - 1].withValues(alpha: 0.15), borderRadius: AppRadius.full),
          child: Text(_labels[value - 1], style: AppTextStyles.caption.copyWith(
              color: _colors[value - 1], fontWeight: FontWeight.w800))),
      ]),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: _colors[value - 1],
          inactiveTrackColor: _colors[value - 1].withValues(alpha: 0.2),
          thumbColor: _colors[value - 1],
          overlayColor: _colors[value - 1].withValues(alpha: 0.1),
          trackHeight: 6),
        child: Slider(
          value: value.toDouble(), min: 1, max: 5, divisions: 4,
          onChanged: (v) => onChanged(v.round())),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('😌 Calme', style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
        Text('😰 Très stressé', style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
      ]),
    ]),
  );
}

// ─── Factor Selector (depuis DB) ─────────────────────────────────────────────
class _FactorSelector extends StatelessWidget {
  final List<StressFactorDef> factors;
  final List<String> selected;
  final Function(String) onToggle;
  const _FactorSelector({required this.factors, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text("Qu'est-ce qui impacte ton humeur ?", style: AppTextStyles.h4),
    const SizedBox(height: 4),
    Text("Sélectionne tout ce qui s'applique",
        style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
    const SizedBox(height: 10),
    Wrap(spacing: 8, runSpacing: 8, children: factors.map((f) {
      final isSel = selected.contains(f.id);
      return GestureDetector(
        onTap: () => onToggle(f.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary : AppColors.surface,
            borderRadius: AppRadius.full,
            border: Border.all(color: isSel ? AppColors.primary : AppColors.divider, width: 1.5),
            boxShadow: isSel ? [BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8)] : null),
          child: Text('${f.emoji} ${f.label}', style: AppTextStyles.bodySmall.copyWith(
              color: isSel ? Colors.white : AppColors.onSurface, fontWeight: FontWeight.w700)),
        ),
      );
    }).toList()),
  ]);
}

// ─── Mood Card ────────────────────────────────────────────────────────────────
class _MoodCard extends StatelessWidget {
  final List<MoodDefinition> moods;
  final int? selectedIndex;
  final bool moodLogged, isLogging;
  final Map<String, dynamic>? todayMood;
  final Function(int) onMoodSelected;
  final VoidCallback onLog;
  const _MoodCard({required this.moods, required this.selectedIndex,
      required this.moodLogged, required this.isLogging, required this.todayMood,
      required this.onMoodSelected, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final count = moods.length;
    final firstRow = count >= 4 ? 4 : count;
    final secondRow = count > 4 ? count - 4 : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: selectedIndex != null
            ? moods[selectedIndex!].color.withValues(alpha: 0.06) : AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: selectedIndex != null
              ? moods[selectedIndex!].color.withValues(alpha: 0.25) : AppColors.divider, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (int i = 0; i < firstRow; i++)
            _MoodEmoji(mood: moods[i], isSelected: selectedIndex == i, onTap: () => onMoodSelected(i)),
        ]),
        if (secondRow > 0) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (int i = 0; i < secondRow; i++)
              _MoodEmoji(mood: moods[i + 4], isSelected: selectedIndex == (i + 4), onTap: () => onMoodSelected(i + 4)),
          ]),
        ],
        const SizedBox(height: 16),
        if (moodLogged)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4), width: 1.5)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('✅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('Humeur enregistrée !', style: AppTextStyles.body.copyWith(
                    color: AppColors.secondary, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 4),
              Text('Continue chaque jour pour suivre ton évolution',
                  style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
            ]))
        else
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: selectedIndex != null && !isLogging ? onLog : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedIndex != null ? moods[selectedIndex!].color : AppColors.divider,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.divider),
              child: isLogging
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      selectedIndex != null
                          ? 'Je me sens ${moods[selectedIndex!].label.toLowerCase()} — Enregistrer'
                          : 'Sélectionne comment tu te sens',
                      style: AppTextStyles.button.copyWith(fontSize: 13,
                          color: selectedIndex != null ? Colors.white : AppColors.onSurfaceMuted)),
            )),
      ]),
    );
  }
}

// ─── Mood Emoji ───────────────────────────────────────────────────────────────
class _MoodEmoji extends StatelessWidget {
  final MoodDefinition mood;
  final bool isSelected;
  final VoidCallback onTap;
  const _MoodEmoji({required this.mood, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 60, height: 68,
      decoration: BoxDecoration(
        color: isSelected ? mood.color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? Border.all(color: mood.color.withValues(alpha: 0.5), width: 1.5) : null),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedScale(
          scale: isSelected ? 1.3 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.elasticOut,
          child: IconMapper.getIcon(mood.emoji, size: 28, color: mood.color)),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontSize: isSelected ? 9 : 8,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
            color: isSelected ? mood.color : AppColors.onSurfaceMuted,
            fontFamily: AppTextStyles.fontFamily),
          child: Text(mood.label.split(' ').first, textAlign: TextAlign.center)),
      ]),
    ),
  );
}

// ─── Weekly Chart (CORRIGÉ : plus d'overflow) ─────────────────────────────────
class _WeeklyMoodChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final Map<String, dynamic>? stats;
  const _WeeklyMoodChart({required this.history, this.stats});

  Map<String, double> _buildDayMap() {
    final map = <String, double>{};
    for (final e in history) {
      final raw = e['createdAt']?.toString() ?? e['date']?.toString() ?? '';
      final dt  = DateTime.tryParse(raw);
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
      map[key] = (e['score'] as num?)?.toDouble() ?? 0;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final dayMap = _buildDayMap();
    final today  = DateTime.now();
    const dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    const maxBarHeight = 58.0;

    final days7 = List.generate(7, (i) {
      final d   = today.subtract(Duration(days: 6 - i));
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      return (score: dayMap[key] ?? 0.0, label: dayLabels[d.weekday - 1], isToday: i == 6, date: d);
    });

    String scoreEmoji(double s) {
      if (s == 0) return '';
      if (s <= 1.5) return '😔'; 
      if (s <= 2.5) return '😕';
      if (s <= 3.5) return '😐'; 
      if (s <= 4.5) return '😊'; 
      return '😄';
    }

    Color scoreColor(double s) {
      if (s == 0) return AppColors.surfaceVariant;
      if (s <= 1.5) return const Color(0xFFFF7675);
      if (s <= 2.5) return const Color(0xFFFFB347);
      if (s <= 3.5) return const Color(0xFFFFD93D);
      if (s <= 4.5) return const Color(0xFF6BCF7F);
      return const Color(0xFF2ECC71);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface, 
        borderRadius: AppRadius.lg,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ton évolution', style: AppTextStyles.h4),
          const SizedBox(height: 16),
          // Utilisation d'IntrinsicHeight pour éviter l'overflow
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days7.map((d) {
                final s = d.score;
                final barHeight = s == 0 ? 8.0 : (s / 5.0) * maxBarHeight;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (s > 0) Text(scoreEmoji(s), style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      width: 24, 
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: scoreColor(s),
                        borderRadius: BorderRadius.circular(6)
                      )
                    ),
                    const SizedBox(height: 8),
                    Text(d.label, style: AppTextStyles.caption.copyWith(
                      color: d.isToday ? AppColors.primary : AppColors.onSurfaceMuted,
                      fontWeight: d.isToday ? FontWeight.w800 : FontWeight.w600
                    ))
                  ]
                );
              }).toList(),
            )
          )
        ]
      )
    );
  }
}

// ─── Wellness Tips Section ────────────────────────────────────────────────────
class _WellnessTipsSection extends StatelessWidget {
  final List<_WellnessTip> tips;
  final String moodId;
  final Color moodColor;
  
  const _WellnessTipsSection({
    required this.tips, 
    required this.moodId, 
    required this.moodColor
  });

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recommandé pour toi', style: AppTextStyles.h4),
        const SizedBox(height: 12),
        ...tips.map((t) => GestureDetector(
          onTap: t.route != null ? () => context.push(t.route!) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: moodColor.withValues(alpha: 0.08),
              borderRadius: AppRadius.md,
              border: Border.all(color: moodColor.withValues(alpha: 0.2))
            ),
            child: Row(
              children: [
                Text(t.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(t.desc, style: AppTextStyles.caption.copyWith(
                        color: AppColors.onSurfaceMuted, height: 1.3))
                    ]
                  )
                ),
                if (t.route != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: moodColor, size: 20)
                ]
              ]
            ),
          ),
        ))
      ]
    );
  }
}

// ─── Wellness Sheet (Bottom Sheet) ────────────────────────────────────────────
class _WellnessSheet extends StatelessWidget {
  final String moodId;
  final List<_WellnessTip> tips;
  
  const _WellnessSheet({required this.moodId, required this.tips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.divider, 
                  borderRadius: AppRadius.full
                )
              )
            ),
            const SizedBox(height: 20),
            const Text('Prends un moment pour toi', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            ...tips.map((t) => ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10)
                ),
                child: Center(child: Text(t.icon, style: const TextStyle(fontSize: 20)))
              ),
              title: Text(t.title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w800)),
              subtitle: Text(t.desc, style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              trailing: t.route != null ? const Icon(Icons.chevron_right, size: 20) : null,
              onTap: () {
                Navigator.pop(context);
                if (t.route != null) context.push(t.route!);
              }
            )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('Compris')
              )
            )
          ]
        )
      )
    );
  }
}

// ─── Badges ───────────────────────────────────────────────────────────────────
class _PointsBadge extends StatelessWidget {
  final int points;
  const _PointsBadge({required this.points});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: const BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.full),
    child: Text('⚡ $points pts',
        style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w800)));
}

class _StreakBadge extends StatelessWidget {
  final int days;
  const _StreakBadge({required this.days});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.accentOrange.withValues(alpha: 0.12), borderRadius: AppRadius.full,
      border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3))),
    child: Text('🔥 $days jours',
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(color: AppColors.accentOrange, fontWeight: FontWeight.w800)));
}