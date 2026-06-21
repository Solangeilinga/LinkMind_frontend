import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api.service.dart';
import 'package:flutter/foundation.dart';

// ─── Auth State ───────────────────────────────────────────────────────────────
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = true,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    UserModel? user,
    Object? error = _sentinel,
  }) =>
      AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
        user: user ?? this.user,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );

  static const _sentinel = Object();
}

// ─── Mood State ───────────────────────────────────────────────────────────────
class MoodState {
  final bool isLoading;
  final Map<String, dynamic>? todayMood;
  final List<Map<String, dynamic>> history;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? recommendations;
  final String? error;

  const MoodState({
    this.isLoading = false,
    this.todayMood,
    this.history = const [],
    this.stats,
    this.recommendations,
    this.error,
  });

  MoodState copyWith({
    bool? isLoading,
    Map<String, dynamic>? todayMood,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? recommendations,
    String? error,
  }) =>
      MoodState(
        isLoading: isLoading ?? this.isLoading,
        todayMood: todayMood ?? this.todayMood,
        history: history ?? this.history,
        stats: stats ?? this.stats,
        recommendations: recommendations ?? this.recommendations,
        error: error ?? this.error,
      );
}

// ─── Challenges State ─────────────────────────────────────────────────────────
class ChallengesState {
  final bool isLoading;
  final List<Map<String, dynamic>> daily;
  final String? error;

  const ChallengesState({
    this.isLoading = false,
    this.daily = const [],
    this.error,
  });

  ChallengesState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? daily,
    String? error,
  }) =>
      ChallengesState(
        isLoading: isLoading ?? this.isLoading,
        daily: daily ?? this.daily,
        error: error ?? this.error,
      );
}

