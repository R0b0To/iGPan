import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';

/// Stores and retrieves session metadata per account.
///
/// Does NOT store cookies — those are owned by the per-account
/// PersistCookieJar inside HttpClient.
///
/// Storage keys:
///   session_{email}     → Session JSON (expiresAt, createdAt)
///   credential_{email}  → password (for re-login)
class SessionManager {
  final FlutterSecureStorage _storage;

  SessionManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // ─── Keys ─────────────────────────────────────────────────

  String _sessionKey(String email)    => 'session_$email';
  String _credentialKey(String email) => 'credential_$email';

  // ─── Session metadata ─────────────────────────────────────

  Future<void> saveSession(String email, Session session) async {
    debugPrint('[SessionManager] Saving session for $email');
    await _storage.write(
      key:   _sessionKey(email),
      value: jsonEncode(session.toJson()),
    );
  }

  Future<Session?> getSession(String email) async {
    try {
      final raw = await _storage.read(key: _sessionKey(email));
      if (raw == null) return null;
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[SessionManager] Error loading session for $email: $e');
      return null;
    }
  }

  Future<bool> isSessionValid(String email) async {
    final session = await getSession(email);
    return session != null && session.isValid;
  }

  Future<void> clearSession(String email) async {
    debugPrint('[SessionManager] Clearing session for $email');
    await _storage.delete(key: _sessionKey(email));
  }

  // ─── Credentials (for re-login) ───────────────────────────

  Future<void> saveCredential(String email, String password) async {
    await _storage.write(
      key:   _credentialKey(email),
      value: password,
    );
  }

  Future<String?> getCredential(String email) async {
    return _storage.read(key: _credentialKey(email));
  }

  Future<void> clearCredential(String email) async {
    await _storage.delete(key: _credentialKey(email));
  }

  // ─── Bulk ─────────────────────────────────────────────────

  /// Returns emails of all accounts that have a valid, non-expired session.
  Future<List<String>> getValidSessionEmails() async {
    final all = await _storage.readAll();
    final validEmails = <String>[];

    for (final entry in all.entries) {
      if (!entry.key.startsWith('session_')) continue;
      try {
        final session = Session.fromJson(
          jsonDecode(entry.value) as Map<String, dynamic>,
        );
        if (session.isValid) {
          validEmails.add(entry.key.replaceFirst('session_', ''));
        }
      } catch (_) {
        // Corrupted entry — skip
      }
    }

    return validEmails;
  }

  /// Clears session and credential for an account (full logout).
  Future<void> clearAll(String email) async {
    await clearSession(email);
    await clearCredential(email);
  }
}
