import 'package:dio/dio.dart';

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

  Future<List<Incident>> loadNearby({
    double lat = 6.6018,
    double lng = 3.3515,
    double radiusKm = 5,
  }) async {
    try {
      final incidents = await _api.nearbyIncidents(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
      );
      return incidents.isEmpty ? demoIncidents : incidents;
    } on DioException {
      return demoIncidents;
    }
  }

  Future<SubmissionResult> submit(Map<String, dynamic> payload) async {
    try {
      final incident = await _api.createIncident(payload);
      return SubmissionResult(queued: false, incident: incident);
    } on DioException {
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
      } on DioException {
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
