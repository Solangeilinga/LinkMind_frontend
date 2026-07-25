import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';
import '../utils/theme.dart';
import 'cache_manager.dart';

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
  static void Function()? _onSessionReplaced;

  static void setSessionReplacedCallback(void Function() cb) {
    _onSessionReplaced = cb;
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();
  final _cacheManager = ApiCacheManager();
  String? _accessToken;

  static bool disableCache = kDebugMode;

  // 🔧 Désactiver la vérification SSL UNIQUEMENT en debug (pour tester)
  static bool _ignoreSSLCertificates = kDebugMode;

  // ─── Token Management ──────────────────────────────────────────────────────
  Future<void> saveTokens(String access, [String? refresh]) async {
    _accessToken = access;
    await _storage.write(key: 'access_token', value: access);
    if (refresh != null) {
      await _storage.write(key: 'refresh_token', value: refresh);
    } else {
      await _storage.write(key: 'refresh_token', value: access);
    }
    if (kDebugMode) {
      debugPrint('✅ TOKEN SAUVEGARDÉ : ${access.substring(0, 10)}...');
    }
  }

  Future<String?> getAccessToken() async {
    if (_accessToken != null) {
      if (kDebugMode) {
        debugPrint('🔑 Token en mémoire : ${_accessToken!.substring(0, 10)}...');
      }
      return _accessToken;
    }
    try {
      _accessToken = await _storage.read(key: 'access_token');
      if (kDebugMode) {
        debugPrint('🔑 Token lu depuis storage : ${_accessToken?.substring(0, 10) ?? 'null'}...');
      }
    } catch (e) {
      debugPrint('❌ Erreur lecture token : $e');
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
        final newAccess = data['accessToken'] ?? data['access_token'];
        final newRefresh = data['refreshToken'] ?? data['refresh_token'];
        if (newAccess != null) {
          await saveTokens(newAccess, newRefresh);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    await _storage.deleteAll();
    if (kDebugMode) {
      debugPrint('🗑️ Tous les tokens supprimés');
    }
  }

  // ─── HTTP Helpers ──────────────────────────────────────────────────────────
  Future<Map<String, String>> _getHeaders() async {
    final token = await getAccessToken();
    if (kDebugMode) {
      debugPrint('📤 En-têtes : Authorization = ${token != null ? 'Bearer ${token.substring(0, 10)}...' : 'null'}');
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'LinkMind-Mobile/1.0',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Client> _getClient() async {
    if (kDebugMode && _ignoreSSLCertificates) {
      final ioClient = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return IOClient(ioClient);
    }
    return http.Client();
  }

  // ─── Data Extraction Helper ──────────────────────────────────────────────
  dynamic _extractData(dynamic response) {
    if (response is Map<String, dynamic>) {
      // Si la réponse a une structure avec 'data'
      if (response.containsKey('data')) {
        final data = response['data'];
        if (data is Map || data is List) {
          return data;
        }
      }
      // Si la réponse a une structure avec 'user'
      if (response.containsKey('user')) {
        final user = response['user'];
        if (user is Map) {
          return user;
        }
      }
      // Si la réponse a une structure avec 'challenge' ou 'challenges'
      if (response.containsKey('challenges')) {
        final challenges = response['challenges'];
        if (challenges is List) {
          return challenges;
        }
      }
      if (response.containsKey('challenge')) {
        final challenge = response['challenge'];
        if (challenge is Map) {
          return challenge;
        }
      }
      // Si la réponse a une structure avec 'posts'
      if (response.containsKey('posts')) {
        final posts = response['posts'];
        if (posts is List) {
          return posts;
        }
      }
      // Si la réponse a une structure avec 'feed'
      if (response.containsKey('feed')) {
        final feed = response['feed'];
        if (feed is List) {
          return feed;
        }
      }
      // Sinon, retourner le Map tel quel
      return response;
    }
    // Si c'est une liste, la retourner
    if (response is List) {
      return response;
    }
    return response;
  }

  dynamic _cleanPosts(dynamic response) {
    if (response is Map<String, dynamic> && response.containsKey('posts')) {
      final posts = response['posts'];
      if (posts is List) {
        final cleanedPosts = posts.map((post) {
          if (post is Map<String, dynamic>) return post;
          if (post != null) {
            try {
              return Map<String, dynamic>.from(post as Map);
            } catch (e) {
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

  // ─── Response Handler ─────────────────────────────────────────────────────
  Future<dynamic> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Nettoyer les posts si présents
      dynamic result = _cleanPosts(body);
      
      // 🔥 EXTRAIRE LES DONNÉES CORRECTEMENT
      result = _extractData(result);
      
      // 🔍 DEBUG
      if (kDebugMode) {
        debugPrint('📦 Response type: ${result.runtimeType}');
        if (result is Map) {
          debugPrint('📦 Response keys: ${(result as Map).keys}');
        }
        if (result is List) {
          debugPrint('📦 Response list length: ${result.length}');
        }
      }
      
      return result;
    }

    if (response.statusCode == 401) {
      if (body['code'] == 'SESSION_REPLACED') {
        _onSessionReplaced?.call();
        throw SecurityException(
          'Connexion détectée sur un autre appareil. Tu as été déconnecté(e).',
          SecurityErrorType.sessionExpired,
        );
      }
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
      throw SecurityException(body['error'] ?? 'Non authentifié', SecurityErrorType.unauthorized);
    }

    if (response.statusCode == 429) {
      if (body['code'] == 'ACCOUNT_LOCKED') {
        throw SecurityException(body['message'] ?? 'Compte verrouillé',
            SecurityErrorType.accountLocked,
            data: {'remainingMinutes': body['remainingMinutes']});
      }
      if (body['code'] == 'ACCOUNT_RESTRICTED') {
        throw SecurityException(body['message'] ?? 'Compte restreint',
            SecurityErrorType.accountRestricted,
            data: {'until': body['until']});
      }
      throw SecurityException(body['error'] ?? 'Trop de requêtes', SecurityErrorType.rateLimited);
    }

    if (response.statusCode == 403) {
      throw SecurityException(body['error'] ?? 'Accès interdit', SecurityErrorType.forbidden);
    }

    throw ApiException(body['error'] ?? 'Une erreur est survenue', response.statusCode);
  }

  Future<dynamic> _execute(
      Future<http.Response> Function(Map<String, String> headers) fn) async {
    final headers = await _getHeaders();
    final client = await _getClient();
    try {
      final response = await fn(headers);
      return _handleResponse(response);
    } on ApiException catch (e) {
      if (e.retryable) {
        final freshHeaders = await _getHeaders();
        final retryResponse = await fn(freshHeaders);
        return _handleResponse(retryResponse);
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ERREUR RÉSEAU dans _execute : $e');
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  // ─── Cache ────────────────────────────────────────────────────────────────
  void invalidateCache(String pathPattern) {
    _cacheManager.invalidateWhere((key) => key.startsWith(pathPattern));
    debugPrint('🗑️ Cache invalidé pour: $pathPattern');
  }

  void invalidateMultipleCache(List<String> patterns) {
    for (final pattern in patterns) {
      invalidateCache(pattern);
    }
  }

  String _generateCacheKey(String path, Map<String, String>? queryParams) {
    if (queryParams == null || queryParams.isEmpty) return path;
    final sortedParams = (queryParams.keys.toList()..sort())
        .map((k) => '$k=${queryParams[k]}')
        .join('&');
    return '$path?$sortedParams';
  }

  Duration _getCacheDuration(String path) {
    if (disableCache) return Duration.zero;

    if (path.startsWith('/content/moods') ||
        path.startsWith('/content/professional-types') ||
        path.startsWith('/content/challenge-categories') ||
        path.startsWith('/content/challenge-difficulties') ||
        path.startsWith('/content/stress-factors') ||
        path.startsWith('/content/post-types')) {
      return const Duration(minutes: 30);
    }

    if (path.startsWith('/content/')) return const Duration(minutes: 10);

    if (path.startsWith('/professionals/bookings') ||
        path.startsWith('/users/me')) {
      return Duration.zero;
    }

    if (path.startsWith('/professionals')) return const Duration(minutes: 2);
    if (path.startsWith('/community/')) return const Duration(minutes: 1);
    if (path.startsWith('/mood/history')) return const Duration(minutes: 2);
    if (path.startsWith('/mood/today')) return Duration.zero;
    if (path.startsWith('/challenges/')) return const Duration(minutes: 2);
    if (path.startsWith('/notifications')) return Duration.zero;

    return const Duration(minutes: 2);
  }

  Future<dynamic> _fetchFromNetwork(String path, Map<String, String>? queryParams) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path')
        .replace(queryParameters: queryParams);
    if (kDebugMode) {
      debugPrint('🌐 Appel réseau : $uri');
    }
    final result = await _execute(
        (h) => http.get(uri, headers: h).timeout(const Duration(seconds: 15)));

    final cacheDuration = _getCacheDuration(path);
    if (cacheDuration > Duration.zero && !disableCache) {
      final cacheKey = _generateCacheKey(path, queryParams);
      _cacheManager.set(cacheKey, result, expiry: cacheDuration);
    }

    return result;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams, bool forceRefresh = false}) async {
    final cacheKey = _generateCacheKey(path, queryParams);

    if (!forceRefresh && !disableCache) {
      final cached = _cacheManager.get<dynamic>(cacheKey);
      if (cached != null) {
        debugPrint('💾 API Cache Hit: $path');
        return cached;
      }
    }

    debugPrint('🌐 API Cache Miss/Fresh: $path');
    return await _fetchFromNetwork(path, queryParams);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    if (kDebugMode) {
      debugPrint('🌐 POST $uri');
    }
    return await _execute((h) => http
        .post(uri, headers: h, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15)));
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    return await _execute((h) => http
        .put(uri, headers: h, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15)));
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    return await _execute((h) => http
        .patch(uri, headers: h, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15)));
  }

  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    return await _execute((h) =>
        http.delete(uri, headers: h).timeout(const Duration(seconds: 15)));
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? anonymousAlias,
    bool legalAccepted = true,
    int? age,
    String? city,
    String? country,
    String? gender,
  }) async {
    final result = await post('/auth/register', {
      'email': email,
      'password': password,
      if (anonymousAlias != null && anonymousAlias.isNotEmpty) 'anonymousAlias': anonymousAlias,
      'legalAccepted': legalAccepted,
      if (age != null) 'age': age,
      if (city != null && city.isNotEmpty) 'city': city,
      if (country != null && country.isNotEmpty) 'country': country,
      if (gender != null) 'gender': gender,
    });

    final accessToken = result['accessToken'] ?? result['access_token'] ?? result['token'];
    final refreshToken = result['refreshToken'] ?? result['refresh_token'] ?? result['refresh'];
    if (accessToken != null) {
      await saveTokens(accessToken, refreshToken);
      invalidateCache('/users/me');
    }
    return result;
  }

  Future<Map<String, dynamic>> login({String? email, required String password}) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}/auth/login');
      if (kDebugMode) {
        debugPrint('🌐 Tentative de connexion à : $uri');
      }

      final result = await post('/auth/login', {
        if (email != null && email.isNotEmpty) 'email': email,
        'password': password,
      });

      if (kDebugMode) {
        debugPrint('📦 Réponse login brute : $result');
      }

      final accessToken = result['accessToken'] ?? result['access_token'] ?? result['token'];
      final refreshToken = result['refreshToken'] ?? result['refresh_token'] ?? result['refresh'];

      if (accessToken != null) {
        await saveTokens(accessToken, refreshToken);
        if (kDebugMode) {
          debugPrint('✅ Tokens sauvegardés avec succès');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ Aucun access token trouvé. Clés disponibles : ${result.keys}');
        }
      }

      invalidateCache('/users/me');
      return result;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ ERREUR LORS DU LOGIN : $e');
        debugPrint(stack.toString());
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try { await post('/auth/logout', {}); } catch (_) {}
    await clearTokens();
    _cacheManager.clearAll();
  }

  // ─── Verification ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> sendVerification() async =>
      await post('/auth/send-verification', {});

  Future<bool> verifyEmail(String code) async {
    final response = await post('/auth/verify-email', {'code': code});
    invalidateCache('/users/me');
    return response['verified'] == true;
  }

  // ─── Legal ─────────────────────────────────────────────────────────────────
  Future<void> acceptLegal() async => await post('/users/accept-legal', {});

  // ─── Account ───────────────────────────────────────────────────────────────
  Future<void> deleteAccount() async => await delete('/users/me');
  Future<dynamic> exportMyData() async => await get('/users/me/export');

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
    final result = await post('/mood', {
      'score': score,
      'label': label,
      if (note != null) 'note': note,
      if (factors != null) 'factors': factors,
      if (energyLevel != null) 'energyLevel': energyLevel,
    });
    invalidateMultipleCache(['/mood/today', '/mood/history', '/mood/insights']);
    return result;
  }

  Future<Map<String, dynamic>> getTodayMood() async => await get('/mood/today');
  Future<Map<String, dynamic>> getMoodHistory({int days = 7}) async =>
      await get('/mood/history', queryParams: {'days': days.toString()});
  Future<Map<String, dynamic>> getMoodInsights() async =>
      await get('/mood/insights');

  // ─── Challenges ────────────────────────────────────────────────────────────
  Future<List<dynamic>> getDailyChallenges({String? moodLabel}) async {
    final result = await get('/challenges/daily',
        queryParams: moodLabel != null ? {'moodLabel': moodLabel} : null);
    
    // Si le résultat est déjà une liste, le retourner
    if (result is List) {
      return result;
    }
    // Si le résultat est un Map avec une clé 'challenges', l'extraire
    if (result is Map && result.containsKey('challenges')) {
      final challenges = result['challenges'];
      if (challenges is List) {
        return challenges;
      }
    }
    // Sinon, retourner une liste vide
    return [];
  }

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
    final result = await post('/challenges/$challengeId/complete', body);
    invalidateMultipleCache(['/challenges/daily', '/challenges', '/challenges/$challengeId']);
    return result;
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
  Future<List<dynamic>> getFeed({
    int page = 1,
    int limit = 20,
    String? type,
    String sort = 'recent',
    bool forceRefresh = false,
  }) async {
    final Map<String, String> params = {
      'page': page.toString(),
      'limit': limit.toString(),
      'sort': sort,
    };
    if (type != null && type.isNotEmpty) params['postType'] = type;
    final result = await get('/community/feed', queryParams: params, forceRefresh: forceRefresh);
    
    if (result is List) return result;
    if (result is Map && result.containsKey('feed')) {
      final feed = result['feed'];
      if (feed is List) return feed;
    }
    if (result is Map && result.containsKey('posts')) {
      final posts = result['posts'];
      if (posts is List) return posts;
    }
    return [];
  }

  Future<List<dynamic>> getMyPosts(
      {int page = 1, int limit = 20, bool forceRefresh = false}) async {
    final result = await get('/community/my-posts', queryParams: {
      'page': page.toString(),
      'limit': limit.toString(),
    }, forceRefresh: forceRefresh);
    
    if (result is List) return result;
    if (result is Map && result.containsKey('posts')) {
      final posts = result['posts'];
      if (posts is List) return posts;
    }
    return [];
  }

  Future<Map<String, dynamic>> createPost({
    required String content,
    String postType = 'general',
    bool isAnonymous = false,
    int? moodScore,
    String? moodEmoji,
  }) async {
    final result = await post('/community/posts', {
      'content': content,
      'postType': postType,
      'isAnonymous': isAnonymous,
      if (moodScore != null) 'moodScore': moodScore,
      if (moodEmoji != null) 'moodEmoji': moodEmoji,
    });
    invalidateMultipleCache(['/community/feed', '/community/my-posts']);
    return result;
  }

  Future<Map<String, dynamic>> editPost(String postId, String content) async {
    final result = await patch('/community/posts/$postId', {'content': content});
    invalidateMultipleCache(['/community/feed', '/community/my-posts', '/community/posts/$postId']);
    return result;
  }

  Future<Map<String, dynamic>> toggleLike(String postId) async {
    final result = await post('/community/posts/$postId/like', {});
    invalidateMultipleCache(['/community/feed', '/community/my-posts']);
    return result;
  }

  Future<Map<String, dynamic>> toggleSameFeeling(String postId) async {
    final result = await post('/community/posts/$postId/same-feeling', {});
    invalidateMultipleCache(['/community/feed', '/community/my-posts']);
    return result;
  }

  Future<void> deletePost(String postId) async {
    await delete('/community/posts/$postId');
    invalidateMultipleCache(['/community/feed', '/community/my-posts']);
  }

  Future<Map<String, dynamic>> toggleReaction(String postId, String type) async {
    final result = await post('/community/posts/$postId/react', {'type': type});
    invalidateMultipleCache(['/community/feed', '/community/my-posts']);
    return result;
  }

  Future<Map<String, dynamic>> searchPosts(String query, {String? postType}) async =>
      await get('/community/search',
          queryParams: {'q': query, if (postType != null) 'type': postType});

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
  Future<void> clearAllNotifications() async => await delete('/notifications');
  Future<void> registerFcmToken(String token) async =>
      await post('/notifications/fcm-token', {'token': token});

  // ─── Professionals ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfessionals({
    String? type,
    String? city,
    String? search,
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final Map<String, String> params = {
      'page': page.toString(),
      'limit': limit.toString()
    };
    if (type != null) params['type'] = type;
    if (city != null) params['city'] = city;
    if (search != null) params['search'] = search;
    return await get('/professionals', queryParams: params, forceRefresh: forceRefresh);
  }

  Future<Map<String, dynamic>> getProfessional(String id) async =>
      await get('/professionals/$id');

  Future<Map<String, dynamic>> bookProfessional({
    required String professionalId,
    required String message,
    String? preferredDate,
    String? consultationType,
  }) async {
    final result = await post('/professionals/$professionalId/book', {
      'message': message,
      if (preferredDate != null) 'preferredDate': preferredDate,
      if (consultationType != null) 'consultationType': consultationType,
    });
    invalidateCache('/professionals/bookings/me');
    return result;
  }

  Future<Map<String, dynamic>> getMyBookings({bool forceRefresh = false}) async =>
      await get('/professionals/bookings/me', forceRefresh: forceRefresh);

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
    final result = await put('/professionals/bookings/$bookingId', data);
    invalidateCache('/professionals/bookings/me');
    return result;
  }

  Future<void> cancelBooking(String bookingId) async {
    await delete('/professionals/bookings/$bookingId');
    invalidateCache('/professionals/bookings/me');
  }

  // ─── User ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMe({bool forceRefresh = false}) async {
    final result = await get('/users/me', forceRefresh: forceRefresh);
    
    // 🔍 DEBUG
    if (kDebugMode) {
      debugPrint('📦 getMe result type: ${result.runtimeType}');
      if (result is Map) {
        debugPrint('📦 getMe keys: ${(result as Map).keys}');
      }
    }
    
    // Si le résultat est déjà un Map, le retourner
    if (result is Map<String, dynamic>) {
      return result;
    }
    
    // Si le résultat est un Map mais pas typé, le convertir
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    
    // Sinon, retourner un Map vide
    return {};
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final result = await patch('/users/me', data);
    invalidateCache('/users/me');
    return result;
  }

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
    try { await delete('/assistant/session'); } catch (_) {}
  }

  // ─── Content ───────────────────────────────────────────────────────────────
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
  Future<Map<String, dynamic>> getLanguages() async =>
      await get('/content/languages');
  Future<Map<String, dynamic>> getProfessionalTypes() async =>
      await get('/content/professional-types');
  Future<Map<String, dynamic>> getChallengeCategories() async =>
      await get('/content/challenge-categories');
  Future<Map<String, dynamic>> getChallengeDifficulties() async =>
      await get('/content/challenge-difficulties');
  Future<Map<String, dynamic>> getPostTypes() async =>
      await get('/content/post-types');
}