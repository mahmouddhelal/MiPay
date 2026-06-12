class ApiException implements Exception {
  const ApiException({required this.code, required this.message, required this.statusCode});

  final String code;
  final String message;
  final int statusCode;

  factory ApiException.fromJson(Map<String, dynamic> json, int statusCode) {
    final error = json['error'] as Map<String, dynamic>? ?? {};
    return ApiException(
      code: error['code'] as String? ?? 'UNKNOWN',
      message: error['message'] as String? ?? 'Unknown error',
      statusCode: statusCode,
    );
  }

  bool get isUnauthorized => code == 'INVALID_CREDENTIALS' || code == 'TOKEN_EXPIRED';
  bool get isNotFound => code == 'NOT_FOUND';

  @override
  String toString() => 'ApiException($code: $message)';
}
