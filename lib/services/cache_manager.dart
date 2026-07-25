import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Cache en deux couches :
///   1. Mémoire (Map) — accès instantané, perdu au restart
///   2. Hive (disque) — persiste entre les sessions, pour les données
///      qui changent peu souvent (feed communauté, contenu, professionnels)
///
/// Clés persistées par défaut : celles qui commencent par les préfixes
/// dans [_persistedPrefixes]. Tout le reste reste en mémoire uniquement.

class ApiCacheEntry<T> {
  final T        data;
  final DateTime timestamp;
  final Duration expiry;

  ApiCacheEntry({required this.data, required this.expiry})
      : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > expiry;

  Map<String, dynamic> toJson() => {
    'data':      jsonEncode(data),
    'timestamp': timestamp.millisecondsSinceEpoch,
    'expiryMs':  expiry.inMilliseconds,
  };

  static ApiCacheEntry<T> fromJson<T>(Map<String, dynamic> j) {
    return ApiCacheEntry<T>(
      data:   jsonDecode(j['data'] as String) as T,
      expiry: Duration(milliseconds: j['expiryMs'] as int),
    )..timestamp; // timestamp est set par le constructeur — on le corrige ci-dessous
  }
}

// Contournement : timestamp immutable → sous-classe interne
class _RestoredEntry<T> extends ApiCacheEntry<T> {
  final DateTime _ts;
  _RestoredEntry(T data, Duration expiry, this._ts)
      : super(data: data, expiry: expiry);
  @override
  DateTime get timestamp => _ts;
}

class ApiCacheManager {
  static final ApiCacheManager _instance = ApiCacheManager._internal();
  factory ApiCacheManager() => _instance;
  ApiCacheManager._internal();

  static const _boxName = 'api_cache';
  static const _persistedPrefixes = [
    '/community/',
    '/professionals',
    '/content/',
    '/ads',
  ];

  final Map<String, ApiCacheEntry> _memory = {};
  Box? _box;

  // ── Init (appeler une fois au démarrage) ──────────────────────────────────
  Future<void> init() async {
    try {
      _box = await Hive.openBox(_boxName);
      _evictExpiredFromDisk();
    } catch (e) {
      debugPrint('⚠️ Hive cache init failed: $e');
    }
  }

  bool get _diskReady => _box != null && _box!.isOpen;

  bool _shouldPersist(String key) =>
      _persistedPrefixes.any((p) => key.startsWith(p));

  // ── Get ───────────────────────────────────────────────────────────────────
  T? get<T>(String key) {
    // 1. Mémoire d'abord
    final mem = _memory[key];
    if (mem != null) {
      if (mem.isExpired) {
        _memory.remove(key);
        _removeFromDisk(key);
      } else {
        return mem.data as T?;
      }
    }

    // 2. Disque (Hive)
    if (_diskReady && _shouldPersist(key)) {
      try {
        final raw = _box!.get(key);
        if (raw != null) {
          final j = Map<String, dynamic>.from(raw as Map);
          final ts = DateTime.fromMillisecondsSinceEpoch(j['timestamp'] as int);
          final expiry = Duration(milliseconds: j['expiryMs'] as int);
          if (DateTime.now().difference(ts) > expiry) {
            _box!.delete(key);
            return null;
          }
          final data = jsonDecode(j['data'] as String) as T;
          // Remettre en mémoire pour les prochains accès
          _memory[key] = _RestoredEntry<T>(data, expiry, ts);
          return data;
        }
      } catch (e) {
        debugPrint('⚠️ Hive read error for $key: $e');
      }
    }

    return null;
  }

  // ── Set ───────────────────────────────────────────────────────────────────
  void set<T>(String key, T data,
      {Duration expiry = const Duration(minutes: 5)}) {
    final entry = ApiCacheEntry<T>(data: data, expiry: expiry);
    _memory[key] = entry;

    if (_diskReady && _shouldPersist(key)) {
      try {
        _box!.put(key, {
          'data':      jsonEncode(data),
          'timestamp': entry.timestamp.millisecondsSinceEpoch,
          'expiryMs':  expiry.inMilliseconds,
        });
      } catch (e) {
        debugPrint('⚠️ Hive write error for $key: $e');
      }
    }
  }

  // ── Invalidation ──────────────────────────────────────────────────────────
  void clear(String key) {
    _memory.remove(key);
    _removeFromDisk(key);
  }

  void clearAll() {
    _memory.clear();
    _box?.clear().catchError((_) {});
  }

  void invalidateWhere(bool Function(String key) predicate) {
    final keys = _memory.keys.where(predicate).toList();
    for (final k in keys) _memory.remove(k);
    if (_diskReady) {
      final diskKeys = _box!.keys.cast<String>().where(predicate).toList();
      for (final k in diskKeys) _box!.delete(k);
    }
  }

  void invalidatePattern(String pattern) =>
      invalidateWhere((k) => k.startsWith(pattern));

  // ── Stats ─────────────────────────────────────────────────────────────────
  Map<String, dynamic> getStats() {
    int expired = 0;
    for (final e in _memory.values) {
      if (e.isExpired) expired++;
    }
    return {
      'memory_total':   _memory.length,
      'memory_expired': expired,
      'memory_valid':   _memory.length - expired,
      'disk_keys':      _diskReady ? _box!.length : 0,
    };
  }

  // ── Privé ─────────────────────────────────────────────────────────────────
  void _removeFromDisk(String key) {
    if (_diskReady) _box!.delete(key).catchError((_) {});
  }

  void _evictExpiredFromDisk() {
    if (!_diskReady) return;
    final toDelete = <String>[];
    for (final key in _box!.keys.cast<String>()) {
      try {
        final raw = _box!.get(key) as Map?;
        if (raw == null) { toDelete.add(key); continue; }
        final ts     = DateTime.fromMillisecondsSinceEpoch(raw['timestamp'] as int);
        final expiry = Duration(milliseconds: raw['expiryMs'] as int);
        if (DateTime.now().difference(ts) > expiry) toDelete.add(key);
      } catch (_) {
        toDelete.add(key);
      }
    }
    for (final k in toDelete) _box!.delete(k);
    if (toDelete.isNotEmpty) {
      debugPrint('🗑️ Hive: ${toDelete.length} entrées expirées supprimées');
    }
  }
}