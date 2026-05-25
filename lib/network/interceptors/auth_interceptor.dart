import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/session_manager.dart';

/// Checks that a session exists before the request goes out.
///
/// Does NOT inject Authorization headers — this server is cookie-based.
/// Cookies are injected automatically by the per-account CookieJar
/// via AccountCookieInterceptor, which runs before this one.
class AuthInterceptor extends Interceptor {
  final SessionManager _sessionManager;

  AuthInterceptor({SessionManager? sessionManager})
      : _sessionManager = sessionManager ?? SessionManager();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final email = options.extra['accountEmail'] as String?;

    if (email == null) {
      // No account context — public endpoint (e.g. login itself)
      return handler.next(options);
    }

    final session = await _sessionManager.getSession(email);

    if (session == null || session.isExpired) {
      // Let the request proceed — login endpoint hits this path on first login.
      // For authenticated endpoints, the server will return 401 which
      // ErrorInterceptor will convert to SessionExpiredException.
      debugPrint('[AuthInterceptor] No valid session for $email');
    } else if (session.isTokenBased) {
      // Future: bearer token accounts
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      debugPrint('[AuthInterceptor] Token injected for $email');
    } else {
      // Cookie-based: AccountCookieInterceptor already injected the cookie
      debugPrint('[AuthInterceptor] Cookie session active for $email');
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final email = err.requestOptions.extra['accountEmail'] as String?;
      if (email != null) {
        debugPrint('[AuthInterceptor] 401 — clearing session for $email');
        await _sessionManager.clearSession(email);
        // Do NOT retry or re-login here.
        // Error bubbles up; UI/service layer handles re-login.
      }
    }
    handler.next(err);
  }
}
