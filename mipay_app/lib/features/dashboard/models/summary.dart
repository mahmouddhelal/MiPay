class CategorySummary {
  const CategorySummary({
    required this.category,
    required this.total,
    required this.count,
  });

  final String category;
  final double total;
  final int count;

  factory CategorySummary.fromJson(Map<String, dynamic> json) => CategorySummary(
        category: json['category'] as String,
        total: double.parse(json['total'].toString()),
        count: json['count'] as int,
      );
}

class Summary {
  const Summary({
    required this.month,
    required this.currency,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.byCategory,
    required this.byCategoryIncome,
  });

  final String month;
  final String currency;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final List<CategorySummary> byCategory;
  final List<CategorySummary> byCategoryIncome;

  factory Summary.empty() => Summary(
        month: '',
        currency: 'EGP',
        totalIncome: 0,
        totalExpense: 0,
        balance: 0,
        byCategory: [],
        byCategoryIncome: [],
      );

  factory Summary.fromJson(Map<String, dynamic> json) => Summary(
        month: json['month'] as String,
        currency: json['currency'] as String,
        totalIncome: double.parse(json['total_income'].toString()),
        totalExpense: double.parse(json['total_expense'].toString()),
        balance: double.parse(json['balance'].toString()),
        byCategory: (json['by_category'] as List)
            .map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        byCategoryIncome: (json['by_category_income'] as List? ?? [])
            .map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
