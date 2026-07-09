import 'package:mipay_app/l10n/app_localizations.dart';

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

  String localizedMessage(AppLocalizations l10n) {
    switch (code) {
      case 'INVALID_CREDENTIALS':
        return l10n.errorInvalidCredentials;
      case 'EMAIL_TAKEN':
        return l10n.errorEmailTaken;
      case 'TOKEN_EXPIRED':
        return l10n.errorTokenExpired;
      case 'NOT_FOUND':
        return l10n.errorNotFound;
      case 'AUDIO_TOO_LONG':
        return l10n.errorAudioTooLong;
      case 'AUDIO_UNSUPPORTED':
        return l10n.errorAudioUnsupported;
      case 'EXTRACTION_FAILED':
        return l10n.errorExtractionFailed;
      case 'VALIDATION_ERROR':
        return l10n.errorValidation;
      case 'INTERNAL':
        return l10n.errorInternal;
      default:
        return l10n.errorUnknown;
    }
  }

  @override
  String toString() => 'ApiException($code: $message)';
}

/// Returns a user-facing error string from any exception type.
/// Call this in UI catch blocks where [AppLocalizations] is available.
String apiErrorMessage(Object error, AppLocalizations l10n) {
  if (error is ApiException) return error.localizedMessage(l10n);
  return l10n.errorNetwork;
}
