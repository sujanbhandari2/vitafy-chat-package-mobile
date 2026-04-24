import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  testWidgets('MessengerChatShell shows empty conversations placeholder',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: MessengerChatShell(
          currentUserId: 'me',
          currentUserName: 'Me',
          conversations: const [],
          users: const [],
          selectedConversationId: null,
          messages: const [],
          composerController: composer,
          messagesScrollController: scroll,
          isSending: false,
          isRecording: false,
          onRefresh: () {},
          onLogout: () {},
          onSelectConversation: (_) async {},
          onOpenDirectChat: (_) async {},
          onSend: () {},
          onPickImage: () {},
          onPickAudio: () {},
          onToggleRecording: () {},
          emptyConversationsMessage: 'No chats yet',
        ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No chats yet'), findsOneWidget);
  });
}
