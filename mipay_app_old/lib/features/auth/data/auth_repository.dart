import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';

class AuthRepository {
  const AuthRepository(this._dio);
  final Dio _dio;

  Future<({String accessToken, String refreshToken, User user})> register({
    required String email,
    required String password,
    required String displayName,
    String defaultCurrency = 'SAR',
  }) async {
    final r = await _dio.post('/auth/register', data: {
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
    final r = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return _parseAuthResponse(r.data as Map<String, dynamic>);
  }

  Future<({String accessToken, String refreshToken})> refreshToken(String token) async {
    final r = await _dio.post('/auth/refresh', data: {'refresh_token': token});
    final data = r.data as Map<String, dynamic>;
    return (
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
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
    baseUrl: 'http://192.168.1.42:8000/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(_plainDioProvider)),
);