// ─── Helper : message d'erreur human-readable ─────────────────────────────────
String _errorMessage(Object e, {String fallback = 'Une erreur inattendue est survenue. Réessaie.'}) {
  if (e is SecurityException) {
    switch (e.type) {
      case SecurityErrorType.accountLocked:
        final mins = e.data?['remainingMinutes'] ?? 15;
        return 'Compte verrouillé après trop de tentatives. Réessaie dans $mins min.';
      case SecurityErrorType.accountRestricted:
        return 'Ton compte est restreint. Contacte le support LinkMind.';
      case SecurityErrorType.unauthorized:
        return e.message.isNotEmpty
            ? e.message
            : 'Identifiants incorrects. Vérifie ton email et ton mot de passe.';
      case SecurityErrorType.rateLimited:
        return 'Trop de requêtes. Attends un moment avant de réessayer.';
      case SecurityErrorType.forbidden:
        return e.message.isNotEmpty ? e.message : 'Accès refusé. Vérifie que tu as accepté les conditions d\'utilisation.';
      default:
        return e.message.isNotEmpty ? e.message : fallback;
    }
  }
  if (e is ApiException) {
    if (e.statusCode == 401) {
      return 'Identifiants incorrects. Vérifie ton email et ton mot de passe.';
    }
    if (e.statusCode == 409) return e.message;
    if (e.statusCode == 400) return e.message;
    if (e.statusCode >= 500) return 'Serveur indisponible. Réessaie dans un moment.';
    return e.message.isNotEmpty ? e.message : fallback;
  }
  if (e is SocketException) {
    return 'Pas de connexion internet. Vérifie ton réseau.';
  }
  if (e is TimeoutException) {
    return 'Erreur de connexion au serveur. Réessaie.';
  }
  return fallback;
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final Ref _ref;

  AuthNotifier(this._api, this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final token = await _api.getAccessToken().timeout(const Duration(seconds: 5));
      if (token != null) {
        final data = await _api.getMe().timeout(const Duration(seconds: 8));
        final user = UserModel.fromJson(data['user']);
        debugPrint('🔍 [AuthInit] legalAccepted=${user.legalAccepted}');

        if (user.legalAccepted == true) {
          _saveLegalCache(user.id);
        }

        state = AuthState(isAuthenticated: true, isLoading: false, user: user);
      } else {
        state = const AuthState(isAuthenticated: false, isLoading: false);
      }
    } catch (e) {
      debugPrint('⚠️ [AuthInit] $e');
      state = const AuthState(isAuthenticated: false, isLoading: false);
    }
  }

  // ─── Login ────────────────────────────────────────────────────────────────
  Future<bool> login({String? email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.login(email: email, password: password);
      await _api.saveTokens(data['accessToken'], data['refreshToken']);
      final user = UserModel.fromJson(data['user']);
      debugPrint('🔍 [Login] legalAccepted=${user.legalAccepted}');

      state = AuthState(isAuthenticated: true, isLoading: false, user: user);
      _ref.read(challengesProvider.notifier).reset();
      _ref.read(moodProvider.notifier).reset();

      if (user.legalAccepted == true) _saveLegalCache(user.id);
      _sendPendingFcmToken(); // envoyer FCM token maintenant que JWT est disponible
      return true;
    } catch (e) {
      debugPrint('❌ [Login] ${e.runtimeType}: $e');
      state = state.copyWith(isLoading: false, error: _errorMessage(e));
      return false;
    }
  }

  // ─── Register ─────────────────────────────────────────────────────────────
  Future<bool> register({
    required String email,
    String? anonymousAlias,
    required String password,
    bool legalAccepted = true,
    int? age,
    String? city,
    String? country,
    String? gender,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.register(
        email: email, anonymousAlias: anonymousAlias,
        password: password, legalAccepted: legalAccepted,
        age: age, city: city, country: country, gender: gender,
      );
      await _api.saveTokens(data['accessToken'], data['refreshToken']);
      final user = UserModel.fromJson(data['user']);
      debugPrint('🔍 [Register] legalAccepted=${user.legalAccepted}');

      state = AuthState(isAuthenticated: true, isLoading: false, user: user);
      _ref.read(challengesProvider.notifier).reset();
      _ref.read(moodProvider.notifier).reset();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _errorMessage(e,
          fallback: 'Inscription échouée. Vérifie tes informations et réessaie.'));
      return false;
    }
  }

  // ─── Logout ───────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try { await _api.logout(); } catch (_) {}
    _ref.read(challengesProvider.notifier).reset();
    _ref.read(moodProvider.notifier).reset();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }

  void updateUser(UserModel user) => state = state.copyWith(user: user);

  Future<void> _sendPendingFcmToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('pending_fcm_token');
      if (token != null && token.isNotEmpty) {
        await _api.registerFcmToken(token);
        debugPrint('✅ FCM token envoyé après authentification');
      }
    } catch (e) {
      debugPrint('⚠️ FCM token send failed: $e');
    }
  }

  Future<void> refreshUser() async {
    try {
      final data = await _api.getMe();
      if (data['user'] != null) {
        final user = UserModel.fromJson(data['user']);
        state = state.copyWith(user: user);
        if (user.legalAccepted == true) _saveLegalCache(user.id);
        debugPrint('✅ User rafraîchi: isPremium=${user.isPremium}, legalAccepted=${user.legalAccepted}');
      }
    } catch (e) {
      debugPrint('⚠️ refreshUser: $e');
    }
  }

  Future<void> loadDailyChallenges({String? moodLabel}) async {
    await _ref.read(challengesProvider.notifier).loadDaily(moodLabel: moodLabel);
  }

  // ─── Mot de passe oublié ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    try {
      final data = await _api.post('/auth/forgot-password', {
        if (email != null) 'email': email,
      });
      return Map<String, dynamic>.from(data ?? {});
    } catch (e) {
      final msg = _errorMessage(e, fallback: 'Impossible d\'envoyer le code. Réessaie.');
      throw Exception(msg);
    }
  }

  Future<String?> verifyOtp({String? email, required String code}) async {
    try {
      final data = await _api.post('/auth/verify-otp', {
        if (email != null) 'email': email,
        'code': code,
      });
      return data['resetToken'] as String?;
    } catch (e) {
      final msg = _errorMessage(e, fallback: 'Code incorrect ou expiré.');
      throw Exception(msg);
    }
  }

  Future<void> resetPassword({
    String? email,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _api.post('/auth/reset-password', {
        if (email != null) 'email': email,
        'resetToken': resetToken,
        'newPassword': newPassword,
      });
    } catch (e) {
      final msg = _errorMessage(e, fallback: 'Réinitialisation échouée. Recommence depuis le début.');
      throw Exception(msg);
    }
  }

  // ─── Vérification Email / Téléphone ───────────────────────────────────────
  Future<Map<String, dynamic>> sendVerification() async {
    try {
      return await _api.sendVerification();
    } catch (e) {
      debugPrint('⚠️ sendVerification: $e');
      rethrow;
    }
  }

  Future<bool> verifyEmail(String code) async {
    try {
      final result = await _api.verifyEmail(code);
      if (result == true) {
        final currentUser = state.user;
        if (currentUser != null) {
          final updatedUser = currentUser.copyWith(isEmailVerified: true);
          state = state.copyWith(user: updatedUser);
          debugPrint('✅ verifyEmail: utilisateur mis à jour localement (isEmailVerified=true)');
        }
      }
      return result;
    } catch (e) {
      debugPrint('⚠️ verifyEmail: $e');
      rethrow;
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────
  void _saveLegalCache(String userId) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('legal_accepted_$userId', true);
    }).catchError((_) {});
  }
}

