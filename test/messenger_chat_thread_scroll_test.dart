import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  testWidgets(
    'scheduleJumpToBottom reaches max extent after loading→messages transition',
    (tester) async {
      final composer = TextEditingController();
      final scroll = ScrollController();
      addTearDown(() {
        composer.dispose();
        scroll.dispose();
      });

      final conversation = MessengerConversation(
        id: 'c1',
        title: 'Test',
        subtitle: 'Sub',
        avatarLabel: 'T',
        createdAt: DateTime.utc(2026),
      );

      Future<void> pumpThread({
        required bool loading,
        required List<MessengerChatMessage> messages,
      }) {
        return tester.pumpWidget(
          MaterialApp(
            home: MessengerTheme(
              data: const MessengerThemeData(),
              child: Scaffold(
                body: SizedBox(
                  height: 640,
                  width: 400,
                  child: MessengerChatThread(
                    conversation: conversation,
                    messages: messages,
                    isConversationLoading: loading && messages.isEmpty,
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
          ),
        );
      }

      await pumpThread(loading: true, messages: const []);
      await tester.pump();
      await pumpThread(
        loading: false,
        messages: _sampleMessages(30),
      );
      MessengerThreadScroll.scheduleJumpToBottom(scroll);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(scroll.hasClients, isTrue);
      expect(
        scroll.position.pixels,
        closeTo(scroll.position.maxScrollExtent, 3),
      );
    },
  );

  testWidgets(
    'keyboard inset change re-anchors scroll to bottom when snap enabled',
    (tester) async {
      final composer = TextEditingController();
      final scroll = ScrollController();
      addTearDown(() {
        composer.dispose();
        scroll.dispose();
      });

      final conversation = MessengerConversation(
        id: 'c1',
        title: 'Test',
        subtitle: 'Sub',
        avatarLabel: 'T',
        createdAt: DateTime.utc(2026),
      );

      Widget buildHarness({required double viewInsetBottom}) {
        return MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 700),
              viewInsets: EdgeInsets.only(bottom: viewInsetBottom),
            ),
            child: MessengerTheme(
              data: const MessengerThemeData(),
              child: Scaffold(
                body: SizedBox(
                  height: 700,
                  width: 400,
                  child: MessengerChatThread(
                    conversation: conversation,
                    messages: _sampleMessages(20),
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
                    snapToBottomOnKeyboardInsetChange: true,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness(viewInsetBottom: 0));
      MessengerThreadScroll.scheduleJumpToBottom(scroll);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.pumpWidget(buildHarness(viewInsetBottom: 280));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(scroll.hasClients, isTrue);
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      expect(
        scroll.position.pixels,
        closeTo(scroll.position.maxScrollExtent, 3),
      );
    },
  );

  testWidgets(
    'last message sits close to composer (no large list bottom slack)',
    (tester) async {
      final composer = TextEditingController();
      final scroll = ScrollController();
      addTearDown(() {
        composer.dispose();
        scroll.dispose();
      });

      final conversation = MessengerConversation(
        id: 'c1',
        title: 'Test',
        subtitle: 'Sub',
        avatarLabel: 'T',
        createdAt: DateTime.utc(2026),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MessengerTheme(
            data: const MessengerThemeData(),
            child: Scaffold(
              body: SizedBox(
                height: 640,
                width: 400,
                child: MessengerChatThread(
                  conversation: conversation,
                  messages: [
                    MessengerChatMessage(
                      id: 'm1',
                      senderId: 'u1',
                      senderLabel: 'Alice',
                      type: MessengerMessageType.text,
                      content: 'Line\n' * 25,
                      createdAt: DateTime.utc(2026, 1, 1),
                    ),
                  ],
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
        ),
      );
      MessengerThreadScroll.scheduleJumpToBottom(scroll);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final bubbleRect =
          tester.getRect(find.byType(MessengerMessageBubble).last);
      final composerRect = tester.getRect(find.byType(MessengerComposerBar));

      expect(
        composerRect.top - bubbleRect.bottom,
        lessThan(48),
        reason:
            'expect small gap (list bottom padding + column), not ~88px slack',
      );
    },
  );
}

List<MessengerChatMessage> _sampleMessages(int count) {
  return List<MessengerChatMessage>.generate(
    count,
    (i) => MessengerChatMessage(
      id: 'm$i',
      senderId: i.isEven ? 'me' : 'u1',
      senderLabel: i.isEven ? 'Me' : 'Alice',
      type: MessengerMessageType.text,
      content: 'Message $i ${'x' * 40}',
      createdAt: DateTime.utc(2026, 1, 1, 0, 0, i),
    ),
  );
}
