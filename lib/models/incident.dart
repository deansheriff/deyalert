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
    );
  }

  static String _prepositionFor(String type) =>
      type == 'fire_outbreak' || type == 'suspicious_activity' ? 'near' : 'on';
}

final demoIncidents = <Incident>[
  Incident(
    id: '10000000-0000-4000-8000-000000000001',
    type: 'roadblock',
    description:
        'Police checkpoint causing heavy traffic buildup. Use Opebi Road as an alternative.',
    locationName: 'Allen Avenue, Ikeja',
    lat: 6.6018,
    lng: 3.3515,
    status: 'corroborated',
    severity: 'medium',
    createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 15)),
    distanceKm: 1.2,
    corroborationCount: 3,
  ),
  Incident(
    id: '10000000-0000-4000-8000-000000000002',
    type: 'suspicious_activity',
    description:
        'Two people seen following commuters near the west entrance. Stay in groups.',
    locationName: 'Computer Village, Ikeja',
    lat: 6.6011,
    lng: 3.3421,
    status: 'unconfirmed',
    severity: 'medium',
    createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 45)),
    distanceKm: 2.4,
  ),
  Incident(
    id: '10000000-0000-4000-8000-000000000003',
    type: 'fire_outbreak',
    description:
        'Fire service is on the scene. Avoid the market road until the area is cleared.',
    locationName: 'Ikeja Market',
    lat: 6.5964,
    lng: 3.3419,
    status: 'confirmed',
    severity: 'high',
    createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    distanceKm: 3.1,
    corroborationCount: 5,
  ),
];
