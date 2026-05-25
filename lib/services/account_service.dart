import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/exceptions.dart';
import '../core/session_manager.dart';
import '../models/account.dart';
import '../network/http_client.dart';
import '../services/auth_service.dart';

/// Manages the persisted list of accounts.
///
/// Storage:
///   account_list → JSON array of Account objects (emails + nicknames only,
///                  no passwords — those live under credential_{email})
///
/// Passwords are stored separately via SessionManager.saveCredential so
/// the account list itself never contains plaintext passwords at rest.
class AccountService {
  final FlutterSecureStorage _storage;
  final SessionManager       _sessionManager;
  final AuthService          _authService;
  final HttpClient           _httpClient;

  static const _listKey = 'account_list';

  AccountService({
    FlutterSecureStorage? storage,
    SessionManager?       sessionManager,
    AuthService?          authService,
    HttpClient?           httpClient,
  })  : _storage        = storage        ?? const FlutterSecureStorage(),
        _sessionManager = sessionManager ?? SessionManager(),
        _authService    = authService    ?? AuthService(),
        _httpClient     = httpClient     ?? HttpClient();

  // ─── Read ─────────────────────────────────────────────────

  /// Returns all stored accounts (enabled and disabled).
  Future<List<Account>> getAccounts() async {
    try {
      final raw = await _storage.read(key: _listKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[AccountService] Error loading accounts: $e');
      return [];
    }
  }

  /// Returns only enabled accounts.
  Future<List<Account>> getEnabledAccounts() async {
    final all = await getAccounts();
    return all.where((a) => a.enabled).toList();
  }

  // ─── Write ────────────────────────────────────────────────

  Future<void> _saveAccounts(List<Account> accounts) async {
    // Strip passwords before writing the list — they live in credential_{email}
    final withoutPasswords = accounts
        .map((a) => a.copyWith(password: ''))
        .toList();
    await _storage.write(
      key:   _listKey,
      value: jsonEncode(withoutPasswords.map((a) => a.toJson()).toList()),
    );
  }

  // ─── Add ──────────────────────────────────────────────────

  /// Login and add a new account.
  ///
  /// Throws [LoginFailedException] if credentials are wrong.
  /// Throws [ApiException] if the account already exists.
  Future<Account> addAccount({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final existing = await getAccounts();
    if (existing.any((a) => a.email == email)) {
      throw ApiException('Account $email already exists');
    }

    // Login first — this validates credentials and captures the cookie
    await _sessionManager.clearAll(email);
    await _httpClient.deleteCookiesFor(email);
    // small delay to ensure clean state before login (especially cookie deletion)
    await Future.delayed(const Duration(milliseconds: 100));
    await _authService.login(email, password);

    final account = Account(
      email:    email,
      password: password,
      nickname: nickname.isEmpty ? email : nickname,
      enabled:  true,
    );

    await _saveAccounts([...existing, account]);
    debugPrint('[AccountService] Added account: ${account.nickname}');
    return account;
  }

  // ─── Delete ───────────────────────────────────────────────

  /// Remove an account and wipe all its data.
  Future<void> deleteAccount(String email) async {
    final accounts = await getAccounts();
    await _saveAccounts(accounts.where((a) => a.email != email).toList());

    // Wipe session metadata, stored credential, and cookies
    await _sessionManager.clearAll(email);
    await _httpClient.deleteCookiesFor(email);

    debugPrint('[AccountService] Deleted account: $email');
  }

  // ─── Enable / disable ─────────────────────────────────────

  Future<void> setEnabled(String email, {required bool enabled}) async {
    final accounts = await getAccounts();
    final updated  = accounts.map((a) {
      return a.email == email ? a.copyWith(enabled: enabled) : a;
    }).toList();
    await _saveAccounts(updated);
    debugPrint('[AccountService] ${enabled ? "Enabled" : "Disabled"} $email');
  }

  // ─── Rename ───────────────────────────────────────────────

  Future<void> renameAccount(String email, String newNickname) async {
    final accounts = await getAccounts();
    final updated  = accounts.map((a) {
      return a.email == email ? a.copyWith(nickname: newNickname) : a;
    }).toList();
    await _saveAccounts(updated);
  }

  // ─── Reorder ──────────────────────────────────────────────

  /// Persist a reordered list (from drag-and-drop in UI).
  Future<void> reorderAccounts(List<Account> reordered) async {
    await _saveAccounts(reordered);
  }

  // ─── Password update ──────────────────────────────────────

  /// Update stored password (e.g. after user changes it on the server).
  Future<void> updatePassword(String email, String newPassword) async {
    await _sessionManager.saveCredential(email, newPassword);
  }
}
