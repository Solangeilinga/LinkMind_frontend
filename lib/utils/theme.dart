import 'package:flutter/material.dart';

// ─── Color Palette ────────────────────────────────────────────────────────────
class AppColors {
  // Primary — Bordeaux #77021D
  static const primary      = Color(0xFF77021D);
  static const primaryLight = Color(0xFF9E1530);
  static const primaryDark  = Color(0xFF550114);

  // Secondary — Jaune doré #F5B731
  static const secondary      = Color(0xFFF5B731);
  static const secondaryLight = Color(0xFFF8C95A);

  // Accents — orange palette from image
  static const accent       = Color(0xFFE07B2A); // orange
  static const accentOrange = Color(0xFFD95E2B); // orange-rouge
  static const accentRed    = Color(0xFFC93B2B); // rouge-orangé

  // Mood colors — harmonized with warm palette
  static const moodGreat    = Color(0xFFF5B731); // jaune doré
  static const moodGood     = Color(0xFF5BAD72); // vert (neutral positif)
  static const moodNeutral  = Color(0xFF5B8FC4); // bleu calme
  static const moodTired    = Color(0xFF8B7EC8); // violet doux
  static const moodStressed = Color(0xFFD95E2B); // orange-rouge
  static const moodAnxious  = Color(0xFFE07B2A); // orange
  static const moodSad      = Color(0xFF5BA8A8); // bleu-vert

  // Neutrals — warm-tinted (bordeaux harmony)
  static const background      = Color(0xFFFAF7F5);
  static const surface         = Color(0xFFFFFFFF);
  static const surfaceVariant  = Color(0xFFF5EFED);
  static const onSurface       = Color(0xFF1C1010);
  static const onSurfaceMuted  = Color(0xFF8A7070);
  static const divider         = Color(0xFFEDE5E3);

  // Dark mode
  static const backgroundDark     = Color(0xFF120508);
  static const surfaceDark        = Color(0xFF1E0A0E);
  static const surfaceVariantDark = Color(0xFF2A1218);
}

// ─── Text Styles ─────────────────────────────────────────────────────────────
class AppTextStyles {
  static const String fontFamily = 'Nunito';

  static const h1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, fontFamily: fontFamily, height: 1.2);
  static const h2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFamily: fontFamily, height: 1.3);
  static const h3 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: fontFamily, height: 1.3);
  static const h4 = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: fontFamily);
  static const body      = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: fontFamily, height: 1.5);
  static const bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFamily: fontFamily);
  static const caption   = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: fontFamily, letterSpacing: 0.3);
  static const button    = TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFamily: fontFamily);
}

// ─── Spacing & Radius ────────────────────────────────────────────────────────
class AppSpacing {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 16.0;
  static const lg  = 24.0;
  static const xl  = 32.0;
  static const xxl = 48.0;
}

class AppRadius {
  static const sm   = BorderRadius.all(Radius.circular(8));
  static const md   = BorderRadius.all(Radius.circular(16));
  static const lg   = BorderRadius.all(Radius.circular(24));
  static const xl   = BorderRadius.all(Radius.circular(32));
  static const full = BorderRadius.all(Radius.circular(100));
}

// ─── Theme ───────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      surface: AppColors.surface,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.accent,
      brightness: Brightness.light,
    ),
    fontFamily: AppTextStyles.fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w800,
        fontFamily: AppTextStyles.fontFamily,
        color: AppColors.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(borderRadius: AppRadius.md, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: AppRadius.md, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      surface: AppColors.surfaceDark,
      primary: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      brightness: Brightness.dark,
    ),
    fontFamily: AppTextStyles.fontFamily,
    scaffoldBackgroundColor: AppColors.backgroundDark,
  );
}

// ─── Mood Definitions ────────────────────────────────────────────────────────
class MoodDefinition {
  final String id, label, emoji;
  final Color color;
  final int score;
  const MoodDefinition({required this.id, required this.label,
      required this.emoji, required this.color, required this.score});
}

const List<MoodDefinition> kMoods = [
  MoodDefinition(id: 'great',   label: 'Super bien',    emoji: '😄', color: AppColors.moodGreat,    score: 5),
  MoodDefinition(id: 'good',    label: 'Bien',           emoji: '🙂', color: AppColors.moodGood,     score: 4),
  MoodDefinition(id: 'neutral', label: 'Neutre',         emoji: '😐', color: AppColors.moodNeutral,  score: 3),
  MoodDefinition(id: 'tired',   label: 'Fatigué(e)',     emoji: '😔', color: AppColors.moodTired,    score: 2),
  MoodDefinition(id: 'stressed',label: 'Stressé(e)',     emoji: '😰', color: AppColors.moodStressed, score: 1),
  MoodDefinition(id: 'anxious', label: 'Anxieux(se)',    emoji: '😟', color: AppColors.moodAnxious,  score: 1),
  MoodDefinition(id: 'sad',     label: 'Triste',         emoji: '😢', color: AppColors.moodSad,      score: 2),
];

// ─── Constants ───────────────────────────────────────────────────────────────
class AppConstants {
  static const appName = 'LinkMind';
  static const String baseUrl = 'http://192.168.12.135:3000/api';
  static const int tokenRefreshThreshold = 300;
}