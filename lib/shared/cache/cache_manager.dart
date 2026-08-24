import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Redis-style local cache with TTL, tag-based invalidation,
/// and SharedPreferences persistence.
class CacheManager {
  CacheManager._();

  static final CacheManager instance = CacheManager._();

  SharedPreferences? _prefs;

  // ── In-memory store ──
  final Map<String, CacheEntry> _memory = {};

  // ── Tag index: tag → set of keys ──
  final Map<String, Set<String>> _tagIndex = {};

  static const String _prefPrefix = 'cache:';

  /// Must be called once before use.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _rebuildTagIndex();
    invalidate(CacheTags.patients);
    invalidate(CacheTags.appointments);
  }

  void _rebuildTagIndex() {
    _tagIndex.clear();
    final keys = _prefs?.getKeys() ?? {};
    for (final key in keys) {
      if (key.startsWith(_prefPrefix)) {
        final raw = _prefs?.getString(key);
        if (raw == null) continue;
        final tags = _loadTags(raw);
        for (final tag in tags) {
          _tagIndex.putIfAbsent(tag, () => {}).add(key);
        }
      }
    }
  }

  List<String> _loadTags(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (map['t'] as List?)?.cast<String>() ?? [];
    } catch (_) {
      return [];
    }
  }

  // ── Core API ──

  /// Retrieve a cached value. Returns `null` if expired or missing.
  T? get<T>(String key) {
    // Try memory first
    final mem = _memory[key];
    if (mem != null) {
      if (!mem.isExpired) return mem.value as T;
      _memory.remove(key);
    }

    // Try SharedPreferences
    final raw = _prefs?.getString(_prefPrefix + key);
    if (raw == null) return null;
    try {
      final entry = CacheEntry.fromJson(raw);
      if (entry.isExpired) {
        _prefs?.remove(_prefPrefix + key);
        return null;
      }
      // Promote to memory
      _memory[key] = entry;
      return entry.value as T;
    } catch (_) {
      _prefs?.remove(_prefPrefix + key);
      return null;
    }
  }

  /// Store a value in cache.
  Future<void> set<T>(
    String key,
    T value, {
    Duration ttl = const Duration(minutes: 5),
    List<String> tags = const [],
    bool persist = true,
  }) async {
    final entry = CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
      tags: tags,
    );

    _memory[key] = entry;

    if (persist && _prefs != null) {
      await _prefs!.setString(_prefPrefix + key, entry.toJson());
    }

    // Update tag index
    for (final tag in tags) {
      _tagIndex
          .putIfAbsent(tag, () => {})
          .add(persist ? _prefPrefix + key : key);
    }
  }

  /// Invalidate all entries tagged with [tag].
  void invalidate(String tag) {
    final keys = _tagIndex[tag];
    if (keys == null || keys.isEmpty) return;

    for (final fullKey in keys) {
      final shortKey = fullKey.startsWith(_prefPrefix)
          ? fullKey.substring(_prefPrefix.length)
          : fullKey;
      _memory.remove(shortKey);
      _prefs?.remove(fullKey);
    }
    _tagIndex.remove(tag);
  }

  /// Invalidate multiple tags at once.
  void invalidateTags(List<String> tags) {
    for (final tag in tags) {
      invalidate(tag);
    }
  }

  /// Clear entire cache.
  Future<void> invalidateAll() async {
    _memory.clear();
    _tagIndex.clear();
    if (_prefs == null) return;
    final keys = _prefs!
        .getKeys()
        .where((k) => k.startsWith(_prefPrefix))
        .toList();
    for (final k in keys) {
      await _prefs!.remove(k);
    }
  }

  /// Remove a specific key from cache.
  void remove(String key) {
    _memory.remove(key);
    _prefs?.remove(_prefPrefix + key);
  }
}

// ── Cache entry ──

class CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  final List<String> tags;

  CacheEntry({
    required this.value,
    required this.expiresAt,
    this.tags = const [],
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory CacheEntry.fromJson(String raw) {
    final map = _safeDecode(raw);
    return CacheEntry(
      value: map['v'],
      expiresAt: DateTime.tryParse(map['e'] as String? ?? '') ?? DateTime.now(),
      tags: (map['t'] as List?)?.cast<String>() ?? [],
    );
  }

  String toJson() {
    return jsonEncode({
      'v': value,
      'e': expiresAt.toIso8601String(),
      't': tags,
    });
  }

  static Map<String, dynamic> _safeDecode(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

// ── Predefined cache tags ──

class CacheTags {
  static const patients = 'patients';
  static const appointments = 'appointments';
  static const products = 'products';
  static const orders = 'orders';
  static const catalog = 'catalog';
  static const banners = 'banners';
  static const categories = 'categories';
}
