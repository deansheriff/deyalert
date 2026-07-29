import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static SupabaseClient? supabase;

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasGoogleMaps => googleMapsApiKey.isNotEmpty;
  static bool get isDemoMode => !hasSupabase;

  static Future<void> initialize() async {
    if (!hasSupabase) return;
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    supabase = Supabase.instance.client;
  }
}
