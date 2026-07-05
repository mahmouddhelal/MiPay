import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_controller.dart';

/// Derives the current user's id from auth state.
/// When null (unauthenticated), all per-user providers should return empty data.
/// Because providers watch this, Riverpod tears them down automatically on
/// logout/login — making cross-user data leaks structurally impossible.
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthAuthenticated ? auth.user.id : null;
});
