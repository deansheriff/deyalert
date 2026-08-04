import 'package:flutter/material.dart';

class AdvisorySource {
  const AdvisorySource({
    required this.sourceName,
    required this.title,
    required this.url,
    required this.publishedAt,
  });

  final String sourceName;
  final String title;
  final String url;
  final DateTime publishedAt;

  factory AdvisorySource.fromJson(Map<String, dynamic> json) => AdvisorySource(
    sourceName: json['source_name'] as String? ?? 'News source',
    title: json['title'] as String? ?? 'Security report',
    url: json['url'] as String? ?? '',
    publishedAt:
        DateTime.tryParse(json['published_at'] as String? ?? '') ??
        DateTime.now().toUtc(),
  );
}

class SecurityAdvisory {
  const SecurityAdvisory({
    required this.id,
    required this.title,
    required this.summary,
    required this.type,
    required this.severity,
    required this.locationName,
    required this.locationConfidence,
    required this.status,
    required this.sourceCount,
    required this.articleCount,
    required this.firstPublishedAt,
    required this.lastUpdatedAt,
    required this.expiresAt,
    required this.sources,
    this.lat,
    this.lng,
    this.distanceKm,
    this.trendScore = 0,
  });

  final String id;
  final String title;
  final String summary;
  final String type;
  final String severity;
  final double? lat;
  final double? lng;
  final String locationName;
  final String locationConfidence;
  final String status;
  final int sourceCount;
  final int articleCount;
  final DateTime firstPublishedAt;
  final DateTime lastUpdatedAt;
  final DateTime expiresAt;
  final double? distanceKm;
  final double trendScore;
  final List<AdvisorySource> sources;

  bool get hasLocation => lat != null && lng != null;
  Color get markerColor => const Color(0xFF4DA3FF);
  String get sourceLabel =>
      sourceCount == 1 ? '1 news outlet' : '$sourceCount news outlets';
  String get confidenceLabel => switch (locationConfidence) {
    'exact' => 'Exact location',
    'city' => 'City-level location',
    'state' => 'State-level approximation',
    _ => 'Location unconfirmed',
  };
  String get time {
    final age = DateTime.now().toUtc().difference(lastUpdatedAt.toUtc());
    if (age.inMinutes < 1) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes} mins ago';
    if (age.inHours < 24) return '${age.inHours} hrs ago';
    return '${age.inDays} days ago';
  }

  factory SecurityAdvisory.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    final sourceItems = json['sources'] as List<dynamic>? ?? const [];
    return SecurityAdvisory(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Security advisory',
      summary:
          json['summary'] as String? ??
          'Open a publisher report for additional details.',
      type: json['type'] as String? ?? 'other',
      severity: json['severity'] as String? ?? 'medium',
      lat: (location?['lat'] as num?)?.toDouble(),
      lng: (location?['lng'] as num?)?.toDouble(),
      locationName: json['location_name'] as String? ?? 'Nigeria',
      locationConfidence: json['location_confidence'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'published',
      sourceCount: json['source_count'] as int? ?? 1,
      articleCount: json['article_count'] as int? ?? 1,
      firstPublishedAt:
          DateTime.tryParse(json['first_published_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      lastUpdatedAt:
          DateTime.tryParse(json['last_updated_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now().toUtc().add(const Duration(days: 3)),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      trendScore: (json['trend_score'] as num?)?.toDouble() ?? 0,
      sources: sourceItems
          .map(
            (item) =>
                AdvisorySource.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