// ─── Mood Notifier ────────────────────────────────────────────────────────────
class MoodNotifier extends StateNotifier<MoodState> {
  final ApiService _api;

  MoodNotifier(this._api) : super(const MoodState()) {
    loadTodayMood();
    loadHistory();
  }

  void reset() {
    state = const MoodState();
    loadTodayMood();
    loadHistory();
  }

  Future<void> loadTodayMood() async {
    try {
      final data = await _api.getTodayMood();
      state = state.copyWith(todayMood: data['mood']);
    } catch (_) {}
  }

  Future<void> loadHistory({int days = 14}) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.getMoodHistory(days: days);
      state = state.copyWith(
        isLoading: false,
        history: List<Map<String, dynamic>>.from(data['history'] ?? []),
        stats: data['stats'],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> logMood({
    required int score,
    required String label,
    String? note,
    List<String>? factors,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.logMood(
        score: score, label: label, note: note, factors: factors,
      );
      state = state.copyWith(
        isLoading: false,
        todayMood: data['mood'],
        recommendations: data['recommendations'],
      );
      await loadHistory();
      return data;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

// ─── Challenges Notifier (VERSION DURABLE) ───────────────────────────────────
class ChallengesNotifier extends StateNotifier<ChallengesState> {
  final ApiService _api;
  final Ref _ref;

  ChallengesNotifier(this._api, this._ref) : super(const ChallengesState()) {
    loadDaily();
  }

  void reset() {
    state = const ChallengesState();
    loadDaily();
  }

  Future<void> loadDaily({String? moodLabel}) async {
    state = state.copyWith(isLoading: true);
    try {
      // 🔥 AUTO-MAGIQUE : Si pas de moodLabel fourni, on va le chercher
      String? finalMoodLabel = moodLabel;
      if (finalMoodLabel == null) {
        try {
          final todayData = await _api.getTodayMood();
          finalMoodLabel = todayData['mood']?['label'];
          if (finalMoodLabel != null) {
            debugPrint('📊 [Challenges] Auto-detected mood: $finalMoodLabel');
          }
        } catch (e) {
          debugPrint('⚠️ [Challenges] Could not fetch mood: $e');
        }
      }
      
      final data = await _api.getDailyChallenges(moodLabel: finalMoodLabel);
      state = state.copyWith(
        isLoading: false,
        daily: List<Map<String, dynamic>>.from(data['challenges'] ?? []),
        error: null,
      );
      
      debugPrint('✅ [Challenges] Loaded ${state.daily.length} challenges for mood: $finalMoodLabel');
    } catch (e) {
      debugPrint('❌ [Challenges] Error: $e');
      state = state.copyWith(
        isLoading: false, 
        error: e.toString(),
        daily: [],
      );
    }
  }

  Future<Map<String, dynamic>?> complete(String challengeId, {int? durationSeconds}) async {
    try {
      final data = await _api.completeChallenge(challengeId, durationSeconds: durationSeconds);
      final updated = state.daily.map((c) {
        if ((c['_id'] ?? c['id']) == challengeId) {
          return {...c, 'isCompleted': true};
        }
        return c;
      }).toList();
      state = state.copyWith(daily: updated);
      return data;
    } catch (e) {
      debugPrint('❌ [Challenges] Complete error: $e');
      return null;
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(apiServiceProvider), ref),
);

final moodProvider = StateNotifierProvider<MoodNotifier, MoodState>(
  (ref) => MoodNotifier(ref.read(apiServiceProvider)),
);

// ✅ UNE SEULE DÉCLARATION - avec les 2 arguments (Ref)
final challengesProvider = StateNotifierProvider<ChallengesNotifier, ChallengesState>(
  (ref) => ChallengesNotifier(ref.read(apiServiceProvider), ref),
);