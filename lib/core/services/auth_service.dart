import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../../models/incident.dart';

class AuthService {
  SupabaseClient? get _client => AppConfig.supabase;

  bool get isDemoMode => AppConfig.isDemoMode;
  bool get isAuthenticated => isDemoMode || _client?.auth.currentUser != null;
  String get userId => _client?.auth.currentUser?.id ?? demoUserId;
  String? get email => _client?.auth.currentUser?.email;

  Future<void> signIn({required String email, required String password}) async {
    if (isDemoMode) {
      if (email.toLowerCase() != 'demo@deyalert.local' ||
          password != 'password123') {
        throw const AuthException(
          'Use demo@deyalert.local and password123 in demo mode.',
        );
      }
      return;
    }
    await _client!.auth.signInWithPassword(email: email, password: password);
  }

  Future<bool> signUp({required String email, required String password}) async {
    if (!AppConfig.allowEmailSignUp) {
      throw const AuthException('New accounts are currently invite-only.');
    }
    if (isDemoMode) return true;
    final response = await _client!.auth.signUp(
      email: email,
      password: password,
    );
    return response.session != null;
  }

  Future<void> signOut() async {
    if (!isDemoMode) await _client!.auth.signOut();
  }

  Future<String?> accessToken() async =>
      _client?.auth.currentSession?.accessToken;
}
