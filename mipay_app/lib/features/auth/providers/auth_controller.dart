import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/auth/token_storage.dart';
import '../data/auth_repository.dart';
import '../models/user.dart';

// ── State ──────────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  const AuthError({this.apiException, this.fallback = ''});
  final ApiException? apiException;
  final String fallback;
}

// ── Controller ─────────────────────────────────────────────────────────────

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(const AuthLoading()) {
    _init();
  }

  final AuthRepository _repo;

  Future<void> _init() async {
    try {
      final token = await TokenStorage.getAccessToken();
      final userData = await TokenStorage.getUserData();
      if (token != null && userData != null) {
        state = AuthAuthenticated(User.fromJson(userData));
      } else {
        await TokenStorage.clear();
        state = const AuthUnauthenticated();
      }
    } catch (_) {
      await TokenStorage.clear();
      state = const AuthUnauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    try {
      final result = await _repo.login(email: email, password: password);
      await TokenStorage.saveSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        user: result.user.toJson(),
      );
      state = AuthAuthenticated(result.user);
    } catch (e) {
      state = AuthError(apiException: _toApiException(e));
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    String defaultCurrency = 'SAR',
  }) async {
    state = const AuthLoading();
    try {
      final result = await _repo.register(
        email: email,
        password: password,
        displayName: displayName,
        defaultCurrency: defaultCurrency,
      );
      await TokenStorage.saveSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        user: result.user.toJson(),
      );
      state = AuthAuthenticated(result.user);
    } catch (e) {
      state = AuthError(apiException: _toApiException(e));
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? defaultCurrency,
    String? locale,
  }) async {
    final current = state;
    if (current is! AuthAuthenticated) return;
    final updated = await _repo.updateProfile(
      displayName: displayName,
      defaultCurrency: defaultCurrency,
      locale: locale,
    );
    await TokenStorage.updateUserData(updated.toJson());
    state = AuthAuthenticated(updated);
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    state = const AuthUnauthenticated();
  }

  /// Called by DioAuthInterceptor when a refresh attempt fails.
  void handleSessionExpired() {
    TokenStorage.clear();
    state = const AuthUnauthenticated();
  }

  static ApiException? _toApiException(Object e) {
    if (e is DioException && e.error is ApiException) {
      return e.error as ApiException;
    }
    return null;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
