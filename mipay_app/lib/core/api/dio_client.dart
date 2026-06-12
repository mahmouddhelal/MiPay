import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_storage.dart';
import '../../features/auth/providers/auth_controller.dart';
import 'api_exceptions.dart';

const _baseUrl = 'http://10.0.2.2:8000/api/v1'; // Android emulator → host machine

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.addAll([
    _AuthInterceptor(dio, ref),
    _ErrorInterceptor(),
  ]);

  return dio;
});

// ── Auth interceptor: attach token, refresh on 401, logout on failure ──────

class _AuthInterceptor extends QueuedInterceptorsWrapper {
  _AuthInterceptor(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;
  bool _isRefreshing = false;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isRefreshing) {
      return handler.next(err);
    }

    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) {
      _ref.read(authControllerProvider.notifier).handleSessionExpired();
      return handler.next(err);
    }

    _isRefreshing = true;
    try {
      // Use a bare Dio to avoid running through this interceptor again
      final refreshDio = Dio(BaseOptions(baseUrl: _baseUrl));
      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data as Map<String, dynamic>;
      final newAccess = data['access_token'] as String;
      final newRefresh = data['refresh_token'] as String;

      await TokenStorage.updateTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );

      // Retry original request with new token
      err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
      final retry = await _dio.fetch(err.requestOptions);
      handler.resolve(retry);
    } catch (_) {
      _ref.read(authControllerProvider.notifier).handleSessionExpired();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}

// ── Error interceptor: map API error envelope to ApiException ──────────────

class _ErrorInterceptor extends InterceptorsWrapper {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null) {
      final apiEx = ApiException.fromJson(
        response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : {},
        response.statusCode ?? 0,
      );
      return handler.reject(DioException(
        requestOptions: err.requestOptions,
        error: apiEx,
        response: response,
        type: err.type,
        message: apiEx.message,
      ));
    }
    handler.next(err);
  }
}
