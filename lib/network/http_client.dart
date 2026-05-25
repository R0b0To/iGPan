import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
 
import '../core/app_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/csrf_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
 
/// Single Dio instance with per-account cookie isolation.
///
/// Each account gets its own PersistCookieJar stored at:
///   <appDir>/.cookies/<sanitised_email>/
///
/// Call [initialize] once from main() before any requests.
class HttpClient {
  static final HttpClient _instance = HttpClient._internal();
  factory HttpClient() => _instance;
  HttpClient._internal();
 
  late final Dio _dio;
  late final String _cookieBasePath;
 
  // email → jar
  final Map<String, PersistCookieJar> _jars = {};
 
  bool _initialized = false;
 
  /// Must be called after WidgetsFlutterBinding.ensureInitialized().
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
 
    final appDir = await getApplicationDocumentsDirectory();
    _cookieBasePath = '${appDir.path}/.cookies';
 
    _dio = Dio(
      BaseOptions(
        baseUrl:        AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout:    AppConfig.sendTimeout,
        // No global Content-Type — login uses FormData (multipart/form-data),
        // other endpoints may differ.
      ),
    );
 
    _dio.interceptors.addAll([
      _AccountCookieInterceptor(_jars, _cookieBasePath),
      csrfInterceptor,                                    // ← CSRF before auth
      if (AppConfig.enableDioLogging) LoggingInterceptor(),
      AuthInterceptor(),
      ErrorInterceptor(),
    ]);
  }
 
  // ─── Cookie jar access ────────────────────────────────────
 
  PersistCookieJar jarFor(String email) {
    return _jars.putIfAbsent(
      email,
      () => PersistCookieJar(
        storage: FileStorage('$_cookieBasePath/${_sanitize(email)}/'),
        ignoreExpires: false,
      ),
    );
  }
 
  /// Delete all cookies for an account (call on logout or session clear).
  Future<void> deleteCookiesFor(String email) async {
    final jar = _jars[email];
    if (jar != null) {
      await jar.deleteAll();
      _jars.remove(email);
    }
    debugPrint('[HttpClient] Cookies deleted for $email');
  }
 
  static String _sanitize(String email) =>
      email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
 
  // ─── Request methods ──────────────────────────────────────
 
  Future<Response<T>> get<T>(
    String path, {
    required String accountEmail,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    final opts = _withAccount(options, accountEmail);
    return _dio.get<T>(path, queryParameters: queryParameters, options: opts);
  }
 
  Future<Response<T>> post<T>(
    String path, {
    required String accountEmail,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    final opts = _withAccount(options, accountEmail);
    return _dio.post<T>(
      path,
      data:            data,
      queryParameters: queryParameters,
      options:         opts,
    );
  }
 
  Options _withAccount(Options? base, String email) {
    return (base ?? Options()).copyWith(
      extra: {...?base?.extra, 'accountEmail': email},
    );
  }
 
  /// Raw Dio for edge cases.
  Dio get raw => _dio;
}
 
// ─── Per-account cookie interceptor ───────────────────────────────────────────
 
class _AccountCookieInterceptor extends Interceptor {
  final Map<String, PersistCookieJar> _jars;
  final String _basePath;
 
  _AccountCookieInterceptor(this._jars, this._basePath);
 
  PersistCookieJar _jarFor(String email) {
    return _jars.putIfAbsent(
      email,
      () => PersistCookieJar(
        storage: FileStorage('$_basePath/${HttpClient._sanitize(email)}/'),
        ignoreExpires: false,
      ),
    );
  }
 
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final email = options.extra['accountEmail'] as String?;
    if (email != null) {
      final jar     = _jarFor(email);
      final cookies = await jar.loadForRequest(options.uri);
      if (cookies.isNotEmpty) {
        options.headers['Cookie'] =
            cookies.map((c) => '${c.name}=${c.value}').join('; ');
      }
    }
    handler.next(options);
  }
 
  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final email = response.requestOptions.extra['accountEmail'] as String?;
    if (email != null) {
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null && setCookie.isNotEmpty) {
        final jar     = _jarFor(email);
        final cookies = setCookie
            .map((s) => _parseCookieHeader(s, response.requestOptions.uri))
            .whereType<Cookie>()
            .toList();
        if (cookies.isNotEmpty) {
          await jar.saveFromResponse(response.requestOptions.uri, cookies);
          debugPrint(
            '[CookieInterceptor] Saved ${cookies.length} cookie(s) for $email',
          );
        }
      }
    }
    handler.next(response);
  }
 
  Cookie? _parseCookieHeader(String header, Uri uri) {
    try {
      final parts = header.split(';');
      final nameValue = parts.first.trim().split('=');
      if (nameValue.length < 2) return null;
      final name  = nameValue.first.trim();
      final value = nameValue.sublist(1).join('=').trim();
      return Cookie(name, value)
        ..domain  = uri.host
        ..path    = '/'
        ..httpOnly = header.toLowerCase().contains('httponly');
    } catch (_) {
      return null;
    }
  }
}