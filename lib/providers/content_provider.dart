import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api.service.dart';
import '../utils/theme.dart';

// ─── Mood Definition ──────────────────────────────────────────────────────────
class MoodDef {
  final String id, label, emoji;
  final Color color;
  final int score;
  const MoodDef({required this.id, required this.label, required this.emoji,
      required this.color, required this.score});

  factory MoodDef.fromJson(Map<String, dynamic> j) {
    Color c = AppColors.primary;
    try {
      final hex = (j['colorHex'] as String? ?? '#77021D').replaceFirst('#', '');
      c = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}
    return MoodDef(id: j['id'] ?? '', label: j['label'] ?? '',
        emoji: j['emoji'] ?? '😐', color: c,
        score: (j['score'] as num?)?.toInt() ?? 3);
  }

  MoodDefinition toMoodDefinition() =>
      MoodDefinition(id: id, label: label, emoji: emoji, color: color, score: score);
}

// ─── Professional Type ────────────────────────────────────────────────────────
class ProTypeDef {
  final String id, label, labelPlural, emoji, colorHex;
  const ProTypeDef({required this.id, required this.label, required this.labelPlural,
      required this.emoji, required this.colorHex});

  factory ProTypeDef.fromJson(Map<String, dynamic> j) => ProTypeDef(
    id: j['id'] ?? '', label: j['label'] ?? '',
    labelPlural: j['labelPlural'] ?? j['label'] ?? '',
    emoji: j['emoji'] ?? '🧑‍⚕️', colorHex: j['colorHex'] ?? '#77021D');

  Color get color {
    try { return Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16)); }
    catch (_) { return AppColors.primary; }
  }
}

// ─── Challenge Category ───────────────────────────────────────────────────────
class ChallengeCategoryDef {
  final String id, label, emoji, colorHex;
  const ChallengeCategoryDef({required this.id, required this.label,
      required this.emoji, required this.colorHex});

  factory ChallengeCategoryDef.fromJson(Map<String, dynamic> j) => ChallengeCategoryDef(
    id: j['id'] ?? '', label: j['label'] ?? '',
    emoji: j['emoji'] ?? '⚡', colorHex: j['colorHex'] ?? '#77021D');

  Color get color {
    try { return Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16)); }
    catch (_) { return AppColors.primary; }
  }
}

// ─── Challenge Difficulty ─────────────────────────────────────────────────────
class ChallengeDifficultyDef {
  final String id, label, colorHex;
  const ChallengeDifficultyDef({required this.id, required this.label, required this.colorHex});

  factory ChallengeDifficultyDef.fromJson(Map<String, dynamic> j) => ChallengeDifficultyDef(
    id: j['id'] ?? '', label: j['label'] ?? '', colorHex: j['colorHex'] ?? '#6BCF7F');

  Color get color {
    try { return Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16)); }
    catch (_) { return const Color(0xFF6BCF7F); }
  }
}

// ─── Post Type ────────────────────────────────────────────────────────────────
class PostTypeDef {
  final String id, label, emoji, colorHex;
  final bool isLegacy;
  const PostTypeDef({required this.id, required this.label, required this.emoji,
      required this.colorHex, this.isLegacy = false});

  factory PostTypeDef.fromJson(Map<String, dynamic> j) => PostTypeDef(
    id: j['id'] ?? '', label: j['label'] ?? '',
    emoji: j['emoji'] ?? '💬', colorHex: j['colorHex'] ?? '#77021D',
    isLegacy: j['isLegacy'] == true);

  Color get color {
    try { return Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16)); }
    catch (_) { return AppColors.primary; }
  }
}

// ─── Stress Factor ────────────────────────────────────────────────────────────
class StressFactorDef {
  final String id, label, emoji;
  const StressFactorDef({required this.id, required this.label, required this.emoji});

  factory StressFactorDef.fromJson(Map<String, dynamic> j) => StressFactorDef(
    id: j['id'] ?? '', label: j['label'] ?? '', emoji: j['emoji'] ?? '💭');
}

