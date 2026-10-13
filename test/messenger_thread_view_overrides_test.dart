import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

MessengerConversation _testConversation() {
  return MessengerConversation(
    id: 'c1',
    title: 'Alice Jones',
    subtitle: 'Hello',
    avatarLabel: 'A',
    createdAt: DateTime.utc(2026),
  );
}

MessengerChatMessage _textMessage({
  String id = 'm1',
  String senderId = 'peer',
  String content = 'Hello world',
}) {
  return MessengerChatMessage(
    id: id,
    senderId: senderId,
    senderLabel: 'Alice',
    type: MessengerMessageType.text,
    content: content,
    createdAt: DateTime.utc(2026, 1, 1, 12),
  );
}

Future<void> _pumpThread(
  WidgetTester tester, {
  required TextEditingController composer,
  required ScrollController scroll,
  List<MessengerChatMessage> messages = const [],
  MessengerThreadViewOverrides? threadViewOverrides,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MessengerTheme(
        data: const MessengerThemeData(),
        child: Scaffold(
          body: SizedBox(
            height: 640,
            width: 400,
            child: MessengerChatThread(
              conversation: _testConversation(),
              messages: messages,
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
              composerHintText: 'Type your message...',
              threadViewOverrides: threadViewOverrides,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('messengerResolveMessageContentKind', () {
    test('maps plain text messages', () {
      expect(
        messengerResolveMessageContentKind(_textMessage()),
        MessengerMessageContentKind.text,
      );
    });

    test('maps deleted messages', () {
      expect(
        messengerResolveMessageContentKind(
          MessengerChatMessage(
            id: 'm1',
            senderId: 'peer',
            senderLabel: 'Alice',
            type: MessengerMessageType.text,
            content: 'gone',
            createdAt: DateTime.utc(2026),
            isDeleted: true,
          ),
        ),
        MessengerMessageContentKind.deleted,
      );
    });
  });

  group('MessengerChatThread threadViewOverrides', () {
    testWidgets('defaults unchanged when overrides are null', (tester) async {
      final composer = TextEditingController();
      final scroll = ScrollController();
      addTearDown(() {
        composer.dispose();
        scroll.dispose();
      });

      await _pumpThread(
        tester,
        composer: composer,
        scroll: scroll,
        messages: [_textMessage()],
      );

      expect(find.text('Alice Jones'), findsOneWidget);
      expect(find.text('Hello world'), findsOneWidget);
      expect(find.text('AJ'), findsOneWidget);
      expect(find.byType(MessengerComposerBar), findsOneWidget);
      expect(find.text('Type your message...'), findsOneWidget);
    });

    testWidgets('headerBuilder replaces default header', (tester) async {
      final composer = TextEditingController();
      final scroll = ScrollController();
      addTearDown(() {
        composer.dispose();
        scroll.dispose();
      });

      await _pumpThread(
        tester,
        composer: composer,
        scroll: scroll,
        threadViewOverrides: MessengerThreadViewOverrides(
          headerBuilder: (context, data) => const Text('Custom Header'),
        ),
      );

      expect(find.text('Custom Header'), findsOneWidget);
      expect(find.text('Alice Jones'), findsNothing);
    });

    testWidgets('textBuilder replaces text bubble content only', (tester) async {
      final composer = TextEditingController();
      final scroll = ScrollController();
      addTearDown(() {
        composer.dispose();
        scroll.dispose();
      });

      await _pumpThread(
        tester,
        composer: composer,
        scroll: scroll,
        messages: [_textMessage(content: 'Original text')],
        threadViewOverrides: MessengerThreadViewOverrides(
          messageContentBuilders: MessengerMessageContentBuilders(
            textBuilder: (context, data) => Text('Custom: ${data.message.content}'),
          ),
        ),
      );

      expect(find.text('Custom: Original text'), findsOneWidget);
      expect(find.text('Original text'), findsNothing);
      expect(find.byType(MessengerMessageBubble), findsOneWidget);
    });

    testWidgets('messageBubbleBuilder replaces entire bubble', (tester) async {
      final composer = TextEditingController();
      final scroll = ScrollController();
      addTearDown(() {
        composer.dispose();
        scroll.dispose();
      });

      await _pumpThread(
        tester,
        composer: composer,
        scroll: scroll,
        messages: [_textMessage(content: 'Hidden')],
        threadViewOverrides: MessengerThreadViewOverrides(
          messageBubbleBuilder: (context, data) => Text('Bubble: ${data.message.content}'),
        ),
      );

      expect(find.text('Bubble: Hidden'), findsOneWidget);
      expect(find.byType(MessengerMessageBubble), findsNothing);
    });

    testWidgets('composerBuilder replaces composer bar', (tester) async {
      final composer = TextEditingController();
      final scroll = ScrollController();
      addTearDown(() {
        composer.dispose();
        scroll.dispose();
      });

      await _pumpThread(
        tester,
        composer: composer,
        scroll: scroll,
        threadViewOverrides: MessengerThreadViewOverrides(
          composerBuilder: (context, data) => const Text('Custom Composer'),
        ),
      );

      expect(find.text('Custom Composer'), findsOneWidget);
      expect(find.byType(MessengerComposerBar), findsNothing);
    });

    testWidgets('threadOverlayBuilder shows floating widget', (tester) async {
      final composer = TextEditingController();
      final scroll = ScrollController();
      addTearDown(() {
        composer.dispose();
        scroll.dispose();
      });

      await _pumpThread(
        tester,
        composer: composer,
        scroll: scroll,
        messages: [_textMessage()],
        threadViewOverrides: MessengerThreadViewOverrides(
          threadOverlayBuilder: (context, data) => const Text('Floating Widget'),
        ),
      );

      expect(find.text('Floating Widget'), findsOneWidget);
    });
  });

  testWidgets('MessengerChatShell passes threadViewOverrides to thread',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    final conversation = _testConversation();

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 800,
              width: 1200,
              child: MessengerChatShell(
                currentUserId: 'me',
                currentUserName: 'Me',
                conversations: [conversation],
                users: const [],
                selectedConversationId: conversation.id,
                messages: [_textMessage()],
                composerController: composer,
                messagesScrollController: scroll,
                isSending: false,
                isRecording: false,
                onRefresh: () async {},
                onLogout: () {},
                onSelectConversation: (_) async {},
                onOpenDirectChat: (_) async {},
                onSend: () {},
                onPickImage: () {},
                onPickAudio: () {},
                onToggleRecording: () {},
                desktopBreakpoint: 400,
                threadViewOverrides: MessengerThreadViewOverrides(
                  headerBuilder: (context, data) =>
                      const Text('Shell Custom Header'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(MessengerChatThread),
        matching: find.text('Shell Custom Header'),
      ),
      findsOneWidget,
    );
  });
}
