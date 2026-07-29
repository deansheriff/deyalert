import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dey_alert/main.dart';
import 'package:dey_alert/models/incident.dart';

void main() {
  testWidgets('Dey Alert opens on the onboarding experience', (tester) async {
    await tester.pumpWidget(const DeyAlertApp());
    expect(find.text('dey alert'), findsOneWidget);
    expect(find.text('Report incidents in seconds'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('demo OTP reaches profile setup', (tester) async {
    await tester.pumpWidget(const DeyAlertApp());
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '08012345678');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify & continue'));
    await tester.pumpAndSettle();

    expect(find.text('Complete your profile'), findsOneWidget);
  });

  test('incident API payload maps to presentation fields', () {
    final incident = Incident.fromJson({
      'id': '10000000-0000-4000-8000-000000000001',
      'type': 'armed_robbery',
      'description': 'Reported near the junction.',
      'location_name': 'Opebi Road',
      'location': {'lat': 6.59, 'lng': 3.36},
      'status': 'confirmed',
      'severity': 'high',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'distance_km': 1.25,
      'corroboration_count': 4,
    });

    expect(incident.displayType, 'Armed robbery');
    expect(incident.displayStatus, 'Confirmed');
    expect(incident.distance, '1.3 km');
    expect(incident.corroborationCount, 4);
  });
}
