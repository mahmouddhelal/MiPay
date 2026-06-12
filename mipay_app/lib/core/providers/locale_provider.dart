import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_controller.dart';

/// Derives the active [Locale] from the authenticated user's stored locale.
/// Updates automatically when [AuthController] emits a new user (e.g. after
/// [AuthController.updateProfile] changes the locale).
final localeProvider = Provider<Locale>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth is AuthAuthenticated) {
    return Locale(auth.user.locale);
  }
  return const Locale('en');
});
