import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Manages the rolling CSRF token required by saveAll and other mutating requests.
///
/// The server returns a fresh csrf.name + csrf.token in every JSON response.
/// This interceptor:
///   1. Reads the token from every response body (if JSON).
///   2. Stores the latest name + token keyed by account email.
///   3. Injects X-CSRF-Name and X-CSRF-Token headers on every POST or
///      action=send GET, using the token for that specific account.
///
/// Tokens are per-session, so switching accounts no longer contaminates
/// the token for the previous account.
class CsrfInterceptor extends Interceptor {
  // Per-account storage
  final Map<String, String> _names  = {};
  final Map<String, String> _tokens = {};

  // ─── Per-account accessors ────────────────────────────────

  String nameFor(String email)  => _names[email]  ?? '';
  String tokenFor(String email) => _tokens[email] ?? '';

  /// Remove stored state for one account (call on logout).
  void clearFor(String email) {
    _names.remove(email);
    _tokens.remove(email);
    debugPrint('[CSRF] Cleared token for $email');
  }

  // ─── Interceptor hooks ────────────────────────────────────

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final email       = options.extra['accountEmail'] as String?;
    final isActionGet = options.method == 'GET' &&
                        options.path.contains('action=send');

    if ((options.method == 'POST' || isActionGet) && email != null) {
      final n = nameFor(email);
      final t = tokenFor(email);
      if (n.isNotEmpty) {
        options.headers['X-CSRF-Name']  = n;
        options.headers['X-CSRF-Token'] = t;
        debugPrint('[CSRF] Injected for $email into '
            '${options.method} ${options.path}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final email = response.requestOptions.extra['accountEmail'] as String?;
    _extractFromResponse(response.data, email);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      final email = err.requestOptions.extra['accountEmail'] as String?;
      _extractFromResponse(err.response!.data, email);
    }
    handler.next(err);
  }

  // ─── Internal ─────────────────────────────────────────────

  void _extractFromResponse(dynamic data, String? email) {
    if (data is! String || email == null) return;
    if (!data.contains('"csrf"')) return;

    try {
      final nameMatch  = RegExp(r'"name"\s*:\s*"([a-f0-9]+)"').firstMatch(data);
      final tokenMatch = RegExp(r'"token"\s*:\s*"([a-f0-9]+)"').firstMatch(data);

      if (nameMatch != null && tokenMatch != null) {
        _names[email]  = nameMatch.group(1)!;
        _tokens[email] = tokenMatch.group(1)!;
        debugPrint('[CSRF] Updated token for $email: '
            '${_names[email]!.substring(0, 8)}…');
      }
    } catch (_) {}
  }
}

/// Global singleton — token state is now per-account, not global.
final csrfInterceptor = CsrfInterceptor();