/// Base class for all app exceptions
abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Login failed (bad credentials, server error, parse error)
class LoginFailedException extends AppException {
  const LoginFailedException(super.message);
}

/// Session expired — cookie gone or server returned 401
class SessionExpiredException extends AppException {
  final String accountEmail;
  const SessionExpiredException(this.accountEmail, String message)
      : super(message);
}

/// Generic API error with optional status code
class ApiException extends AppException {
  final int? statusCode;
  final dynamic responseData;
  final Object? originalError;

  const ApiException(
    super.message, {
    this.statusCode,
    this.responseData,
    this.originalError,
  });
}

/// Network timeout or connectivity issue
class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// Server-side error (5xx)
class ServerException extends AppException {
  final int? statusCode;
  const ServerException({required String message, this.statusCode})
      : super(message);
}