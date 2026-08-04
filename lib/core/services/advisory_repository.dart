import 'package:dio/dio.dart';

import '../../models/advisory.dart';
import 'api_service.dart';

class AdvisoryRepository {
  AdvisoryRepository({DeyAlertApi? api}) : _api = api ?? DeyAlertApi();

  final DeyAlertApi _api;

  Future<List<SecurityAdvisory>> loadTrending() async {
    try {
      final advisories = await _api.trendingNews();
      return advisories;
    } on DioException {
      rethrow;
    }
  }

  Future<List<SecurityAdvisory>> loadNearby({
    required double lat,
    required double lng,
    double radiusKm = 50,
  }) async {
    try {
      final advisories = await _api.nearbyAdvisories(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
      );
      return advisories;
    } on DioException {
      rethrow;
    }
  }
}
