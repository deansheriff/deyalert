import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  RealtimeChannel? _channel;

  Future<void> initialize() async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  void subscribeToIncidents({
    required String lga,
    required Future<void> Function() onIncident,
  }) {
    final client = AppConfig.supabase;
    if (client == null) return;
    _channel = client
        .channel('dey-alert-incidents')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'incidents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'lga',
            value: lga,
          ),
          callback: (_) async {
            await onIncident();
          },
        )
        .subscribe();
  }

  Future<void> showNearbyIncident() => _local.show(
    DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
    'New nearby safety report',
    'Open Dey Alert to review the location and verification status.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'nearby_incidents',
        'Nearby incidents',
        channelDescription: 'Security reports near your selected area',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );

  Future<void> dispose() async {
    final channel = _channel;
    final client = AppConfig.supabase;
    if (channel != null && client != null) await client.removeChannel(channel);
  }
}
