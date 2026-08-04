import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../models/incident.dart';
import 'api_service.dart';
import 'offline_queue.dart';

class SubmissionResult {
  const SubmissionResult({required this.queued, this.incident});
  final bool queued;
  final Incident? incident;
}

class IncidentRepository {
  IncidentRepository({DeyAlertApi? api, OfflineQueue? queue})
    : _api = api ?? DeyAlertApi(),
      _queue = queue ?? OfflineQueue();

  final DeyAlertApi _api;
  final OfflineQueue _queue;

  bool _isConnectivityFailure(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => true,
    _ => false,
  };

  Future<List<Incident>> loadNearby({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    try {
      final incidents = await _api.nearbyIncidents(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
      );
      return incidents;
    } on DioException {
      rethrow;
    }
  }

  Future<SubmissionResult> submit(Map<String, dynamic> payload) async {
    payload.putIfAbsent('client_report_id', () => const Uuid().v4());
    try {
      final incident = await _api.createIncident(payload);
      return SubmissionResult(queued: false, incident: incident);
    } on DioException catch (error) {
      if (!_isConnectivityFailure(error)) rethrow;
      await _queue.enqueue(payload);
      return const SubmissionResult(queued: true);
    }
  }

  Future<void> syncPending() async {
    for (final item in await _queue.pending()) {
      try {
        await _api.createIncident(
          Map<String, dynamic>.from(item['payload'] as Map),
        );
        await _queue.remove(item['id'] as int);
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        if (status != null && status >= 400 && status < 500 && status != 401) {
          await _queue.remove(item['id'] as int);
          continue;
        }
        return;
      }
    }
  }

  Future<Incident> corroborate(
    String incidentId, {
    required double lat,
    required double lng,
  }) => _api.corroborate(incidentId, lat: lat, lng: lng);

  Future<Incident> flag(String incidentId) => _api.flag(incidentId);
}
