/// Mirror of the backend's VoiceExtractionResult (§5.2 response shape).
/// One utterance can yield several transactions, so [extractions] is a list.
class VoiceExtractionResult {
  const VoiceExtractionResult({
    required this.status,
    required this.transcript,
    required this.timingMs,
    required this.extractions,
    this.detectedLanguage,
  });

  final String status; // 'ok' | 'needs_review' | 'failed'
  final String transcript;
  final String? detectedLanguage;
  final List<ExtractedFields> extractions;
  final Map<String, int> timingMs;

  bool get isOk => status == 'ok';
  bool get needsReview => status == 'needs_review';
  bool get failed => status == 'failed';
  bool get hasExtractions => extractions.isNotEmpty;

  factory VoiceExtractionResult.fromJson(Map<String, dynamic> json) =>
      VoiceExtractionResult(
        status: json['status'] as String,
        transcript: json['transcript'] as String? ?? '',
        detectedLanguage: json['detected_language'] as String?,
        extractions: (json['extractions'] as List<dynamic>? ?? [])
            .map((e) => ExtractedFields.fromJson(e as Map<String, dynamic>))
            .toList(),
        timingMs: (json['timing_ms'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
}

class ExtractedFields {
  const ExtractedFields({
    required this.currency,
    required this.date,
    required this.confidence,
    this.status = 'ok',
    this.transactionType,
    this.amount,
    this.category,
    this.name,
  });

  final String status; // 'ok' | 'needs_review' — per-transaction
  final String? transactionType;
  final double? amount;
  final String currency;
  final String? category;
  final String? name;
  final DateTime date;
  final String confidence;

  bool get needsReview => status == 'needs_review';

  factory ExtractedFields.fromJson(Map<String, dynamic> json) => ExtractedFields(
        status: json['status'] as String? ?? 'ok',
        transactionType: json['transaction_type'] as String?,
        amount: (json['amount'] as num?)?.toDouble(),
        currency: json['currency'] as String,
        category: json['category'] as String?,
        name: json['name'] as String?,
        date: DateTime.parse(json['date'] as String),
        confidence: json['confidence'] as String,
      );
}
