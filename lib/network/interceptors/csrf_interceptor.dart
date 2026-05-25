import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
 
/// Manages the rolling CSRF token required by saveAll and other mutating requests.
///
/// The server returns a fresh csrf.name + csrf.token in every JSON response.
/// This interceptor:
///   1. Reads the token from every response body (if JSON).
///   2. Stores the latest name + token in memory (per account email).
///   3. Injects X-CSRF-Name and X-CSRF-Token headers into every POST request.
///
/// Since the token is per-session (not per-account), we store one global pair
/// and update it on every response. This is safe because requests are serialised
/// per account at the service layer.
class CsrfInterceptor extends Interceptor {
  String _csrfName  = '';
  String _csrfToken = '';
 
  // Expose for saveAll body fields (some endpoints want them in the body too)
  String get name  => _csrfName;
  String get token => _csrfToken;
 
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Inject CSRF headers on every POST if we have a token
    if (options.method == 'POST' && _csrfName.isNotEmpty) {
      options.headers['X-CSRF-Name']  = _csrfName;
      options.headers['X-CSRF-Token'] = _csrfToken;
      debugPrint('[CSRF] Injected ${_csrfName.substring(0, 8)}… into POST');
    }
    handler.next(options);
  }
 
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _extractFromResponse(response.data);
    handler.next(response);
  }
 
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) _extractFromResponse(err.response!.data);
    handler.next(err);
  }
 
  void _extractFromResponse(dynamic data) {
    if (data is! String) return;
    // Fast path — look for "csrf" key in the raw string before parsing
    if (!data.contains('"csrf"')) return;
 
    try {
      // We only need the csrf block — avoid full parse when not needed
      final nameMatch  = RegExp(r'"name"\s*:\s*"([a-f0-9]+)"').firstMatch(data);
      final tokenMatch = RegExp(r'"token"\s*:\s*"([a-f0-9]+)"').firstMatch(data);
 
      if (nameMatch != null && tokenMatch != null) {
        _csrfName  = nameMatch.group(1)!;
        _csrfToken = tokenMatch.group(1)!;
        debugPrint('[CSRF] Updated token ${_csrfName.substring(0, 8)}…');
      }
    } catch (_) {}
  }
}
 
/// Global singleton so HttpClient and RaceService can both access it.
final csrfInterceptor = CsrfInterceptor();