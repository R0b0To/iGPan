import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('→ [${options.method}] ${options.path}');
    if (options.extra.isNotEmpty) {
      debugPrint('  extra: ${options.extra}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('← [${response.statusCode}] ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '✗ [${err.response?.statusCode}] '
      '${err.requestOptions.path} — ${err.message}',
    );
    handler.next(err);
  }
}
