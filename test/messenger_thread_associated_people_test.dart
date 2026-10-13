import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  const alice = MessengerUser(
    id: 'a',
    username: 'alice_jones',
    roleLabel: 'Nurse',
  );
  const bob = MessengerUser(
    id: 'b',
    username: 'bob_smith',
    roleLabel: 'Doctor',
  );

  group('messengerAssociatedPeopleForThread', () {
    test('excludes peers in the open conversation', () {
      final conversation = MessengerConversation(
        id: 'c1',
        title: 'Alice Jones',
        subtitle: 'Hi',
        avatarLabel: 'AJ',
        createdAt: DateTime.utc(2026),
        peerUsers: const [alice],
      );

      final people = messengerAssociatedPeopleForThread(
        allPeople: const [alice, bob],
        conversation: conversation,
        currentUserId: 'me',
      );

      expect(people.map((user) => user.id), ['b']);
    });
  });

  group('MessengerThreadAssociatedPeoplePanel', () {
    testWidgets('renders associated people below header in thread', (tester) async {
      final composer = TextEditingController();
      final scroll = ScrollController();
      addTearDown(() {
        composer.dispose();
        scroll.dispose();
      });

      final conversation = MessengerConversation(
        id: 'c1',
        title: 'Alice Jones',
        subtitle: 'Hi',
        avatarLabel: 'AJ',
        createdAt: DateTime.utc(2026),
        peerUsers: const [alice],
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
                  showAssociatedPeopleOnThread: true,
                  associatedPeopleUsers: const [alice, bob],
                  associatedPeopleSectionHeaderBuilder: (_, count) =>
                      Text('Associated ($count)'),
                  onOpenAssociatedPerson: (_) async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Associated (1)'), findsOneWidget);
      expect(find.text('Bob Smith'), findsOneWidget);
      expect(find.text('Alice Jones'), findsWidgets);
      expect(find.byType(MessengerThreadAssociatedPeoplePanel), findsOneWidget);
    });

    testWidgets('hidden when showAssociatedPeopleOnThread is false',
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
              body: SizedBox(
                height: 640,
                width: 400,
                child: MessengerChatThread(
                  conversation: MessengerConversation(
                    id: 'c1',
                    title: 'Alice Jones',
                    subtitle: 'Hi',
                    avatarLabel: 'AJ',
                    createdAt: DateTime.utc(2026),
                    peerUsers: const [alice],
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
                  associatedPeopleUsers: const [bob],
                  onOpenAssociatedPerson: (_) async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MessengerThreadAssociatedPeoplePanel), findsNothing);
    });
  });
}
