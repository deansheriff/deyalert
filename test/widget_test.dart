import 'package:flutter_test/flutter_test.dart';

import 'package:dey_alert/main.dart';

void main() {
  testWidgets('Dey Alert opens on the onboarding experience', (tester) async {
    await tester.pumpWidget(const DeyAlertApp());
    expect(find.text('dey alert'), findsOneWidget);
    expect(find.text('Report incidents in seconds'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });
}