// ─── Content State ────────────────────────────────────────────────────────────
class ContentState {
  final List<MoodDef>              moods;
  final List<ProTypeDef>           professionalTypes;
  final List<ChallengeCategoryDef> challengeCategories;
  final List<ChallengeDifficultyDef> challengeDifficulties;
  final List<PostTypeDef>          postTypes;
  final List<StressFactorDef>      stressFactors;
  final bool                       loaded;

  const ContentState({
    this.moods                 = const [],
    this.professionalTypes     = const [],
    this.challengeCategories   = const [],
    this.challengeDifficulties = const [],
    this.postTypes             = const [],
    this.stressFactors         = const [],
    this.loaded                = false,
  });

  ContentState copyWith({
    List<MoodDef>?               moods,
    List<ProTypeDef>?            professionalTypes,
    List<ChallengeCategoryDef>?  challengeCategories,
    List<ChallengeDifficultyDef>? challengeDifficulties,
    List<PostTypeDef>?           postTypes,
    List<StressFactorDef>?       stressFactors,
    bool?                        loaded,
  }) => ContentState(
    moods:                 moods                 ?? this.moods,
    professionalTypes:     professionalTypes     ?? this.professionalTypes,
    challengeCategories:   challengeCategories   ?? this.challengeCategories,
    challengeDifficulties: challengeDifficulties ?? this.challengeDifficulties,
    postTypes:             postTypes             ?? this.postTypes,
    stressFactors:         stressFactors         ?? this.stressFactors,
    loaded:                loaded                ?? this.loaded,
  );

  // Fallback vers kMoods si pas encore chargé
  List<MoodDefinition> get moodDefinitions => loaded && moods.isNotEmpty
      ? moods.map((m) => m.toMoodDefinition()).toList()
      : kMoods;

  // Helpers
  ChallengeCategoryDef? findCategory(String id) {
    try { return challengeCategories.firstWhere((c) => c.id == id); }
    catch (_) { return null; }
  }

  ChallengeDifficultyDef? findDifficulty(String id) {
    try { return challengeDifficulties.firstWhere((d) => d.id == id); }
    catch (_) { return null; }
  }

  PostTypeDef? findPostType(String id) {
    try { return postTypes.firstWhere((t) => t.id == id); }
    catch (_) { return null; }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
class ContentNotifier extends StateNotifier<ContentState> {
  ContentNotifier() : super(const ContentState());

  Future<void> load() async {
    try {
      final results = await Future.wait([
        ApiService().getMoodDefinitions(),
        ApiService().getProfessionalTypes(),
        ApiService().getChallengeCategories(),
        ApiService().getChallengeDifficulties(),
        ApiService().getPostTypes(),
        ApiService().getStressFactors(),
      ]);

      state = state.copyWith(
        moods: (results[0]['moods'] as List? ?? [])
            .map((m) => MoodDef.fromJson(Map<String, dynamic>.from(m))).toList(),
        professionalTypes: (results[1]['types'] as List? ?? [])
            .map((t) => ProTypeDef.fromJson(Map<String, dynamic>.from(t))).toList(),
        challengeCategories: (results[2]['categories'] as List? ?? [])
            .map((c) => ChallengeCategoryDef.fromJson(Map<String, dynamic>.from(c))).toList(),
        challengeDifficulties: (results[3]['difficulties'] as List? ?? [])
            .map((d) => ChallengeDifficultyDef.fromJson(Map<String, dynamic>.from(d))).toList(),
        postTypes: (results[4]['types'] as List? ?? [])
            .map((t) => PostTypeDef.fromJson(Map<String, dynamic>.from(t))).toList(),
        stressFactors: (results[5]['factors'] as List? ?? [])
            .map((f) => StressFactorDef.fromJson(Map<String, dynamic>.from(f))).toList(),
        loaded: true,
      );
    } catch (_) {
      state = state.copyWith(loaded: true);
    }
  }
}

final contentProvider = StateNotifierProvider<ContentNotifier, ContentState>(
  (ref) => ContentNotifier(),
);