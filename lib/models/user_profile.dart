class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.state,
    required this.lga,
    required this.ward,
    required this.alertRadiusKm,
    required this.locationPrecision,
    required this.role,
    this.email,
    this.phone,
    this.phoneVerified = false,
  });

  final String id;
  final String? email;
  final String? phone;
  final bool phoneVerified;
  final String name;
  final String state;
  final String lga;
  final String ward;
  final double alertRadiusKm;
  final String locationPrecision;
  final String role;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    phoneVerified: json['phone_verified'] as bool? ?? false,
    name: json['name'] as String,
    state: json['state'] as String,
    lga: json['lga'] as String,
    ward: json['ward'] as String,
    alertRadiusKm: (json['alert_radius_km'] as num?)?.toDouble() ?? 5,
    locationPrecision: json['location_precision'] as String? ?? 'ward',
    role: json['role'] as String? ?? 'member',
  );
}
