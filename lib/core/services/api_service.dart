import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../../models/advisory.dart';
import '../../models/incident.dart';
import '../../models/user_profile.dart';
import '../../models/sos.dart';
import '../../models/app_notification.dart';
import '../../models/verifier.dart';
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

  Future<List<SecurityAdvisory>> trendingNews({int limit = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/news/trending',
      queryParameters: {'limit': limit},
      options: await _options(),
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) =>
              SecurityAdvisory.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<SecurityAdvisory>> nearbyAdvisories({
    required double lat,
    required double lng,
    double radiusKm = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/advisories',
      queryParameters: {'lat': lat, 'lng': lng, 'radius': radiusKm},
      options: await _options(),
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) =>
              SecurityAdvisory.fromJson(Map<String, dynamic>.from(item as Map)),
        )
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

  Future<UserProfile> currentProfile() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/me',
      options: await _options(),
    );
    return UserProfile.fromJson(response.data!);
  }

  Future<UserProfile> updateProfile({
    required String name,
    String? phone,
    required String state,
    required String lga,
    required String ward,
    required double radiusKm,
    required String locationPrecision,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
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
    return UserProfile.fromJson(response.data!);
  }

  Future<String> uploadMedia(XFile file) async {
    final bytes = await file.readAsBytes();
    final response = await _dio.post<Map<String, dynamic>>(
      '/media/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
      }),
      options: await _options(),
    );
    return response.data!['url'] as String;
  }

  Future<List<TrustedContact>> trustedContacts() async {
    final response = await _dio.get<List<dynamic>>(
      '/trusted-contacts',
      options: await _options(),
    );
    return (response.data ?? const [])
        .map(
          (item) =>
              TrustedContact.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<TrustedContact> addTrustedContact({
    required String name,
    required String phone,
    String? relationship,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/trusted-contacts',
      data: {'name': name, 'phone': phone, 'relationship': relationship},
      options: await _options(),
    );
    return TrustedContact.fromJson(response.data!);
  }

  Future<void> deleteTrustedContact(String id) async {
    await _dio.delete<void>('/trusted-contacts/$id', options: await _options());
  }

  Future<SosReadiness> sosReadiness() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/sos/readiness',
      options: await _options(),
    );
    return SosReadiness.fromJson(response.data!);
  }

  Future<SosResult> triggerSos({
    required double lat,
    required double lng,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/sos',
      data: {
        'client_alert_id': const Uuid().v4(),
        'location': {'lat': lat, 'lng': lng},
      },
      options: await _options(),
    );
    return SosResult.fromJson(response.data!);
  }

  Future<({List<AppNotification> items, int unread})> notifications() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      options: await _options(),
    );
    final values = response.data?['items'] as List<dynamic>? ?? const [];
    return (
      items: values
          .map(
            (item) => AppNotification.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      unread: response.data?['unread'] as int? ?? 0,
    );
  }

  Future<void> markNotificationRead(String id) async {
    await _dio.patch<void>(
      '/notifications/$id/read',
      options: await _options(),
    );
  }

  Future<List<Incident>> moderationQueue() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/moderation',
      options: await _options(),
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .map(
          (item) => Incident.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<Incident> moderateIncident(String id, String status) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/incidents/$id',
      data: {'status': status},
      options: await _options(),
    );
    return Incident.fromJson(response.data!);
  }

  Future<Incident> verifyIncident(String id) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/incidents/$id/verify',
      options: await _options(),
    );
    return Incident.fromJson(response.data!);
  }

  Future<List<VerifierRecord>> verifiers() async {
    final response = await _dio.get<List<dynamic>>(
      '/admin/verifiers',
      options: await _options(),
    );
    return (response.data ?? const [])
        .map(
          (item) =>
              VerifierRecord.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<VerifierRecord> addVerifier({
    required String userId,
    required String state,
    required String lga,
    String? ward,
    String? title,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/verifiers',
      data: {
        'user_id': userId,
        'state': state,
        'lga': lga,
        'ward': ward,
        'title': title,
      },
      options: await _options(),
    );
    return VerifierRecord.fromJson(response.data!);
  }

  Future<void> revokeVerifier(String userId) async {
    await _dio.delete<void>(
      '/admin/verifiers/$userId',
      options: await _options(),
    );
  }

  Future<List<String>> areaStates() => _stringList('/areas/states');

  Future<List<String>> areaLgas(String state) =>
      _stringList('/areas/lgas', query: {'state': state});

  Future<List<String>> areaWards(String state, String lga) =>
      _stringList('/areas/wards', query: {'state': state, 'lga': lga});

  Future<List<String>> _stringList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      path,
      queryParameters: query,
      options: await _options(),
    );
    return (response.data ?? const []).cast<String>();
  }
}
