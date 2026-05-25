import 'dart:convert';
 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
 
import '/models/setup_suggestion.dart';
 
/// Stores per-account circuit setup overrides in secure storage.
///
/// Key: setup_overrides_{email}
/// Value: JSON map of { "fr": { ride, wing, suspension, pit }, ... }
///
/// Only circuits that have been customised are stored.
/// Un-overridden circuits fall back to SetupSuggestion defaults.
class SetupOverridesStorage {
  final FlutterSecureStorage _storage;
 
  SetupOverridesStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
 
  String _key(String email) => 'setup_overrides_$email';
 
  // ─── Read ──────────────────────────────────────────────────
 
  Future<Map<String, CircuitSetup>> getOverrides(String email) async {
    try {
      final raw = await _storage.read(key: _key(email));
      if (raw == null || raw.isEmpty) return {};
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json.map(
        (code, data) => MapEntry(
          code,
          CircuitSetup.fromJson(data as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }
 
  /// Returns base + overrides merged — ready to use for suggestions.
  Future<Map<String, CircuitSetup>> getAllCircuits(String email) async {
    final overrides = await getOverrides(email);
    return SetupSuggestion.allCircuits(accountOverrides: overrides);
  }
 
  // ─── Write ─────────────────────────────────────────────────
 
  Future<void> setOverride(
    String       email,
    String       trackCode,
    CircuitSetup setup,
  ) async {
    final current = await getOverrides(email);
    current[trackCode.toLowerCase()] = setup;
    await _save(email, current);
  }
 
  Future<void> removeOverride(String email, String trackCode) async {
    final current = await getOverrides(email);
    current.remove(trackCode.toLowerCase());
    await _save(email, current);
  }
 
  Future<void> clearOverrides(String email) async {
    await _storage.delete(key: _key(email));
  }
 
  Future<void> _save(
    String email,
    Map<String, CircuitSetup> overrides,
  ) async {
    final json = overrides.map((k, v) => MapEntry(k, v.toJson()));
    await _storage.write(key: _key(email), value: jsonEncode(json));
  }
}