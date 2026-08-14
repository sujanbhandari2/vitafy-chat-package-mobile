import 'dart:async';

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
  const cara = MessengerUser(
    id: 'c',
    username: 'cara_doe',
    roleLabel: 'Client',
  );

  MessengerConversation convWithPeer(
    String id,
    List<MessengerUser> peers,
  ) {
    return MessengerConversation(
      id: id,
      title: id,
      subtitle: 'Hello',
      avatarLabel: 'X',
      createdAt: DateTime.utc(2026),
      lastActivityAt: DateTime.utc(2026, 1, 2),
      peerUsers: peers,
    );
  }

  Widget wrapList({
    required MessengerConversationList list,
    Size size = const Size(360, 640),
  }) {
    return MaterialApp(
      home: MessengerTheme(
        data: const MessengerThemeData(),
        child: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: list,
          ),
        ),
      ),
    );
  }

  MessengerConversationList baseList({
    required List<MessengerConversation> conversations,
    required List<MessengerUser> users,
    bool isMobile = true,
    bool showAvailablePeopleOnMobileInbox = false,
    List<MessengerUser>? availablePeopleUsers,
    Widget Function(BuildContext, int)? conversationSectionHeaderBuilder,
    Widget Function(BuildContext, int)? availablePeopleSectionHeaderBuilder,
    Widget Function(BuildContext, MessengerAvailablePersonData)?
        availablePeopleItemBuilder,
    Widget Function(BuildContext, MessengerUserListItemData)?
        userListItemBuilder,
    FutureOr<void> Function(MessengerUser user)? onOpenDirectChat,
    MessengerSearchVisibility searchVisibility =
        MessengerSearchVisibility.never,
  }) {
    return MessengerConversationList(
      currentUserId: 'me',
      currentUserName: 'Me',
      conversations: conversations,
      users: users,
      selectedConversationId: conversations.isEmpty ? null : conversations.first.id,
      openingDirectUserId: '',
      onRefresh: () async {},
      onLogout: () {},
      onOpenDirectChat: onOpenDirectChat ?? (_) async {},
      onSelectConversation: (_) async {},
      searchVisibility: searchVisibility,
      showStartChatFab: false,
      isMobile: isMobile,
      showAvailablePeopleOnMobileInbox: showAvailablePeopleOnMobileInbox,
      availablePeopleUsers: availablePeopleUsers,
      conversationSectionHeaderBuilder: conversationSectionHeaderBuilder,
      availablePeopleSectionHeaderBuilder: availablePeopleSectionHeaderBuilder,
      availablePeopleItemBuilder: availablePeopleItemBuilder,
      userListItemBuilder: userListItemBuilder,
    );
  }

  group('messengerAvailablePeopleExcludingConversations', () {
    test('excludes peers and current user', () {
      final result = messengerAvailablePeopleExcludingConversations(
        allPeople: const [alice, bob, cara],
        conversations: [convWithPeer('c1', const [alice])],
        currentUserId: 'me',
        visibleConversationUsers: const [alice],
      );
      expect(result.map((u) => u.id), [bob.id, cara.id]);
    });

    test('excludes by email when directory id differs from conversation peer',
        () {
      const peerAlice = MessengerUser(
        id: 'chat-user-1',
        username: 'alice_jones',
        email: 'alice@example.com',
      );
      const directoryAlice = MessengerUser(
        id: 'external-user-1',
        username: 'alice_jones',
        email: 'alice@example.com',
      );
      final result = messengerAvailablePeopleExcludingConversations(
        allPeople: const [directoryAlice, bob],
        conversations: [convWithPeer('c1', const [peerAlice])],
        visibleConversationUsers: const [peerAlice],
      );
      expect(result.map((u) => u.id), [bob.id]);
    });

    test('excludes by externalUserId when directory uses platform id', () {
      const peerBob = MessengerUser(
        id: 'chat-user-2',
        username: 'bob_smith',
      );
      const directoryBob = MessengerUser(
        id: 'platform-user-2',
        externalUserId: 'chat-user-2',
        username: 'bob_smith',
      );
      final result = messengerAvailablePeopleExcludingConversations(
        allPeople: const [directoryBob, cara],
        conversations: [convWithPeer('c1', const [peerBob])],
        visibleConversationUsers: const [peerBob],
      );
      expect(result.map((u) => u.id), [cara.id]);
    });

    test('excludes self by platform id', () {
      const self = MessengerUser(
        id: 'platform-me',
        externalUserId: 'chat-me',
        username: 'me_user',
      );
      final result = messengerAvailablePeopleExcludingConversations(
        allPeople: const [self, alice, bob],
        conversations: const [],
        currentUserId: 'chat-me',
        currentPlatformUserId: 'platform-me',
      );
      expect(result.map((u) => u.id), [alice.id, bob.id]);
    });

    test('keeps same-name accounts when only one email matches a peer', () {
      const peerPratikClient = MessengerUser(
        id: 'chat-client',
        username: 'Pratik Adhikari',
        email: 'pratik+client@vitafyhealth.com',
        roleLabel: 'CLIENT',
      );
      const directoryPratikAdmin = MessengerUser(
        id: 'platform-admin',
        username: 'Pratik Adhikari',
        email: 'pratik+admin@vitafyhealth.com',
        roleLabel: 'ADMIN',
      );
      const directoryPratikAgent = MessengerUser(
        id: 'platform-agent',
        username: 'Pratik Adhikari',
        email: 'pratik+agent@vitafyhealth.com',
        roleLabel: 'AGENT',
      );
      final result = messengerAvailablePeopleExcludingConversations(
        allPeople: const [
          directoryPratikAdmin,
          directoryPratikAgent,
        ],
        conversations: [
          convWithPeer('c1', const [peerPratikClient]),
        ],
        visibleConversationUsers: const [peerPratikClient],
      );
      expect(result.map((u) => u.id), [
        directoryPratikAdmin.id,
        directoryPratikAgent.id,
      ]);
    });
  });

  group('MessengerConversationList available people section', () {
    testWidgets('flag false keeps single-section list', (tester) async {
      await tester.pumpWidget(
        wrapList(
          list: baseList(
            conversations: [convWithPeer('c1', const [alice])],
            users: const [alice, bob, cara],
            showAvailablePeopleOnMobileInbox: false,
            availablePeopleSectionHeaderBuilder: (_, __) =>
                const Text('People section'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Jones'), findsOneWidget);
      expect(find.text('People section'), findsNothing);
      expect(find.text('Bob Smith'), findsNothing);
    });

    testWidgets('flag true on mobile shows users without conversations',
        (tester) async {
      await tester.pumpWidget(
        wrapList(
          list: baseList(
            conversations: [convWithPeer('c1', const [alice])],
            users: const [alice, bob, cara],
            availablePeopleUsers: const [alice, bob, cara],
            showAvailablePeopleOnMobileInbox: true,
            availablePeopleSectionHeaderBuilder: (_, __) =>
                const Text('People section'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Jones'), findsOneWidget);
      expect(find.text('People section'), findsOneWidget);
      expect(find.text('Bob Smith'), findsOneWidget);
      expect(find.text('Cara Doe'), findsOneWidget);
    });

    testWidgets('dedupes peers already shown in conversation section',
        (tester) async {
      await tester.pumpWidget(
        wrapList(
          list: baseList(
            conversations: [convWithPeer('c1', const [alice])],
            users: const [alice, bob],
            availablePeopleUsers: const [alice, bob],
            showAvailablePeopleOnMobileInbox: true,
            availablePeopleItemBuilder: (context, data) =>
                Text('available-${data.user.id}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Jones'), findsOneWidget);
      expect(find.text('available-a'), findsNothing);
      expect(find.text('available-b'), findsOneWidget);
    });

    testWidgets(
        'dedupes by email when people directory id differs from chat peer id',
        (tester) async {
      const peerAlice = MessengerUser(
        id: 'chat-user-1',
        username: 'alice_jones',
        email: 'alice@example.com',
      );
      const directoryAlice = MessengerUser(
        id: 'external-user-1',
        username: 'alice_jones',
        email: 'alice@example.com',
      );
      await tester.pumpWidget(
        wrapList(
          list: baseList(
            conversations: [convWithPeer('c1', const [peerAlice])],
            users: const [directoryAlice, bob],
            availablePeopleUsers: const [directoryAlice, bob],
            showAvailablePeopleOnMobileInbox: true,
            availablePeopleItemBuilder: (context, data) =>
                Text('available-${data.user.id}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Jones'), findsOneWidget);
      expect(find.text('available-external-user-1'), findsNothing);
      expect(find.text('available-b'), findsOneWidget);
    });

    testWidgets('availablePeopleItemBuilder renders custom section rows',
        (tester) async {
      await tester.pumpWidget(
        wrapList(
          list: baseList(
            conversations: [convWithPeer('c1', const [alice])],
            users: const [alice, bob],
            availablePeopleUsers: const [bob],
            showAvailablePeopleOnMobileInbox: true,
            availablePeopleItemBuilder: (context, data) =>
                Text('available-${data.user.username}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('available-bob_smith'), findsOneWidget);
    });

    testWidgets('userListItemBuilder applies to conversation rows only',
        (tester) async {
      await tester.pumpWidget(
        wrapList(
          list: baseList(
            conversations: [convWithPeer('c1', const [alice])],
            users: const [alice, bob],
            availablePeopleUsers: const [bob],
            showAvailablePeopleOnMobileInbox: true,
            userListItemBuilder: (context, data) =>
                Text('conversation-${data.user.username}'),
            availablePeopleItemBuilder: (context, data) =>
                Text('available-${data.user.username}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('conversation-alice_jones'), findsOneWidget);
      expect(find.text('available-bob_smith'), findsOneWidget);
      expect(find.text('conversation-bob_smith'), findsNothing);
    });

    testWidgets('desktop shows available people when flagged', (tester) async {
      await tester.pumpWidget(
        wrapList(
          list: baseList(
            conversations: [convWithPeer('c1', const [alice])],
            users: const [alice, bob],
            availablePeopleUsers: const [bob],
            isMobile: false,
            showAvailablePeopleOnMobileInbox: true,
            availablePeopleItemBuilder: (context, data) =>
                Text('available-${data.user.id}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('available-b'), findsOneWidget);
    });

    testWidgets(
        'title-only conversations render as rows with remaining people below',
        (tester) async {
      const peerAlice = MessengerUser(
        id: 'chat-user-1',
        username: 'alice_jones',
        email: 'alice@example.com',
      );
      const directoryBob = MessengerUser(
        id: 'platform-bob',
        username: 'bob_smith',
        email: 'bob@example.com',
      );
      await tester.pumpWidget(
        wrapList(
          list: baseList(
            conversations: [
              MessengerConversation(
                id: 'c1',
                title: 'Alice Jones',
                subtitle: 'Hey',
                avatarLabel: 'A',
                peerUsers: const [peerAlice],
                createdAt: DateTime.utc(2026),
              ),
            ],
            users: const [directoryBob],
            availablePeopleUsers: const [directoryBob],
            showAvailablePeopleOnMobileInbox: true,
            availablePeopleItemBuilder: (context, data) =>
                Text('available-${data.user.id}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Jones'), findsOneWidget);
      expect(find.text('available-platform-bob'), findsOneWidget);
    });

    testWidgets('search filters both sections', (tester) async {
      await tester.pumpWidget(
        wrapList(
          list: baseList(
            conversations: [convWithPeer('c1', const [alice])],
            users: const [alice, bob, cara],
            availablePeopleUsers: const [bob, cara],
            showAvailablePeopleOnMobileInbox: true,
            searchVisibility: MessengerSearchVisibility.always,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cara');
      await tester.pumpAndSettle();

      expect(find.text('Alice Jones'), findsNothing);
      expect(find.text('Bob Smith'), findsNothing);
      expect(find.text('Cara Doe'), findsOneWidget);
    });

    testWidgets('flag true on mobile shows people with zero conversations',
        (tester) async {
      await tester.pumpWidget(
        wrapList(
          list: baseList(
            conversations: const [],
            users: const [alice, bob],
            availablePeopleUsers: const [alice, bob],
            showAvailablePeopleOnMobileInbox: true,
            availablePeopleSectionHeaderBuilder: (_, __) =>
                const Text('People section'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('People section'), findsOneWidget);
      expect(find.text('Alice Jones'), findsOneWidget);
      expect(find.text('Bob Smith'), findsOneWidget);
    });

    testWidgets('tap available person invokes onOpenDirectChat', (tester) async {
      MessengerUser? tapped;
      await tester.pumpWidget(
        wrapList(
          list: baseList(
            conversations: [convWithPeer('c1', const [alice])],
            users: const [alice, bob],
            availablePeopleUsers: const [bob],
            showAvailablePeopleOnMobileInbox: true,
            availablePeopleItemBuilder: (context, data) => ListTile(
              title: Text(data.user.username),
              onTap: data.onTap,
            ),
            onOpenDirectChat: (user) async {
              tapped = user;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('bob_smith'));
      await tester.pumpAndSettle();

      expect(tapped, bob);
    });
  });
}
