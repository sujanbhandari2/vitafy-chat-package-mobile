import 'package:flutter_test/flutter_test.dart';

import 'package:health_messenger_ui_example/main.dart';

void main() {
  testWidgets('example app renders package flow bootstrap screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MessengerExampleApp());

    expect(find.text('Exact Package Flow Example'), findsOneWidget);
    expect(find.text('Bootstrap Package Flow'), findsOneWidget);
    expect(find.text('Transport logs will appear here.'), findsOneWidget);
  });
}
