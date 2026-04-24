import 'package:flutter_test/flutter_test.dart';

import 'package:health_messenger_ui_example/main.dart';

void main() {
  testWidgets('example app renders configuration screen', (tester) async {
    await tester.pumpWidget(const MessengerExampleApp());

    expect(find.text('Chat Configuration'), findsOneWidget);
    expect(find.text('Configure your chat session'), findsOneWidget);
    expect(find.text('Open Chat'), findsOneWidget);
  });
}
