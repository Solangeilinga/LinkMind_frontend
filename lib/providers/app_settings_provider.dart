import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sound_service.dart';

// ─── État ─────────────────────────────────────────────────────────────────────
class AppSettings {
  final ThemeMode themeMode;
  final double textScale;
  final String language;
  final bool soundsEnabled;

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.textScale  = 1.0,
    this.language   = 'fr',
    this.soundsEnabled = true,
  });

  Locale get locale => Locale(language);

  AppSettings copyWith({
    ThemeMode? themeMode,
    double?    textScale,
    String?    language,
    bool?      soundsEnabled,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    textScale:  textScale  ?? this.textScale,
    language:   language   ?? this.language,
    soundsEnabled: soundsEnabled ?? this.soundsEnabled,
  );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _kTheme    = 'theme_mode';   // 'light' | 'dark' | 'system'
  static const _kScale    = 'text_scale';
  static const _kLanguage = 'language';
  static const _kSounds   = 'sounds_enabled';

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_kTheme) ?? 'light';
    final scale    = prefs.getDouble(_kScale)  ?? 1.0;
    final lang     = prefs.getString(_kLanguage) ?? 'fr';
    final sounds   = prefs.getBool(_kSounds) ?? true;
    SoundService.instance.setEnabled(sounds);
    state = AppSettings(
      themeMode: _parseTheme(themeStr),
      textScale:  scale,
      language:   lang,
      soundsEnabled: sounds,
    );
  }

  ThemeMode _parseTheme(String s) {
    switch (s) {
      case 'dark':   return ThemeMode.dark;
      case 'system': return ThemeMode.system;
      default:       return ThemeMode.light;
    }
  }

  String _serializeTheme(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:   return 'dark';
      case ThemeMode.system: return 'system';
      default:               return 'light';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, _serializeTheme(mode));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> toggleDarkMode() async {
    final next = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(next);
  }

  Future<void> setTextScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kScale, scale);
    state = state.copyWith(textScale: scale);
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, lang);
    state = state.copyWith(language: lang);
  }

  Future<void> setSoundsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSounds, enabled);
    SoundService.instance.setEnabled(enabled);
    state = state.copyWith(soundsEnabled: enabled);
  }

  bool get isDark => state.themeMode == ThemeMode.dark;
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);