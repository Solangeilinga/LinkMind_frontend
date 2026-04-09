import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    String? error,
  }) => AuthState(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    isLoading: isLoading ?? this.isLoading,
    user: user ?? this.user,
    error: error,
  );
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
  }) => MoodState(
    isLoading: isLoading ?? this.isLoading,
    todayMood: todayMood ?? this.todayMood,
    history: history ?? this.history,
    stats: stats ?? this.stats,
    recommendations: recommendations ?? this.recommendations,
    error: error,
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
  }) => ChallengesState(
    isLoading: isLoading ?? this.isLoading,
    daily: daily ?? this.daily,
    error: error,
  );
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
      final token = await _api.getAccessToken();
      if (token != null) {
        final data = await _api.getMe();
        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          user: UserModel.fromJson(data['user']),
        );
      } else {
        state = const AuthState(isAuthenticated: false, isLoading: false);
      }
    } catch (_) {
      state = const AuthState(isAuthenticated: false, isLoading: false);
    }
  }

  Future<bool> login({String? email, String? phone, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.login(email: email, phone: phone, password: password);
      await _api.saveTokens(data['accessToken'], data['refreshToken']);
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        user: UserModel.fromJson(data['user']),
      );
      _ref.read(challengesProvider.notifier).reset();
      _ref.read(moodProvider.notifier).reset();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    int? age,
    String? city,
    String? gender,
    required String password,
    String? anonymousAlias,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.register(
        firstName: firstName, lastName: lastName,
        email: email, phone: phone,
        age: age, city: city, gender: gender,
        password: password,
        anonymousAlias: anonymousAlias,
      );
      await _api.saveTokens(data['accessToken'], data['refreshToken']);
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        user: UserModel.fromJson(data['user']),
      );
      _ref.read(challengesProvider.notifier).reset();
      _ref.read(moodProvider.notifier).reset();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _ref.read(challengesProvider.notifier).reset();
    _ref.read(moodProvider.notifier).reset();
    state = const AuthState(isAuthenticated: false, isLoading: false);
  }

  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
  }

  // ✅ AJOUTÉ: Rafraîchir les données utilisateur (après paiement Premium)
  Future<void> refreshUser() async {
    try {
      final data = await _api.getMe();
      if (data['user'] != null) {
        final updatedUser = UserModel.fromJson(data['user']);
        state = state.copyWith(user: updatedUser);
        debugPrint('✅ Utilisateur rafraîchi: isPremium=${updatedUser.isPremium}');
      }
    } catch (e) {
      debugPrint('❌ Erreur refreshUser: $e');
    }
  }

  // ✅ Méthode ajoutée pour mood_screen.dart
  Future<void> loadDailyChallenges({String? moodLabel}) async {
    await _ref.read(challengesProvider.notifier).loadDaily(moodLabel: moodLabel);
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
        history: List<Map<String, dynamic>>.from(data['history']),
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

// ─── Challenges Notifier ──────────────────────────────────────────────────────
class ChallengesNotifier extends StateNotifier<ChallengesState> {
  final ApiService _api;

  ChallengesNotifier(this._api) : super(const ChallengesState()) {
    loadDaily();
  }

  void reset() {
    state = const ChallengesState();
    loadDaily();
  }

  Future<void> loadDaily({String? moodLabel}) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.getDailyChallenges(moodLabel: moodLabel);
      state = state.copyWith(
        isLoading: false,
        daily: List<Map<String, dynamic>>.from(data['challenges']),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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

final challengesProvider = StateNotifierProvider<ChallengesNotifier, ChallengesState>(
  (ref) => ChallengesNotifier(ref.read(apiServiceProvider)),
);