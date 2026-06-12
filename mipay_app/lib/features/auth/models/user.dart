class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.defaultCurrency,
    required this.locale,
  });

  final String id;
  final String email;
  final String displayName;
  final String defaultCurrency;
  final String locale;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String,
        defaultCurrency: json['default_currency'] as String,
        locale: json['locale'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'default_currency': defaultCurrency,
        'locale': locale,
      };
}
