import 'package:flutter/foundation.dart';

/// 🚀 API Response Cache Manager
/// Réduit requêtes réseau & améliore performance
/// Expiry par défaut: 5 minutes

class ApiCacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration expiry;

  ApiCacheEntry({
    required this.data,
    required this.expiry,
  }) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > expiry;
}

class ApiCacheManager {
  static final ApiCacheManager _instance = ApiCacheManager._internal();

  factory ApiCacheManager() => _instance;
  ApiCacheManager._internal();

  final Map<String, ApiCacheEntry> _cache = {};

  /// Get cached data if valid, otherwise null
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      debugPrint('🗑️ Cache expired: $key');
      return null;
    }

    debugPrint('✅ Cache hit: $key');
    return entry.data as T;
  }

  /// Set cache entry
  void set<T>(String key, T data,
      {Duration expiry = const Duration(minutes: 5)}) {
    _cache[key] = ApiCacheEntry<T>(data: data, expiry: expiry);
    debugPrint('💾 Cached: $key (expires in ${expiry.inSeconds}s)');
  }

  /// Clear specific cache
  void clear(String key) {
    _cache.remove(key);
    debugPrint('🗑️ Cleared cache: $key');
  }

  /// Clear all cache
  void clearAll() {
    _cache.clear();
    debugPrint('🗑️ Cleared all cache');
  }

  /// ✅ Invalider toutes les entrées dont la clé commence par un pattern
  void invalidateWhere(bool Function(String key) predicate) {
    final keysToRemove = _cache.keys.where(predicate).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
      debugPrint('🗑️ Cache invalidated: $key');
    }
  }

  /// ✅ Invalider toutes les entrées qui correspondent à un pattern (wildcard)
  void invalidatePattern(String pattern) {
    invalidateWhere((key) => key.startsWith(pattern));
  }

  /// Get cache stats
  Map<String, dynamic> getStats() {
    int expired = 0;
    for (var entry in _cache.values) {
      if (entry.isExpired) expired++;
    }
    return {
      'total': _cache.length,
      'expired': expired,
      'valid': _cache.length - expired,
    };
  }
}