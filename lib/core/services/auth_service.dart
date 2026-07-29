import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../../models/incident.dart';

class AuthService {
  SupabaseClient? get _client => AppConfig.supabase;

  bool get isDemoMode => AppConfig.isDemoMode;
  bool get isAuthenticated => isDemoMode || _client?.auth.currentUser != null;
  String get userId => _client?.auth.currentUser?.id ?? demoUserId;
  String? get phone => _client?.auth.currentUser?.phone;

  Future<void> requestOtp(String phoneNumber) async {
    if (isDemoMode) return;
    await _client!.auth.signInWithOtp(phone: phoneNumber);
  }

  Future<void> verifyOtp({
    required String phoneNumber,
    required String token,
  }) async {
    if (isDemoMode) {
      if (token != '123456') {
        throw const AuthException('Use 123456 in demo mode.');
      }
      return;
    }
    await _client!.auth.verifyOTP(
      type: OtpType.sms,
      phone: phoneNumber,
      token: token,
    );
  }

  Future<void> signOut() async {
    if (!isDemoMode) await _client!.auth.signOut();
  }

  Future<String?> accessToken() async =>
      _client?.auth.currentSession?.accessToken;
}
