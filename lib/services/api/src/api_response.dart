import 'api_exception.dart';

/// Parsed `{status, message, data}` envelope.
/// HTTP 200 does NOT imply success – always check [status].
class ApiResponse {
  final bool status;
  final String message;
  final dynamic data;
  final int statusCode;

  const ApiResponse({
    required this.status,
    required this.message,
    required this.data,
    required this.statusCode,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, int statusCode) {
    final s = json['status'];
    return ApiResponse(
      status: s == true || s == 1 || s == '1' || s == 'true',
      message: (json['message'] ?? '').toString(),
      data: json['data'],
      statusCode: statusCode,
    );
  }

  /// `data` as a map (empty map when null / not a map).
  Map<String, dynamic> get dataMap =>
      data is Map ? Map<String, dynamic>.from(data as Map) : <String, dynamic>{};

  /// `data` as a list (empty list when null / not a list).
  List<dynamic> get dataList => data is List ? List<dynamic>.from(data as List) : <dynamic>[];

  /// Throws [ApiException] carrying the server message when status == false.
  ApiResponse ensureSuccess() {
    if (!status) {
      throw ApiException(
        message.isEmpty ? 'Request failed' : message,
        type: ApiErrorType.validation,
        statusCode: statusCode,
      );
    }
    return this;
  }
}
