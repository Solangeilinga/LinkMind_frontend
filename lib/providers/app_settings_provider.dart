import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── État des paramètres ──────────────────────────────────────────────────────
class AppSettings {
  final ThemeMode themeMode;
  final double textScale;
  final String language;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.textScale = 1.0,
    this.language  = 'fr',
  });

  Locale get locale => Locale(language);

  AppSettings copyWith({ThemeMode? themeMode, double? textScale, String? language}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        textScale: textScale ?? this.textScale,
        language:  language  ?? this.language,
      );
}

// ─── Provider ────────────────────────────────────────────────────────────────
class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme') ?? 'system';
    final scale = prefs.getDouble('text_scale') ?? 1.0;
    final lang  = prefs.getString('language') ?? 'fr';
    state = AppSettings(
      themeMode: _parseTheme(theme),
      textScale: scale,
      language: lang,
    );
  }

  ThemeMode _parseTheme(String s) {
    if (s == 'light') return ThemeMode.light;
    if (s == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system';
    await prefs.setString('theme', key);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setTextScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_scale', scale);
    state = state.copyWith(textScale: scale);
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    state = state.copyWith(language: lang);
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new);