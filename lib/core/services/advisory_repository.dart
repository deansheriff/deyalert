import 'package:dio/dio.dart';

import '../../models/advisory.dart';
import 'api_service.dart';

class AdvisoryRepository {
  AdvisoryRepository({DeyAlertApi? api}) : _api = api ?? DeyAlertApi();

  final DeyAlertApi _api;

  Future<List<SecurityAdvisory>> loadTrending() async {
    try {
      final advisories = await _api.trendingNews();
      return advisories.isEmpty ? demoAdvisories : advisories;
    } on DioException {
      return demoAdvisories;
    }
  }

  Future<List<SecurityAdvisory>> loadNearby({
    double lat = 6.6018,
    double lng = 3.3515,
    double radiusKm = 50,
  }) async {
    try {
      final advisories = await _api.nearbyAdvisories(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
      );
      return advisories.isEmpty ? demoAdvisories : advisories;
    } on DioException {
      return demoAdvisories;
    }
  }
}
