import 'package:intl/intl.dart';

String formatCurrency(double amount, String currencyCode, String locale) {
  return NumberFormat.currency(
    locale: locale,
    symbol: currencyCode,
    decimalDigits: 2,
  ).format(amount);
}

String formatDate(DateTime date, String locale) {
  return DateFormat.yMMMd(locale).format(date);
}

String formatMonth(DateTime date, String locale) {
  return DateFormat.yMMM(locale).format(date);
}
