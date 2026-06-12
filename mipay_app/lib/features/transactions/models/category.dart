import 'package:flutter/material.dart';

class Category {
  const Category({
    required this.key,
    required this.labelEn,
    required this.labelAr,
    required this.icon,
    required this.kind,
    required this.sortOrder,
  });

  final String key;
  final String labelEn;
  final String labelAr;
  final String icon; // Material icon name from the API
  final String kind; // 'expense' | 'income' | 'both'
  final int sortOrder;

  String labelFor(Locale locale) => locale.languageCode == 'ar' ? labelAr : labelEn;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        key: json['key'] as String,
        labelEn: json['label_en'] as String,
        labelAr: json['label_ar'] as String,
        icon: json['icon'] as String,
        kind: json['kind'] as String,
        sortOrder: json['sort_order'] as int,
      );

  /// Maps the API's Material icon names to IconData (const-only lookup —
  /// Flutter can't resolve icon names at runtime without this table).
  IconData get iconData => switch (icon) {
        'shopping_cart' => Icons.shopping_cart,
        'restaurant' => Icons.restaurant,
        'directions_car' => Icons.directions_car,
        'local_gas_station' => Icons.local_gas_station,
        'shopping_bag' => Icons.shopping_bag,
        'receipt_long' => Icons.receipt_long,
        'home' => Icons.home,
        'local_hospital' => Icons.local_hospital,
        'school' => Icons.school,
        'movie' => Icons.movie,
        'flight' => Icons.flight,
        'face' => Icons.face,
        'card_giftcard' => Icons.card_giftcard,
        'payments' => Icons.payments,
        'business_center' => Icons.business_center,
        'arrow_downward' => Icons.arrow_downward,
        _ => Icons.more_horiz,
      };
}
