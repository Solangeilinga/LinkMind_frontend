import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/theme.dart';

// ============================================================================
// CLASSES D'ERREUR DE SÉCURITÉ
// ============================================================================

enum SecurityErrorType {
  unauthorized,
  sessionExpired,
  accountLocked,
  accountRestricted,
  rateLimited,
  forbidden,
}

class SecurityException implements Exception {
  final String message;
  final SecurityErrorType type;
  final Map<String, dynamic>? data;
  
  SecurityException(this.message, this.type, {this.data});
  
  @override
  String toString() => message;
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final bool retryable;

  ApiException(this.message, this.statusCode, {this.retryable = false});

  @override
  String toString() => message;
}

// ============================================================================
// API SERVICE PRINCIPAL
// ============================================================================

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();
  String? _accessToken;

  // ─── Token Management ──────────────────────────────────────────────────────
  Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<String?> getAccessToken() async {
    if (_accessToken != null) return _accessToken;
    try {
      _accessToken = await _storage.read(key: 'access_token');
    } catch (_) {
      try { await _storage.deleteAll(); } catch (_) {}
      _accessToken = null;
    }
    return _accessToken;
  }

  Future<bool> refreshAccessToken() async {
    try {
      String? refresh;
      try {
        refresh = await _storage.read(key: 'refresh_token');
      } catch (_) {
        try { await _storage.deleteAll(); } catch (_) {}
        return false;
      }
      if (refresh == null) return false;

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['accessToken'], data['refreshToken']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    await _storage.deleteAll();
  }

  // ─── HTTP Helpers ──────────────────────────────────────────────────────────
  Future<Map<String, String>> _getHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Helper pour nettoyer les posts (corrige l'erreur post.toObject is not a function)
  dynamic _cleanPosts(dynamic response) {
    if (response is Map<String, dynamic> && response.containsKey('posts')) {
      final posts = response['posts'];
      if (posts is List) {
        final cleanedPosts = posts.map((post) {
          if (post is Map<String, dynamic>) return post;
          if (post != null && post is dynamic) {
            try {
              if (post.toJson != null && post.toJson is Function) {
                return post.toJson();
              }
              return Map<String, dynamic>.from(post as Map);
            } catch (e) {
              debugPrint('⚠️ Erreur nettoyage post: $e');
              return {'_raw': post.toString()};
            }
          }
          return post;
        }).toList();
        response['posts'] = cleanedPosts;
      }
    }
    return response;
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body);
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _cleanPosts(body);
    }
    
    if (response.statusCode == 401) {
      if (body['code'] == 'SESSION_EXPIRED') {
        throw SecurityException('Session expirée', SecurityErrorType.sessionExpired);
      }
      if (body['code'] == 'TOKEN_EXPIRED') {
        final refreshed = await refreshAccessToken();
        if (!refreshed) {
          throw SecurityException('Session expirée', SecurityErrorType.sessionExpired);
        }
        throw ApiException('retry', 401, retryable: true);
      }
      throw SecurityException(
        body['error'] ?? 'Non authentifié', 
        SecurityErrorType.unauthorized
      );
    }
    
    if (response.statusCode == 429) {
      if (body['code'] == 'ACCOUNT_LOCKED') {
        throw SecurityException(
          body['message'] ?? 'Compte verrouillé',
          SecurityErrorType.accountLocked,
          data: {'remainingMinutes': body['remainingMinutes']}
        );
      }
      if (body['code'] == 'ACCOUNT_RESTRICTED') {
        throw SecurityException(
          body['message'] ?? 'Compte restreint',
          SecurityErrorType.accountRestricted,
          data: {'until': body['until']}
        );
      }
      throw SecurityException(
        body['error'] ?? 'Trop de requêtes', 
        SecurityErrorType.rateLimited
      );
    }
    
    if (response.statusCode == 403) {
      throw SecurityException(
        body['error'] ?? 'Accès interdit', 
        SecurityErrorType.forbidden
      );
    }
    
    throw ApiException(body['error'] ?? 'Une erreur est survenue', response.statusCode);
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path')
        .replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers);
    return _handleResponse(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(String path) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> register({
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
    return await post('/auth/register', {
      'firstName': firstName,
      'lastName': lastName,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (age != null) 'age': age,
      if (city != null && city.isNotEmpty) 'city': city,
      if (gender != null) 'gender': gender,
      'password': password,
      if (anonymousAlias != null && anonymousAlias.isNotEmpty) 'anonymousAlias': anonymousAlias,
    });
  }

  Future<Map<String, dynamic>> login({String? email, String? phone, required String password}) async {
    return await post('/auth/login', {
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'password': password,
    });
  }

  Future<void> logout() async {
    try { await post('/auth/logout', {}); } catch (_) {}
    await clearTokens();
  }

  // ─── Verification (Email ou SMS) ───────────────────────────────────────────
  /// Envoie un code de vérification par email ou SMS selon le moyen de contact
  Future<Map<String, dynamic>> sendVerification() async {
    return await post('/auth/send-verification', {});
  }

  /// Vérifie le code de vérification
  Future<bool> verifyEmail(String code) async {
    final response = await post('/auth/verify-email', {'code': code});
    return response['verified'] == true;
  }

  // ─── Legal ─────────────────────────────────────────────────────────────────
  Future<void> acceptLegal() async =>
      await post('/users/accept-legal', {});

  // ─── Account Management (RGPD) ─────────────────────────────────────────────
  Future<void> deleteAccount() async => 
      await delete('/users/me');
      
  Future<dynamic> exportMyData() async => 
      await get('/users/me/export');

  // ─── User Activity ─────────────────────────────────────────────────────────
  Future<void> recordActivity({
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await post('/users/activity', {
        'type': type,
        'metadata': metadata ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ─── Mood ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> logMood({
    required int score,
    required String label,
    String? note,
    List<String>? factors,
    int? energyLevel,
  }) async {
    return await post('/mood', {
      'score': score,
      'label': label,
      if (note != null) 'note': note,
      if (factors != null) 'factors': factors,
      if (energyLevel != null) 'energyLevel': energyLevel,
    });
  }

  Future<Map<String, dynamic>> getTodayMood() async =>
      await get('/mood/today');

  Future<Map<String, dynamic>> getMoodHistory({int days = 7}) async =>
      await get('/mood/history', queryParams: {'days': days.toString()});

  Future<Map<String, dynamic>> getMoodInsights() async =>
      await get('/mood/insights');

  // ─── Challenges ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDailyChallenges({String? moodLabel}) async =>
      await get('/challenges/daily',
          queryParams: moodLabel != null ? {'moodLabel': moodLabel} : null);

  Future<Map<String, dynamic>> completeChallenge(
    String challengeId, {
    int? durationSeconds,
    String? moodId,
    String? reflection,
  }) async {
    final body = <String, dynamic>{};
    if (durationSeconds != null) body['durationSeconds'] = durationSeconds;
    if (moodId != null) body['moodId'] = moodId;
    if (reflection != null) body['reflection'] = reflection;
    return await post('/challenges/$challengeId/complete', body);
  }

  Future<Map<String, dynamic>> submitChallengeFeedback(
    String completionId, {
    required bool helpful,
    int? rating,
    String? comment,
  }) async {
    return await patch('/challenges/completions/$completionId/feedback', {
      'helpful': helpful,
      if (rating != null) 'rating': rating,
      if (comment != null) 'comment': comment,
    });
  }

  // ─── Community ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getFeed({int page = 1}) async =>
      await get('/community/feed', queryParams: {'page': page.toString()});

  Future<Map<String, dynamic>> getMyPosts({int page = 1}) async =>
      await get('/community/my-posts', queryParams: {'page': page.toString()});

  Future<Map<String, dynamic>> createPost({
    required String content,
    String postType = 'general',
    bool isAnonymous = false,
    int? moodScore,
    String? moodEmoji,
  }) async {
    return await post('/community/posts', {
      'content': content,
      'postType': postType,
      'isAnonymous': isAnonymous,
      if (moodScore != null) 'moodScore': moodScore,
      if (moodEmoji != null) 'moodEmoji': moodEmoji,
    });
  }

  Future<Map<String, dynamic>> editPost(String postId, String content) async =>
      await patch('/community/posts/$postId', {'content': content});

  Future<Map<String, dynamic>> toggleLike(String postId) async =>
      await post('/community/posts/$postId/like', {});

  Future<Map<String, dynamic>> toggleSameFeeling(String postId) async =>
      await post('/community/posts/$postId/same-feeling', {});

  Future<void> deletePost(String postId) async =>
      await delete('/community/posts/$postId');

  Future<Map<String, dynamic>> toggleReaction(String postId, String type) async =>
      await post('/community/posts/$postId/react', {'type': type});

  Future<Map<String, dynamic>> searchPosts(String query, {String? postType}) async =>
      await get('/community/search', queryParams: {
        'q': query,
        if (postType != null) 'type': postType,
      });

  Future<Map<String, dynamic>> getGroupChallenges() async =>
      await get('/community/group-challenges');

  // ─── Notifications ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getNotifications({int page = 1}) async =>
      await get('/notifications', queryParams: {'page': page.toString()});

  Future<void> markNotificationRead(String id) async =>
      await patch('/notifications/$id/read', {});

  Future<void> markAllNotificationsRead() async =>
      await patch('/notifications/read-all', {});

  Future<void> deleteNotification(String id) async =>
      await delete('/notifications/$id');

  Future<void> clearAllNotifications() async =>
      await delete('/notifications');

  Future<void> registerFcmToken(String token) async =>
      await post('/notifications/fcm-token', {'token': token});

  // ─── Professionals ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfessionals({
    String? type, String? city, String? search,
    int page = 1, int limit = 20,
  }) async {
    final Map<String, String> params = {
      'page': page.toString(), 'limit': limit.toString()};
    if (type != null) params['type'] = type;
    if (city != null) params['city'] = city;
    if (search != null) params['search'] = search;
    return await get('/professionals', queryParams: params);
  }

  Future<Map<String, dynamic>> getProfessional(String id) async =>
      await get('/professionals/$id');

  Future<Map<String, dynamic>> bookProfessional({
    required String professionalId,
    required String message,
    String? preferredDate,
    String? consultationType,
  }) async {
    return await post('/professionals/$professionalId/book', {
      'message': message,
      if (preferredDate != null) 'preferredDate': preferredDate,
      if (consultationType != null) 'consultationType': consultationType,
    });
  }

  Future<Map<String, dynamic>> getMyBookings() async =>
      await get('/professionals/bookings/me');

  Future<Map<String, dynamic>> updateBooking({
    required String bookingId,
    String? consultationType,
    String? preferredDate,
    String? message,
  }) async {
    final Map<String, dynamic> data = {};
    if (consultationType != null) data['consultationType'] = consultationType;
    if (preferredDate != null) data['preferredDate'] = preferredDate;
    if (message != null) data['message'] = message;
    return await put('/professionals/bookings/$bookingId', data);
  }

  Future<void> cancelBooking(String bookingId) async =>
      await delete('/professionals/bookings/$bookingId');

  // ─── User ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMe() async =>
      await get('/users/me');

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async =>
      await patch('/users/me', data);

  Future<Map<String, dynamic>> getLeaderboard() async =>
      await get('/users/leaderboard');

  // ─── Assistant ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> chatWithAssistant({
    required String message,
    Map<String, dynamic>? context,
  }) async {
    return await post('/assistant/chat', {
      'message': message,
      if (context != null) 'context': context,
    });
  }

  Future<void> clearAssistantSession() async {
    try {
      final headers = await _getHeaders();
      await http.delete(
        Uri.parse('${AppConstants.baseUrl}/assistant/session'),
        headers: headers,
      );
    } catch (_) {}
  }

  // ─── Content (from DB) ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDailyMessage() async =>
      await get('/content/daily-message');

  Future<Map<String, dynamic>> getWellnessTips({String? mood}) async =>
      await get('/content/wellness-tips',
          queryParams: mood != null ? {'mood': mood} : null);

  Future<Map<String, dynamic>> getStressFactors() async =>
      await get('/content/stress-factors');

  Future<Map<String, dynamic>> getBadgesConfig() async =>
      await get('/content/badges');

  Future<Map<String, dynamic>> getAssistantStarters() async =>
      await get('/content/assistant-starters');

  Future<Map<String, dynamic>> getMoodDefinitions() async =>
      await get('/content/moods');

  Future<Map<String, dynamic>> getProfessionalTypes() async =>
      await get('/content/professional-types');

  Future<Map<String, dynamic>> getChallengeCategories() async =>
      await get('/content/challenge-categories');

  Future<Map<String, dynamic>> getChallengeDifficulties() async =>
      await get('/content/challenge-difficulties');

  Future<Map<String, dynamic>> getPostTypes() async =>
      await get('/content/post-types');
}