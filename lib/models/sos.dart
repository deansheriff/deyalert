class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship,
  });

  final String id;
  final String name;
  final String phone;
  final String? relationship;

  String get maskedPhone {
    if (phone.length < 6) return phone;
    return '${phone.substring(0, 5)} ••• ${phone.substring(phone.length - 2)}';
  }

  factory TrustedContact.fromJson(Map<String, dynamic> json) => TrustedContact(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    relationship: json['relationship'] as String?,
  );
}

class SosReadiness {
  const SosReadiness({
    required this.ready,
    required this.contactCount,
    required this.smsProvider,
    required this.message,
  });

  final bool ready;
  final int contactCount;
  final String smsProvider;
  final String message;

  factory SosReadiness.fromJson(Map<String, dynamic> json) => SosReadiness(
    ready: json['ready'] as bool? ?? false,
    contactCount: json['contact_count'] as int? ?? 0,
    smsProvider: json['sms_provider'] as String? ?? 'disabled',
    message: json['message'] as String? ?? 'SOS unavailable',
  );
}

class SosResult {
  const SosResult({required this.deliveredTo, required this.contactCount});
  final int deliveredTo;
  final int contactCount;

  factory SosResult.fromJson(Map<String, dynamic> json) => SosResult(
    deliveredTo: json['delivered_to'] as int? ?? 0,
    contactCount: json['contact_count'] as int? ?? 0,
  );
}
