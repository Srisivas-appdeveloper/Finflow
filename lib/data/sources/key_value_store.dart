import 'package:shared_preferences/shared_preferences.dart';

/// Minimal persistence for small preference values.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
}

/// [KeyValueStore] backed by the platform's shared preferences.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore._(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static Future<SharedPreferencesStore> create({
    required Set<String> allowList,
  }) async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(allowList: allowList),
    );
    return SharedPreferencesStore._(prefs);
  }

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}

/// Non-persistent [KeyValueStore] for tests and previews.
class InMemoryStore implements KeyValueStore {
  InMemoryStore([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;
}
