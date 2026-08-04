class VerifierRecord {
  const VerifierRecord({
    required this.id,
    required this.userId,
    required this.lga,
    required this.isActive,
    this.state,
    this.ward,
    this.title,
  });
  final String id;
  final String userId;
  final String? state;
  final String lga;
  final String? ward;
  final String? title;
  final bool isActive;

  factory VerifierRecord.fromJson(Map<String, dynamic> json) => VerifierRecord(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    state: json['state'] as String?,
    lga: json['lga'] as String,
    ward: json['ward'] as String?,
    title: json['title'] as String?,
    isActive: json['is_active'] as bool? ?? true,
  );
}
