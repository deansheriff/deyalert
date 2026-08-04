class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.createdAt,
    this.incidentId,
    this.readAt,
  });

  final String id;
  final String? incidentId;
  final String title;
  final String body;
  final String severity;
  final DateTime createdAt;
  final DateTime? readAt;
  bool get isUnread => readAt == null;

  String get time {
    final age = DateTime.now().toUtc().difference(createdAt.toUtc());
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        incidentId: json['incident_id'] as String?,
        title: json['title'] as String,
        body: json['body'] as String,
        severity: json['severity'] as String? ?? 'medium',
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
      );
}
