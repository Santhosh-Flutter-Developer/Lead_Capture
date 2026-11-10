enum ApiErrorType {
  network,
  timeout,
  unauthorized,
  server,
  invalidResponse,
  validation,
  unknown,
}

/// Thrown by the API layer. `toString()` returns only the user-facing message
/// so existing screens that do `FlushBar.show(context, e.toString())` keep
/// showing a clean message.
class ApiException implements Exception {
  final String message;
  final ApiErrorType type;
  final int? statusCode;

  const ApiException(this.message, {this.type = ApiErrorType.unknown, this.statusCode});

  bool get isUnauthorized => type == ApiErrorType.unauthorized;

  @override
  String toString() => message;
}
