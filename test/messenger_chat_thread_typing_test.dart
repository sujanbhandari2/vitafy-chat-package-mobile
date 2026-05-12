import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  testWidgets('MessengerChatThread shows remote typing strip', (tester) async {
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
          child: Scaffold(
            body: MessengerChatThread(
              conversation: MessengerConversation(
                id: 'c1',
                title: 'Test',
                subtitle: 'Sub',
                avatarLabel: 'T',
                createdAt: DateTime.utc(2026),
              ),
              messages: const [],
              currentUserId: 'me',
              composerController: composer,
              messagesScrollController: scroll,
              isSending: false,
              isRecording: false,
              onSend: () {},
              onPickImage: () {},
              onPickAudio: () {},
              onStartRecording: () {},
              onFinishRecording: () {},
              onCancelRecording: () {},
              onToggleRecording: () {},
              remoteTypingUsers: const [
                MessengerTypingUser(userId: 'u1', displayLabel: 'Alice'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Alice is typing'), findsOneWidget);
  });

  testWidgets('MessengerChatThread uses custom loading builder',
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
          child: Scaffold(
            body: MessengerChatThread(
              conversation: MessengerConversation(
                id: 'c1',
                title: 'Test',
                subtitle: 'Sub',
                avatarLabel: 'T',
                createdAt: DateTime.utc(2026),
              ),
              messages: const [],
              isConversationLoading: true,
              loadingMessagesBuilder: (_) => const Center(
                child: Text('Loading custom'),
              ),
              currentUserId: 'me',
              composerController: composer,
              messagesScrollController: scroll,
              isSending: false,
              isRecording: false,
              onSend: () {},
              onPickImage: () {},
              onPickAudio: () {},
              onStartRecording: () {},
              onFinishRecording: () {},
              onCancelRecording: () {},
              onToggleRecording: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Loading custom'), findsOneWidget);
    expect(find.text('No messages yet.'), findsNothing);
  });

  testWidgets(
      'MessengerChatThread replaceMessageList hides messages while loading',
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
          child: Scaffold(
            body: MessengerChatThread(
              conversation: MessengerConversation(
                id: 'c1',
                title: 'Test',
                subtitle: 'Sub',
                avatarLabel: 'T',
                createdAt: DateTime.utc(2026),
              ),
              messages: [
                MessengerChatMessage(
                  id: 'm1',
                  senderId: 'u1',
                  senderLabel: 'Alice',
                  type: MessengerMessageType.text,
                  content: 'visible-when-idle',
                  createdAt: DateTime.utc(2026),
                ),
              ],
              isConversationLoading: true,
              threadFetchLoadingMode:
                  MessengerThreadFetchLoadingMode.replaceMessageList,
              currentUserId: 'me',
              composerController: composer,
              messagesScrollController: scroll,
              isSending: false,
              isRecording: false,
              onSend: () {},
              onPickImage: () {},
              onPickAudio: () {},
              onStartRecording: () {},
              onFinishRecording: () {},
              onCancelRecording: () {},
              onToggleRecording: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('visible-when-idle'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
