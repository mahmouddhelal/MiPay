/// Mirror of the backend's VoiceExtractionResult (§5.2 response shape).
class VoiceExtractionResult {
  const VoiceExtractionResult({
    required this.status,
    required this.transcript,
    required this.timingMs,
    this.detectedLanguage,
    this.extraction,
  });

  final String status; // 'ok' | 'needs_review' | 'failed'
  final String transcript;
  final String? detectedLanguage;
  final ExtractedFields? extraction;
  final Map<String, int> timingMs;

  bool get isOk => status == 'ok';
  bool get needsReview => status == 'needs_review';
  bool get failed => status == 'failed';

  factory VoiceExtractionResult.fromJson(Map<String, dynamic> json) =>
      VoiceExtractionResult(
        status: json['status'] as String,
        transcript: json['transcript'] as String? ?? '',
        detectedLanguage: json['detected_language'] as String?,
        extraction: json['extraction'] == null
            ? null
            : ExtractedFields.fromJson(json['extraction'] as Map<String, dynamic>),
        timingMs: (json['timing_ms'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
}

class ExtractedFields {
  const ExtractedFields({
    required this.currency,
    required this.date,
    required this.confidence,
    this.transactionType,
    this.amount,
    this.category,
    this.name,
  });

  final String? transactionType;
  final double? amount;
  final String currency;
  final String? category;
  final String? name;
  final DateTime date;
  final String confidence;

  factory ExtractedFields.fromJson(Map<String, dynamic> json) => ExtractedFields(
        transactionType: json['transaction_type'] as String?,
        amount: (json['amount'] as num?)?.toDouble(),
        currency: json['currency'] as String,
        category: json['category'] as String?,
        name: json['name'] as String?,
        date: DateTime.parse(json['date'] as String),
        confidence: json['confidence'] as String,
      );
}
