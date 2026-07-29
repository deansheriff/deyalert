import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dey_alert/main.dart';
import 'package:dey_alert/models/advisory.dart';
import 'package:dey_alert/models/incident.dart';

void main() {
  testWidgets('Dey Alert opens on the onboarding experience', (tester) async {
    await tester.pumpWidget(const DeyAlertApp());
    expect(find.text('dey alert'), findsOneWidget);
    expect(find.text('Report incidents in seconds'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('demo email login reaches profile setup', (tester) async {
    await tester.pumpWidget(const DeyAlertApp());
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'demo@deyalert.local');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Sign in & continue'));
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

  test('security advisory payload preserves sources and map location', () {
    final advisory = SecurityAdvisory.fromJson({
      'id': '20000000-0000-4000-8000-000000000001',
      'title': 'Security agencies issue advisory in Maiduguri',
      'summary': 'Residents were advised to avoid a named area.',
      'type': 'suspicious_activity',
      'severity': 'medium',
      'location': {'lat': 11.8333, 'lng': 13.15},
      'location_name': 'Maiduguri',
      'location_confidence': 'city',
      'status': 'published',
      'source_count': 2,
      'article_count': 3,
      'first_published_at': '2026-07-29T08:00:00Z',
      'last_updated_at': '2026-07-29T09:00:00Z',
      'expires_at': '2026-08-01T09:00:00Z',
      'trend_score': 12.5,
      'sources': [
        {
          'source_name': 'Example News',
          'title': 'Security advisory in Maiduguri',
          'url': 'https://news.example/story',
          'published_at': '2026-07-29T08:00:00Z',
        },
      ],
    });

    expect(advisory.hasLocation, isTrue);
    expect(advisory.locationName, 'Maiduguri');
    expect(advisory.confidenceLabel, 'City-level location');
    expect(advisory.sourceLabel, '2 news outlets');
    expect(advisory.sources.single.sourceName, 'Example News');
  });
}
