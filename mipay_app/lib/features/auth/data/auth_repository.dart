import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../models/user.dart';

class AuthRepository {
  const AuthRepository(this._plainDio, this._authedDio);
  final Dio _plainDio;
  final Dio _authedDio;

  Future<({String accessToken, String refreshToken, User user})> register({
    required String email,
    required String password,
    required String displayName,
    String defaultCurrency = 'SAR',
  }) async {
    final r = await _plainDio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'display_name': displayName,
      'default_currency': defaultCurrency,
    });
    return _parseAuthResponse(r.data as Map<String, dynamic>);
  }

  Future<({String accessToken, String refreshToken, User user})> login({
    required String email,
    required String password,
  }) async {
    final r = await _plainDio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return _parseAuthResponse(r.data as Map<String, dynamic>);
  }

  Future<({String accessToken, String refreshToken})> refreshToken(String token) async {
    final r = await _plainDio.post('/auth/refresh', data: {'refresh_token': token});
    final data = r.data as Map<String, dynamic>;
    return (
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }

  Future<User> updateProfile({
    String? displayName,
    String? defaultCurrency,
    String? locale,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (defaultCurrency != null) body['default_currency'] = defaultCurrency;
    if (locale != null) body['locale'] = locale;
    final r = await _authedDio.patch('/users/me', data: body);
    return User.fromJson(r.data as Map<String, dynamic>);
  }

  static ({String accessToken, String refreshToken, User user}) _parseAuthResponse(
    Map<String, dynamic> data,
  ) =>
      (
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        user: User.fromJson(data['user'] as Map<String, dynamic>),
      );
}

// Uses a plain (unauthenticated) Dio instance — no circular dep with authController
final _plainDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: kApiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(_plainDioProvider), ref.watch(dioProvider)),
);
