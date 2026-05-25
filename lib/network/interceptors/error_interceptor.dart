import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/exceptions.dart';

/// Converts Dio exceptions into typed AppExceptions.
class ErrorInterceptor extends Interceptor {
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    debugPrint('[ErrorInterceptor] ${err.type} — ${err.message}');

    final appException = _map(err);

    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        error:          appException,
        type:           err.type,
        response:       err.response,
      ),
    );
  }

  AppException _map(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return NetworkException('Network timeout: ${err.message}');

      case DioExceptionType.badResponse:
        final code = err.response?.statusCode;
        final email =
            err.requestOptions.extra['accountEmail'] as String? ?? 'unknown';

        if (code == 401) {
          return SessionExpiredException(email, 'Unauthorized (401)');
        }
        if (code == 403) {
          return ApiException('Access denied (403)', statusCode: code);
        }
        if (code != null && code >= 500) {
          return ServerException(
            message:    'Server error: $code',
            statusCode: code,
          );
        }
        return ApiException(
          'API error: ${err.response?.data}',
          statusCode:   code,
          responseData: err.response?.data,
        );

      case DioExceptionType.cancel:
        return const ApiException('Request cancelled');

      case DioExceptionType.unknown:
      default:
        return ApiException(
          'Unknown error: ${err.message}',
          originalError: err.error,
        );
    }
  }
}
