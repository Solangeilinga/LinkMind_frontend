import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/theme.dart';

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
      // Corrupted keystore (happens after app reinstall on Android)
      // Wipe everything so the user can log in fresh
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

  Future<dynamic> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    // Token expired — try refresh
    if (response.statusCode == 401 && body['code'] == 'TOKEN_EXPIRED') {
      final refreshed = await refreshAccessToken();
      if (!refreshed) throw ApiException('Session expirée. Reconnecte-toi.', 401);
      throw ApiException('retry', 401, retryable: true);
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

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: headers,
      body: jsonEncode(body),
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
      'lastName':  lastName,
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

  Future<Map<String, dynamic>> getTodayMood() async {
    return await get('/mood/today');
  }

  Future<Map<String, dynamic>> getMoodHistory({int days = 7}) async {
    return await get('/mood/history', queryParams: {'days': days.toString()});
  }

  Future<Map<String, dynamic>> getMoodInsights() async {
    return await get('/mood/insights');
  }

  // ─── Challenges ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDailyChallenges({String? moodLabel}) async {
    return await get('/challenges/daily',
        queryParams: moodLabel != null ? {'moodLabel': moodLabel} : null);
  }

  Future<Map<String, dynamic>> completeChallenge(
    String challengeId, {
    int? durationSeconds,
    String? moodId,
  }) async {
    return await post('/challenges/$challengeId/complete', {
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (moodId != null) 'moodId': moodId,
    });
  }

  Future<Map<String, dynamic>> submitChallengeFeedback(
    String completionId, {
    required bool helpful,
    int? rating,
  }) async {
    return await patch('/challenges/completions/$completionId/feedback', {
      'helpful': helpful,
      if (rating != null) 'rating': rating,
    });
  }

  // ─── Community ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getFeed({int page = 1}) async {
    return await get('/community/feed', queryParams: {'page': page.toString()});
  }

  Future<Map<String, dynamic>> getMyPosts({int page = 1}) async {
    return await get('/community/my-posts', queryParams: {'page': page.toString()});
  }

  Future<Map<String, dynamic>> createPost({
    required String content,
    String postType = 'general',
    bool isAnonymous = false,
    int? moodScore,
  }) async {
    return await post('/community/posts', {
      'content': content,
      'postType': postType,
      'isAnonymous': isAnonymous,
      if (moodScore != null) 'moodScore': moodScore,
    });
  }

  Future<Map<String, dynamic>> toggleLike(String postId) async {
    return await post('/community/posts/$postId/like', {});
  }

  Future<Map<String, dynamic>> getGroupChallenges() async {
    return await get('/community/group-challenges');
  }

  // ─── User ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMe() async {
    return await get('/users/me');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return await patch('/users/me', data);
  }

  Future<Map<String, dynamic>> getLeaderboard() async {
    return await get('/users/leaderboard');
  }


  // ─── Assistant (Mindo/Gemini) ─────────────────────────────────────────────
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
        Uri.parse('\${AppConstants.baseUrl}/assistant/session'),
        headers: headers,
      );
    } catch (_) {}
  }

}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final bool retryable;

  ApiException(this.message, this.statusCode, {this.retryable = false});

  @override
  String toString() => message;
}