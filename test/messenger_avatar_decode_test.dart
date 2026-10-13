import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  testWidgets('MessengerAvatar shows initials while network image loads',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MessengerTheme(
          data: MessengerThemeData(),
          child: Scaffold(
            body: MessengerAvatar(
              label: 'AJ',
              imageUrl: 'https://example.invalid/slow-avatar.jpg',
              size: 26,
              compact: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('AJ'), findsOneWidget);
    await tester.pump();
  });
}
