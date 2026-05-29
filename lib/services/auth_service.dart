import 'dart:convert';
 
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
 
import '../core/app_config.dart';
import '../core/exceptions.dart';
import '../core/session_manager.dart';
import '../models/account.dart';
import '../models/account_data.dart';
import '../models/session.dart';
import '../network/http_client.dart';
import '../network/interceptors/csrf_interceptor.dart';
 
/// Handles login, logout, and session validation.
/// Does not call Dio directly — uses HttpClient.
class AuthService {
  final HttpClient     _httpClient;
  final SessionManager _sessionManager;
 
  AuthService({
    HttpClient?     httpClient,
    SessionManager? sessionManager,
  })  : _httpClient     = httpClient     ?? HttpClient(),
        _sessionManager = sessionManager ?? SessionManager();
 
  // ─── Login ────────────────────────────────────────────────
 
  /// Login with [email] + [password].
  ///
  /// On success:
  ///   - Server sets a session cookie (captured by the cookie jar)
  ///   - Session metadata is saved to secure storage
  ///   - Returns the new [Session]
  ///
  /// Throws [LoginFailedException] on any failure.
Future<Session> login(String email, String password, {bool isRetry = false}) async {
  debugPrint('[AuthService] Login attempt for $email (Retry: $isRetry)');
 
  try {
    final response = await _httpClient.post<String>(
      AppConfig.loginEndpoint,
      accountEmail: email,
      data: FormData.fromMap({
        'loginUsername': email,
        'loginPassword': password,
        'loginRemember': 'on',
        'csrfName':      '',
        'csrfToken':     '',
      }),
    );
 
    final raw = response.data;
    if (raw == null || raw.isEmpty) {
      throw const LoginFailedException('Empty response from server');
    }
 
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw LoginFailedException('Non-JSON response: $raw');
    }
 
    // --- SESSION EXPIRED DURING LOGIN LOGIC ---
    // Check if the message indicates a session/token/expired error
    final message = data['message']?.toString() ?? '';
    final isSessionError = message.toLowerCase().contains('session') || 
                           message.toLowerCase().contains('expired') ||
                           message.toLowerCase().contains('token');
 
    if (data['status'] != 1) {
      // If it's a session error and we haven't retried yet, clean and try once more
      if (isSessionError && !isRetry) {
        debugPrint('[AuthService] Session error detected during login. Cleaning and retrying...');
        await _httpClient.deleteCookiesFor(email);
        await Future.delayed(const Duration(milliseconds: 200));
        return login(email, password, isRetry: true); // Single retry attempt
      }
 
      throw LoginFailedException(message.isNotEmpty ? message : 'Login failed');
    }
 
    // Success logic...
    final session = Session(
      accessToken:  null,
      refreshToken: null,
      expiresAt:    DateTime.now().add(AppConfig.sessionDuration),
      createdAt:    DateTime.now(),
    );
 
    await _sessionManager.saveSession(email, session);
    await _sessionManager.saveCredential(email, password);
 
    return session;
 
  } on AppException {
    rethrow;
  } catch (e) {
    // If a low-level network error happens, and it might be cookie-related
    if (!isRetry) {
      await _httpClient.deleteCookiesFor(email);
      return login(email, password, isRetry: true);
    }
    throw LoginFailedException('Login failed: $e');
  }
}
  // ─── Logout ───────────────────────────────────────────────
 
  /// Clear session metadata, cookies, and CSRF token for [email].
  Future<void> logout(String email) async {
    debugPrint('[AuthService] Logout for $email');
    await _sessionManager.clearAll(email);
    await _httpClient.deleteCookiesFor(email);
    csrfInterceptor.clearFor(email);
  }
 
  // ─── Session validation ───────────────────────────────────
 
  /// Validate session by calling fireUp.
  ///
  /// Returns [AccountData] on success (session is live).
  /// Returns null if the session has expired or the request fails.
  Future<AccountData?> validateSession(String email) async {
    debugPrint('[AuthService] Validating session for $email');
 
    // Quick local check first
    final isValid = await _sessionManager.isSessionValid(email);
    if (!isValid) {
      debugPrint('[AuthService] Session metadata expired for $email');
      return null;
    }
 
    try {
      final response = await _httpClient.get<String>(
        AppConfig.fireUpEndpoint,
        accountEmail: email,
      );
 
      final raw = response.data;
      if (raw == null || raw.isEmpty) return null;
 
      final Map<String, dynamic> data;
      try {
        data = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
 
      // guestAccount: true means the session cookie is gone
      if (data['guestAccount'] == true) {
        debugPrint('[AuthService] Session expired (guest) for $email');
        await _sessionManager.clearSession(email);
        return null;
      }
 
      debugPrint('[AuthService] Session valid for $email');
      return AccountData.fromFireUp(data);
 
    } catch (e) {
      debugPrint('[AuthService] Session validation failed for $email: $e');
      return null;
    }
  }
 
  // ─── Re-login ─────────────────────────────────────────────
 
  /// Re-login using stored credentials (called when session expires).
  /// Clears stale cookies and session metadata first so the login
  /// is sent as a clean request with no old PHPSESSID or CSRF headers.
  /// Returns new [Session] or throws [LoginFailedException].
Future<Session> reLogin(String email) async {
  debugPrint('[AuthService] Seamless re-login sequence started for $email');
 
  final password = await _sessionManager.getCredential(email);
  if (password == null) {
    throw LoginFailedException('No credentials found');
  }
 
  // 1. Force clear everything first
  await _sessionManager.clearSession(email);
  await _httpClient.deleteCookiesFor(email);
 
  // 2. Small delay for file-system cookie deletion to complete.
  await Future.delayed(const Duration(milliseconds: 300));
 
  // 3. Call login normally (isRetry: false) so its built-in retry logic
  //    can fire if the first attempt still fails for any reason.
  return login(email, password);
}
 
  // ─── Convenience ──────────────────────────────────────────
 
  /// Login from an [Account] object (used by AccountService).
  Future<Session> loginAccount(Account account) =>
      login(account.email, account.password);
}