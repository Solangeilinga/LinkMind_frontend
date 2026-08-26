import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/theme.dart';

/// Service API isolé pour l'espace professionnel (psychologues partenaires).
///
/// Volontairement séparé de `ApiService` (comptes utilisateurs classiques) :
/// les deux systèmes d'authentification utilisent des JWT de nature
/// différente (`type: 'professional'` vs utilisateur classique), stockés
/// sous des clés distinctes, pour éviter tout risque d'écrasement mutuel si
/// les deux sessions coexistaient sur le même appareil.
class ProApiService {
  static final ProApiService _instance = ProApiService._internal();
  factory ProApiService() => _instance;
  ProApiService._internal();

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'pro_access_token';
  String? _token;

  Future<String?> _getToken() async {
    if (_token != null) return _token;
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (e, stack) {
      debugPrint('🔴 [ProApi] _getToken: ÉCHEC lecture stockage sécurisé : $e');
      debugPrint('🔴 [ProApi] _getToken: stack:\n$stack');
      return null; // ne bloque jamais l'app pour une lecture ratée
    }
    return _token;
  }

  Future<void> _setToken(String token) async {
    _token = token;
    try {
      debugPrint('🔎 [ProApi] _setToken: écriture dans le stockage sécurisé...');
      await _storage.write(key: _tokenKey, value: token);
      debugPrint('🔎 [ProApi] _setToken: écriture réussie');
    } catch (e, stack) {
      debugPrint('🔴 [ProApi] _setToken: ÉCHEC écriture stockage sécurisé : $e');
      debugPrint('🔴 [ProApi] _setToken: stack:\n$stack');
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> isLoggedIn() async => (await _getToken()) != null;

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _handle(http.Response res) {
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401) {
      // Session pro expirée/invalide — on efface le token pour forcer un
      // nouveau login plutôt que de laisser l'app dans un état incohérent.
      logout();
    }
    throw Exception(body['error'] ?? 'Erreur réseau (${res.statusCode})');
  }

  // ── Authentification ────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    debugPrint('🔎 [ProApi] login: envoi de la requête HTTP...');
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/professionals/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    debugPrint('🔎 [ProApi] login: réponse reçue, code ${res.statusCode}');
    final data = _handle(res);
    debugPrint('🔎 [ProApi] login: _handle OK, token présent = ${data['token'] != null}');
    await _setToken(data['token'] as String);
    debugPrint('🔎 [ProApi] login: token enregistré avec succès');
  }

