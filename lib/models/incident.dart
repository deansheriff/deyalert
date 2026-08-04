import 'package:flutter/material.dart';

const demoUserId = '00000000-0000-4000-8000-000000000001';

class Incident {
  const Incident({
    required this.id,
    required this.type,
    required this.description,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.status,
    required this.severity,
    required this.createdAt,
    this.distanceKm,
    this.corroborationCount = 0,
    this.flagCount = 0,
    this.mediaUrls = const [],
  });

  final String id;
  final String type;
  final String description;
  final String locationName;
  final double lat;
  final double lng;
  final String status;
  final String severity;
  final DateTime createdAt;
  final double? distanceKm;
  final int corroborationCount;
  final int flagCount;
  final List<String> mediaUrls;

  String get displayType => switch (type) {
    'armed_robbery' => 'Armed robbery',
    'cult_clash' => 'Cult clash',
    'fire_outbreak' => 'Fire outbreak',
    'suspicious_activity' => 'Suspicious activity',
    _ =>
      type
          .split('_')
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' '),
  };

  String get title => '$displayType ${_prepositionFor(type)} $locationName';
  String get location => locationName;
  String get distance =>
      distanceKm == null ? 'Nearby' : '${distanceKm!.toStringAsFixed(1)} km';
  String get time {
    final age = DateTime.now().toUtc().difference(createdAt.toUtc());
    if (age.inMinutes < 1) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes} mins ago';
    if (age.inHours < 24) return '${age.inHours} hrs ago';
    return '${age.inDays} days ago';
  }

  String get displayStatus => switch (status) {
    'unconfirmed' => 'Unconfirmed',
    'corroborated' => 'Corroborated',
    'confirmed' => 'Confirmed',
    'false_report' => 'False report',
    _ => '${status[0].toUpperCase()}${status.substring(1)}',
  };

  Color get statusColor => switch (status) {
    'confirmed' || 'resolved' => const Color(0xFF27B878),
    'corroborated' => const Color(0xFFF5A623),
    _ => const Color(0xFFD64545),
  };

  IconData get icon => switch (type) {
    'kidnapping' => Icons.person_search,
    'armed_robbery' => Icons.local_police_outlined,
    'roadblock' => Icons.traffic,
    'cult_clash' => Icons.groups_2_outlined,
    'banditry' => Icons.warning_amber,
    'fire_outbreak' => Icons.local_fire_department_outlined,
    'suspicious_activity' => Icons.visibility_outlined,
    _ => Icons.more_horiz,
  };

  factory Incident.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>? ?? const {};
    return Incident(
      id: json['id'] as String,
      type: json['type'] as String,
      description: json['description'] as String? ?? 'No description provided.',
      locationName: json['location_name'] as String? ?? 'Nearby location',
      lat: (location['lat'] as num?)?.toDouble() ?? 0,
      lng: (location['lng'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'unconfirmed',
      severity: json['severity'] as String? ?? 'medium',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      corroborationCount: json['corroboration_count'] as int? ?? 0,
      flagCount: json['flag_count'] as int? ?? 0,
      mediaUrls: (json['media_urls'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  static String _prepositionFor(String type) =>
      type == 'fire_outbreak' || type == 'suspicious_activity' ? 'near' : 'on';
}
