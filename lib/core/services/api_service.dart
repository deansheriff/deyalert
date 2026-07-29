import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../../models/incident.dart';
import 'auth_service.dart';

class DeyAlertApi {
  DeyAlertApi({Dio? dio, AuthService? auth})
    : _auth = auth ?? AuthService(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              headers: const {'Content-Type': 'application/json'},
            ),
          );

  final Dio _dio;
  final AuthService _auth;

  Future<Options> _options() async {
    final token = await _auth.accessToken();
    return Options(
      headers: token == null ? null : {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<Incident>> nearbyIncidents({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/incidents',
      queryParameters: {'lat': lat, 'lng': lng, 'radius': radiusKm},
      options: await _options(),
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => Incident.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Incident> createIncident(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/incidents',
      data: payload,
      options: await _options(),
    );
    return Incident.fromJson(response.data!);
  }

  Future<Incident> corroborate(
    String incidentId, {
    required double lat,
    required double lng,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/incidents/$incidentId/corroborate',
      data: {
        'location': {'lat': lat, 'lng': lng},
      },
      options: await _options(),
    );
    return Incident.fromJson(response.data!);
  }

  Future<Incident> flag(
    String incidentId, {
    String reason = 'false_report',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/incidents/$incidentId/flag',
      data: {'reason': reason},
      options: await _options(),
    );
    return Incident.fromJson(response.data!);
  }

  Future<void> saveProfile({
    required String name,
    String? phone,
    required String state,
    required String lga,
    required String ward,
    required double radiusKm,
    required String locationPrecision,
  }) async {
    await _dio.put<Map<String, dynamic>>(
      '/auth/profile',
      data: {
        'name': name,
        'phone': phone,
        'state': state,
        'lga': lga,
        'ward': ward,
        'alert_radius_km': radiusKm,
        'location_precision': locationPrecision,
      },
      options: await _options(),
    );
  }
}