  Future<void> setupPassword(String setupToken, String newPassword) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/professionals/auth/setup-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': setupToken, 'newPassword': newPassword}),
    );
    final data = _handle(res);
    await _setToken(data['token'] as String);
  }

  /// Ne lève jamais d'erreur côté UI : le backend renvoie volontairement le
  /// même message que l'email existe ou non (anti-énumération de comptes).
  Future<void> forgotPassword(String email) async {
    await http.post(
      Uri.parse('${AppConstants.baseUrl}/professionals/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  // ── Profil & rendez-vous ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/professionals/me'),
      headers: await _headers(),
    );
    return _handle(res) as Map<String, dynamic>;
  }

  /// Types de professionnels réellement configurés en base — jamais figés en
  /// dur, pour qu'un nouveau type ajouté côté admin apparaisse automatiquement.
  Future<List<dynamic>> getProfessionalTypes() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/types'),
      headers: await _headers(),
    );
    final data = _handle(res);
    return (data['types'] as List<dynamic>?) ?? [];
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    final res = await http.put(
      Uri.parse('${AppConstants.baseUrl}/professionals/me'),
      headers: await _headers(),
      body: jsonEncode(fields),
    );
    _handle(res);
  }

  Future<List<dynamic>> getBookings({String? status}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/professionals/me/bookings')
        .replace(queryParameters: status != null ? {'status': status} : null);
    final res = await http.get(uri, headers: await _headers());
    final data = _handle(res);
    return (data['bookings'] as List<dynamic>?) ?? [];
  }

  Future<void> confirmBooking(String bookingId) async {
    final res = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/bookings/$bookingId/confirm'),
      headers: await _headers(),
    );
    _handle(res);
  }

  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    final res = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/bookings/$bookingId/cancel'),
      headers: await _headers(),
      body: jsonEncode({if (reason != null) 'reason': reason}),
    );
    _handle(res);
  }

  Future<void> completeBooking(String bookingId) async {
    final res = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/bookings/$bookingId/complete'),
      headers: await _headers(),
    );
    _handle(res);
  }

  Future<void> updateSlots(List<Map<String, dynamic>> slots) async {
    final res = await http.put(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/slots'),
      headers: await _headers(),
      body: jsonEncode({'slots': slots}),
    );
    _handle(res);
  }

  Future<void> addSlot({required String date, required String startTime, required String endTime}) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/slots'),
      headers: await _headers(),
      body: jsonEncode({'date': date, 'startTime': startTime, 'endTime': endTime}),
    );
    _handle(res);
  }

  Future<void> deleteSlot(String slotId) async {
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/slots/$slotId'),
      headers: await _headers(),
    );
    _handle(res);
  }

  // ── Communauté (identifié, badge visible) ───────────────────────────────

  Future<List<dynamic>> getCommunityFeed({int page = 1, String? postType}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/professionals/me/community/feed')
        .replace(queryParameters: {
      'page': page.toString(),
      if (postType != null) 'postType': postType,
    });
    final res = await http.get(uri, headers: await _headers());
    final data = _handle(res);
    return (data['posts'] as List<dynamic>?) ?? [];
  }

  Future<List<dynamic>> getMyCommunityPosts({int page = 1}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/professionals/me/community/my-posts')
        .replace(queryParameters: {'page': page.toString()});
    final res = await http.get(uri, headers: await _headers());
    final data = _handle(res);
    return (data['posts'] as List<dynamic>?) ?? [];
  }

  Future<List<dynamic>> searchCommunityPosts(String query, {String? postType}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/professionals/me/community/search')
        .replace(queryParameters: {
      'q': query,
      if (postType != null) 'type': postType,
    });
    final res = await http.get(uri, headers: await _headers());
    final data = _handle(res);
    return (data['posts'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createCommunityPost(String content, {String postType = 'tip'}) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/community/posts'),
      headers: await _headers(),
      body: jsonEncode({'content': content, 'postType': postType}),
    );
    final data = _handle(res);
    return data['post'] as Map<String, dynamic>;
  }

  Future<void> addCommunityComment(String postId, String content, {String? parentCommentId}) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/community/posts/$postId/comments'),
      headers: await _headers(),
      body: jsonEncode({'content': content, if (parentCommentId != null) 'parentCommentId': parentCommentId}),
    );
    _handle(res);
  }

  Future<Map<String, dynamic>> toggleReaction(String postId, String type) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/community/posts/$postId/react'),
      headers: await _headers(),
      body: jsonEncode({'type': type}),
    );
    return _handle(res) as Map<String, dynamic>;
  }

  Future<bool> toggleSameFeeling(String postId) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/community/posts/$postId/same-feeling'),
      headers: await _headers(),
    );
    final data = _handle(res) as Map<String, dynamic>;
    return data['sameFeeling'] == true;
  }

  Future<List<dynamic>> getComments(String postId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/community/posts/$postId/comments'),
      headers: await _headers(),
    );
    final data = _handle(res) as Map<String, dynamic>;
    return data['comments'] as List<dynamic>? ?? [];
  }

  Future<void> toggleCommentLike(String postId, String commentId) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/community/posts/$postId/comments/$commentId/like'),
      headers: await _headers(),
    );
    _handle(res);
  }

  Future<void> deleteCommunityPost(String postId) async {
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/community/posts/$postId'),
      headers: await _headers(),
    );
    _handle(res);
  }

  Future<void> deleteCommunityComment(String commentId) async {
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/professionals/me/community/comments/$commentId'),
      headers: await _headers(),
    );
    _handle(res);
  }
}