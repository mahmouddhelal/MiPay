class Transaction {
  const Transaction({
    required this.id,
    required this.transactionType,
    required this.amount,
    required this.currency,
    required this.category,
    required this.date,
    this.name,
    this.note,
    this.source = 'manual',
    this.transcript,
  });

  final String id;
  final String transactionType; // 'expense' | 'income'
  final double amount;
  final String currency;
  final String category;
  final String? name;
  final DateTime date;
  final String? note;
  final String source; // 'voice' | 'manual'
  final String? transcript;

  bool get isExpense => transactionType == 'expense';

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        transactionType: json['transaction_type'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        category: json['category'] as String,
        name: json['name'] as String?,
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        source: json['source'] as String? ?? 'manual',
        transcript: json['transcript'] as String?,
      );
}

/// Payload for POST /transactions and PATCH /transactions/{id}.
class TransactionDraft {
  const TransactionDraft({
    required this.transactionType,
    required this.amount,
    required this.currency,
    required this.category,
    required this.date,
    this.name,
    this.note,
    this.source = 'manual',
    this.transcript,
  });

  final String transactionType;
  final double amount;
  final String currency;
  final String category;
  final String? name;
  final DateTime date;
  final String? note;
  final String source;
  final String? transcript;

  Map<String, dynamic> toJson() => {
        'transaction_type': transactionType,
        'amount': amount,
        'currency': currency,
        'category': category,
        'name': name,
        'date': date.toIso8601String().substring(0, 10),
        'note': note,
        'source': source,
        'transcript': transcript,
      };
}

/// Filter for GET /transactions — used as a Riverpod family argument,
/// so it must implement value equality.
class TransactionFilter {
  const TransactionFilter({this.month, this.category, this.type});

  factory TransactionFilter.forMonth(DateTime d) => TransactionFilter(
      month: '${d.year}-${d.month.toString().padLeft(2, '0')}');

  final String? month; // 'YYYY-MM'
  final String? category;
  final String? type; // 'expense' | 'income'

  TransactionFilter copyWith({
    String? Function()? month,
    String? Function()? category,
    String? Function()? type,
  }) =>
      TransactionFilter(
        month: month != null ? month() : this.month,
        category: category != null ? category() : this.category,
        type: type != null ? type() : this.type,
      );

  Map<String, dynamic> toQuery() => {
        if (month != null) 'month': month,
        if (category != null) 'category': category,
        if (type != null) 'type': type,
      };

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      other.month == month &&
      other.category == category &&
      other.type == type;

  @override
  int get hashCode => Object.hash(month, category, type);
}
