import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: MessengerTheme(
        data: const MessengerThemeData(),
        child: Scaffold(body: child),
      ),
    );
  }

  const alice = MessengerUser(id: 'u1', username: 'alice');
  const bob = MessengerUser(id: 'u2', username: 'bob');
  const carol = MessengerUser(
    id: 'u3',
    username: 'carol',
    roleLabel: 'Nurse',
  );

  testWidgets('renders default title and helper text', (tester) async {
    await tester.pumpWidget(
      wrap(
        MessengerSuggestedPeoplePanel(
          users: const [alice, bob],
          onUserSelected: (_) {},
        ),
      ),
    );

    expect(find.text('Suggested people'), findsOneWidget);
    expect(
      find.text(
          "You don't have any conversations yet. Choose someone to start messaging."),
      findsOneWidget,
    );
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
  });

  testWidgets('titleWidget overrides default title text', (tester) async {
    await tester.pumpWidget(
      wrap(
        MessengerSuggestedPeoplePanel(
          users: const [alice],
          onUserSelected: (_) {},
          titleWidget: const Text('Custom heading'),
        ),
      ),
    );

    expect(find.text('Custom heading'), findsOneWidget);
    expect(find.text('Suggested people'), findsNothing);
  });

  testWidgets('headerBuilder replaces both title and helper', (tester) async {
    await tester.pumpWidget(
      wrap(
        MessengerSuggestedPeoplePanel(
          users: const [alice],
          onUserSelected: (_) {},
          headerBuilder: (context, users) =>
              Text('Pick one of ${users.length}'),
        ),
      ),
    );

    expect(find.text('Pick one of 1'), findsOneWidget);
    expect(find.text('Suggested people'), findsNothing);
    expect(
      find.text(
          "You don't have any conversations yet. Choose someone to start messaging."),
      findsNothing,
    );
  });

  testWidgets('itemBuilder is used per row', (tester) async {
    await tester.pumpWidget(
      wrap(
        MessengerSuggestedPeoplePanel(
          users: const [alice, bob],
          onUserSelected: (_) {},
          itemBuilder: (context, user, index) => ListTile(
            key: ValueKey('row-${user.id}'),
            title: Text('Row ${user.username}'),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('row-u1')), findsOneWidget);
    expect(find.byKey(const ValueKey('row-u2')), findsOneWidget);
    expect(find.text('Row alice'), findsOneWidget);
    expect(find.text('Row bob'), findsOneWidget);
  });

  testWidgets('tapping default row invokes onUserSelected', (tester) async {
    MessengerUser? tapped;

    await tester.pumpWidget(
      wrap(
        MessengerSuggestedPeoplePanel(
          users: const [alice, bob],
          onUserSelected: (user) => tapped = user,
        ),
      ),
    );

    await tester.tap(find.text('bob'));
    await tester.pumpAndSettle();

    expect(tapped, isNotNull);
    expect(tapped!.id, 'u2');
  });

  testWidgets('empty state shows default emptyText', (tester) async {
    await tester.pumpWidget(
      wrap(
        MessengerSuggestedPeoplePanel(
          users: const [],
          onUserSelected: (_) {},
        ),
      ),
    );

    expect(find.text('No people available right now.'), findsOneWidget);
  });

  testWidgets('emptyBuilder overrides default empty text', (tester) async {
    await tester.pumpWidget(
      wrap(
        MessengerSuggestedPeoplePanel(
          users: const [],
          onUserSelected: (_) {},
          emptyBuilder: (_) => const Text('Nobody around'),
        ),
      ),
    );

    expect(find.text('Nobody around'), findsOneWidget);
    expect(find.text('No people available right now.'), findsNothing);
  });

  testWidgets('isLoading shows default loading branch', (tester) async {
    await tester.pumpWidget(
      wrap(
        MessengerSuggestedPeoplePanel(
          users: const [alice],
          onUserSelected: (_) {},
          isLoading: true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('alice'), findsNothing);
  });

  testWidgets('loadingBuilder overrides default loading widget',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        MessengerSuggestedPeoplePanel(
          users: const [alice],
          onUserSelected: (_) {},
          isLoading: true,
          loadingBuilder: (_) => const Text('Fetching people'),
        ),
      ),
    );

    expect(find.text('Fetching people'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('onPullToRefresh is invoked on overscroll', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 400,
              width: 360,
              child: MessengerSuggestedPeoplePanel(
                users: const [alice, bob],
                onUserSelected: (_) {},
                onPullToRefresh: () async {
                  count++;
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 400),
      2000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(count, 1);
  });

  testWidgets('search field filters users by name and role', (tester) async {
    var query = '';

    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return MessengerSuggestedPeoplePanel(
              users: const [alice, bob, carol],
              onUserSelected: (_) {},
              showSearchField: true,
              searchQuery: query,
              onSearchQueryChanged: (value) {
                setState(() => query = value);
              },
            );
          },
        ),
      ),
    );

    expect(find.text('alice'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('carol'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nur');
    await tester.pumpAndSettle();

    expect(find.text('alice'), findsNothing);
    expect(find.text('bob'), findsNothing);
    expect(find.text('carol'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bo');
    await tester.pumpAndSettle();

    expect(find.text('alice'), findsNothing);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('carol'), findsNothing);
  });

  testWidgets('search no-result state shows custom text', (tester) async {
    var query = 'zzz';

    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return MessengerSuggestedPeoplePanel(
              users: const [alice, bob],
              onUserSelected: (_) {},
              showSearchField: true,
              searchQuery: query,
              noSearchResultsText: 'No matches',
              onSearchQueryChanged: (value) {
                setState(() => query = value);
              },
            );
          },
        ),
      ),
    );

    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('group mode selects users, hides them, and allows removal',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        MessengerSuggestedPeoplePanel(
          users: const [alice, bob, carol],
          onUserSelected: (_) {},
          onCreateGroupSelected: (_) async {},
          showSearchField: true,
          searchQuery: '',
          onSearchQueryChanged: (_) {},
        ),
      ),
    );

    expect(find.text('New group'), findsOneWidget);
    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();

    expect(find.text('Group mode'), findsOneWidget);
    expect(find.text('Selected people (0)'), findsOneWidget);

    await tester.tap(find.text('bob'));
    await tester.pumpAndSettle();

    expect(find.text('Selected people (1)'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);

    final addIcons = find.byIcon(Icons.add_circle_outline_rounded);
    expect(addIcons, findsNWidgets(2));

    final closeButtons = find.byIcon(Icons.close_rounded);
    expect(closeButtons, findsWidgets);
    await tester.tap(closeButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Selected people (0)'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNWidgets(3));
  });

  testWidgets(
    'group mode create callback uses selection order and bypasses direct open',
    (tester) async {
      final created = <MessengerUser>[];
      var openedDirectChats = 0;

      await tester.pumpWidget(
        wrap(
          MessengerSuggestedPeoplePanel(
            users: const [alice, bob, carol],
            onUserSelected: (_) => openedDirectChats++,
            onCreateGroupSelected: (selected) async {
              created
                ..clear()
                ..addAll(selected);
            },
          ),
        ),
      );

      await tester.tap(find.text('New group'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('carol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('alice'));
      await tester.pumpAndSettle();

      expect(find.text('Selected people (2)'), findsOneWidget);

      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();

      expect(openedDirectChats, 0);
      expect(created.map((user) => user.id).toList(), ['u3', 'u1']);
      expect(find.text('New group'), findsOneWidget);
      expect(find.text('Selected people (2)'), findsNothing);
    },
  );

  testWidgets(
    'shell renders suggestedPeopleBuilder when conversations are empty',
    (tester) async {
      final composer = TextEditingController();
      final scroll = ScrollController();
      addTearDown(() {
        composer.dispose();
        scroll.dispose();
      });

      MessengerUser? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: MessengerTheme(
            data: const MessengerThemeData(),
            child: Scaffold(
              body: MessengerChatShell(
                currentUserId: 'me',
                currentUserName: 'Me',
                conversations: const [],
                users: const [alice, bob],
                selectedConversationId: null,
                messages: const [],
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
                emptyConversationsMessage: 'No chats yet',
                suggestedPeopleBuilder: (context, users, openDirectChat) =>
                    MessengerSuggestedPeoplePanel(
                  users: users,
                  onUserSelected: (user) async {
                    await openDirectChat(user);
                    selected = user;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Suggested people'), findsOneWidget);
      expect(find.text('No chats yet'), findsNothing);

      await tester.tap(find.text('alice'));
      await tester.pumpAndSettle();
      expect(selected?.id, 'u1');
    },
  );

  testWidgets(
    'shell falls back to conversation list when builder is null',
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
              body: MessengerChatShell(
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
                onRefresh: () async {},
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
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Suggested people'), findsNothing);
      expect(find.text('No chats yet'), findsOneWidget);
    },
  );
}
