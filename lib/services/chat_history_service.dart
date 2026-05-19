import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service pour gérer l'historique du chatbot et les infos utilisateur
class ChatHistoryService {
  static const String _historyKey = 'chat_history';
  static const String _userContextKey = 'chat_user_context';
  static const String _maxMessagesKey = 'chat_max_messages';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  /// Ajoute un message à l'historique
  Future<void> addMessage(String role, String content,
      {Map<String, dynamic>? metadata}) async {
    await init();
    final history = await getHistory();

    history.add({
      'role': role, // 'user' ou 'assistant'
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'metadata': metadata ?? {},
    });

    // Conserver les 50 derniers messages pour limiter la taille
    final recentHistory =
        history.length > 50 ? history.sublist(history.length - 50) : history;

    await _prefs.setString(_historyKey, jsonEncode(recentHistory));
  }

  /// Récupère l'historique complet
  Future<List<Map<String, dynamic>>> getHistory() async {
    await init();
    final encoded = _prefs.getString(_historyKey);
    if (encoded == null) return [];

    final List<dynamic> decoded = jsonDecode(encoded);
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Récupère les N derniers messages pour le contexte
  Future<List<Map<String, dynamic>>> getRecentMessages(int count) async {
    final history = await getHistory();
    if (history.isEmpty) return [];

    return history.length <= count
        ? history
        : history.sublist(history.length - count);
  }

  /// Efface l'historique
  Future<void> clearHistory() async {
    await init();
    await _prefs.remove(_historyKey);
  }

  /// Sauvegarde le contexte utilisateur (infos persistantes)
  Future<void> updateUserContext(Map<String, dynamic> context) async {
    await init();

    // Fusionner avec le contexte existant
    final existing = await getUserContext();
    final merged = {...existing, ...context};

    await _prefs.setString(_userContextKey, jsonEncode(merged));
  }

  /// Récupère le contexte utilisateur persistant
  Future<Map<String, dynamic>> getUserContext() async {
    await init();
    final encoded = _prefs.getString(_userContextKey);
    if (encoded == null) return {};

    return Map<String, dynamic>.from(jsonDecode(encoded));
  }

  /// Efface le contexte utilisateur
  Future<void> clearUserContext() async {
    await init();
    await _prefs.remove(_userContextKey);
  }

  /// Récupère le nombre total de messages stock
  Future<int> getTotalMessagesCount() async {
    final history = await getHistory();
    return history.length;
  }

  /// Export l'historique au format JSON
  Future<String> exportHistory() async {
    final history = await getHistory();
    final context = await getUserContext();

    return jsonEncode({
      'exported_at': DateTime.now().toIso8601String(),
      'messages_count': history.length,
      'user_context': context,
      'messages': history,
    });
  }
}
