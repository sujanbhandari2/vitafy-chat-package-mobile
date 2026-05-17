import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  testWidgets('peer list orders by latest activity, not selected conversation',
      (tester) async {
    const alice =
        MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');
    const bob = MessengerUser(id: 'b', username: 'bob_smith', roleLabel: '');

    MessengerConversation conv(
      String id,
      List<MessengerUser> peers,
      DateTime activityAt,
    ) {
      return MessengerConversation(
        id: id,
        title: id,
        subtitle: 'Last from $id',
        avatarLabel: 'X',
        createdAt: DateTime.utc(2026, 1, 1),
        lastActivityAt: activityAt,
        peerUsers: peers,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 640,
              width: 400,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: [
                  conv('c1', [alice], DateTime.utc(2026, 1, 10)),
                  conv('c2', [bob], DateTime.utc(2026, 1, 5)),
                ],
                users: const [alice, bob],
                selectedConversationId: 'c2',
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bob Smith'), findsOneWidget);
    expect(find.text('Alice Jones'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Alice Jones')).dy,
      lessThan(tester.getTopLeft(find.text('Bob Smith')).dy),
    );
  });

  testWidgets('cold list follows latest activity over apiRank', (tester) async {
    const alice =
        MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');
    const bob = MessengerUser(id: 'b', username: 'bob_smith', roleLabel: '');

    MessengerConversation conv(
      String id,
      List<MessengerUser> peers,
      DateTime activityAt,
      int apiRank,
    ) {
      return MessengerConversation(
        id: id,
        title: id,
        subtitle: 'Last from $id',
        avatarLabel: 'X',
        createdAt: DateTime.utc(2026, 1, 1),
        lastActivityAt: activityAt,
        peerUsers: peers,
        apiRank: apiRank,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 640,
              width: 400,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: [
                  conv('c1', [alice], DateTime.utc(2026, 1, 1), 0),
                  conv('c2', [bob], DateTime.utc(2026, 1, 20), 1),
                ],
                users: const [alice, bob],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Bob Smith')).dy,
      lessThan(tester.getTopLeft(find.text('Alice Jones')).dy),
    );
  });

  testWidgets('apiRank breaks ties when activity matches', (tester) async {
    const alice =
        MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');
    const bob = MessengerUser(id: 'b', username: 'bob_smith', roleLabel: '');

    MessengerConversation conv(
      String id,
      List<MessengerUser> peers,
      int apiRank,
    ) {
      return MessengerConversation(
        id: id,
        title: id,
        subtitle: 'Last from $id',
        avatarLabel: 'X',
        createdAt: DateTime.utc(2026, 1, 1),
        lastActivityAt: DateTime.utc(2026, 1, 20),
        peerUsers: peers,
        apiRank: apiRank,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 640,
              width: 400,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: [
                  conv('c1', [alice], 0),
                  conv('c2', [bob], 1),
                ],
                users: const [alice, bob],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Alice Jones')).dy,
      lessThan(tester.getTopLeft(find.text('Bob Smith')).dy),
    );
  });

  testWidgets('promoted conversation sorts above cold apiRank', (tester) async {
    const alice =
        MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');
    const bob = MessengerUser(id: 'b', username: 'bob_smith', roleLabel: '');

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 640,
              width: 400,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: [
                  MessengerConversation(
                    id: 'c1',
                    title: 'c1',
                    subtitle: 'old',
                    avatarLabel: 'X',
                    createdAt: DateTime.utc(2026, 1, 1),
                    lastActivityAt: DateTime.utc(2026, 1, 1),
                    peerUsers: const [alice],
                    apiRank: 0,
                  ),
                  MessengerConversation(
                    id: 'c2',
                    title: 'c2',
                    subtitle: 'new',
                    avatarLabel: 'X',
                    createdAt: DateTime.utc(2026, 1, 1),
                    lastActivityAt: DateTime.utc(2026, 1, 25),
                    peerUsers: const [bob],
                    apiRank: 1,
                    promotedAt: DateTime.utc(2026, 2, 1),
                  ),
                ],
                users: const [alice, bob],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Bob Smith')).dy,
      lessThan(tester.getTopLeft(find.text('Alice Jones')).dy),
    );
  });

  testWidgets('tapping non-top row opens that exact user', (tester) async {
    const alice =
        MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');
    const bob = MessengerUser(id: 'b', username: 'bob_smith', roleLabel: '');
    const cara = MessengerUser(id: 'c', username: 'cara_doe', roleLabel: '');
    String? openedConversationId;

    MessengerConversation conv(
      String id,
      List<MessengerUser> peers,
      DateTime activityAt,
    ) {
      return MessengerConversation(
        id: id,
        title: id,
        subtitle: 'Last from $id',
        avatarLabel: 'X',
        createdAt: DateTime.utc(2026, 1, 1),
        lastActivityAt: activityAt,
        peerUsers: peers,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 640,
              width: 400,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: [
                  conv('c1', [alice], DateTime.utc(2026, 1, 10)),
                  conv('c2', [bob], DateTime.utc(2026, 1, 9)),
                  conv('c3', [cara], DateTime.utc(2026, 1, 8)),
                ],
                users: const [alice, bob, cara],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (id) async {
                  openedConversationId = id;
                },
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Alice Jones')).dy,
      lessThan(tester.getTopLeft(find.text('Bob Smith')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Bob Smith')).dy,
      lessThan(tester.getTopLeft(find.text('Cara Doe')).dy),
    );

    await tester.tap(find.text('Cara Doe'));
    await tester.pumpAndSettle();

    expect(openedConversationId, 'c3');
  });

  testWidgets('group conversation renders as a single conversation row',
      (tester) async {
    const alice = MessengerUser(id: 'a', username: 'alice_jones');
    const bob = MessengerUser(id: 'b', username: 'bob_smith');
    const cara = MessengerUser(id: 'c', username: 'cara_doe');

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 420,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: [
                  MessengerConversation(
                    id: 'g1',
                    title: 'Care team',
                    subtitle: 'Group hello',
                    avatarLabel: 'CT',
                    createdAt: DateTime.utc(2026),
                    isGroup: true,
                    peerUsers: const [alice, bob, cara],
                  ),
                ],
                users: const [alice, bob, cara],
                selectedConversationId: 'g1',
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Care team'), findsOneWidget);
    expect(find.text('Alice Jones'), findsNothing);
    expect(find.text('Bob Smith'), findsNothing);
    expect(find.text('Cara Doe'), findsNothing);
  });

  testWidgets('empty peer list shows default start-new-chat hint',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 400,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: const [],
                users: const [],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                emptyConversationsMessage: 'Nothing here',
                showStartChatFab: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.textContaining('Tap +'), findsOneWidget);
  });

  testWidgets('header title can be hidden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 400,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: const [],
                users: const [],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showHeaderTitle: false,
                showStartChatFab: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsNothing);
  });

  testWidgets('falls back to users when peerUsers are missing', (tester) async {
    const alice =
        MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 400,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: [
                  MessengerConversation(
                    id: 'c1',
                    title: 'Alice Jones',
                    subtitle: 'Hey there',
                    avatarLabel: 'A',
                    createdAt: DateTime.utc(2026),
                    // peerUsers intentionally omitted for legacy fallback path
                  ),
                ],
                users: const [alice],
                selectedConversationId: 'c1',
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Alice Jones'), findsOneWidget);
  });

  testWidgets('custom style params are applied to default user card',
      (tester) async {
    const alice =
        MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 420,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: const [],
                users: const [alice],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
                userListItemStyle: const MessengerUserListItemStyle(
                  margin: EdgeInsets.all(7),
                  padding: EdgeInsets.all(9),
                  backgroundColor: Color(0xFFABCDEF),
                  borderRadius: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final styledTile = tester.widget<Container>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.margin == const EdgeInsets.all(7) &&
            widget.padding == const EdgeInsets.all(9),
      ),
    );
    final decoration = styledTile.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFABCDEF));
    expect(decoration.borderRadius, BorderRadius.circular(18));
  });

  testWidgets('custom user list item builder overrides default tile',
      (tester) async {
    const alice =
        MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 420,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: const [],
                users: const [alice],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
                userListItemBuilder: (context, data) {
                  return Text('custom-${data.user.username}');
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('custom-alice_jones'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('pull to refresh invokes onRefresh', (tester) async {
    const alice = MessengerUser(id: 'a', username: 'alice');
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 520,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: const [],
                users: const [alice],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {
                  refreshCount++;
                },
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
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

    expect(refreshCount, 1);
  });

  testWidgets('isConversationListLoading replaces list body with spinner',
      (tester) async {
    const alice = MessengerUser(id: 'a', username: 'alice');

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 400,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: const [],
                users: const [alice],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
                isConversationListLoading: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(
        find.byKey(const ValueKey('conversationListLoading')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('alice'), findsNothing);
  });

  testWidgets('start-new-chat bottom sheet supports group creation',
      (tester) async {
    const alice = MessengerUser(id: 'a', username: 'alice_jones');
    const bob = MessengerUser(id: 'b', username: 'bob_smith');
    const cara = MessengerUser(id: 'c', username: 'cara_doe');
    List<String> createdIds = const [];

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 520,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: const [],
                users: const [alice, bob, cara],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onCreateGroupSelected: (selectedUsers) async {
                  createdIds = selectedUsers
                      .map((user) => user.id)
                      .toList(growable: false);
                },
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showHeaderComposeButton: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Start New Chat'), findsOneWidget);
    expect(find.text('New group'), findsOneWidget);

    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();

    expect(find.text('Selected people (0)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add').first);
    await tester.pumpAndSettle();

    expect(find.text('Selected people (2)'), findsOneWidget);

    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(createdIds, ['a', 'b']);
    expect(find.text('Start New Chat'), findsNothing);
  });

  testWidgets('group rows are interleaved by latest activity', (tester) async {
    const alice = MessengerUser(id: 'a', username: 'alice_jones');
    final groupConversation = MessengerConversation(
      id: 'g1',
      title: 'care_team',
      subtitle: 'Older group update',
      avatarLabel: 'CT',
      createdAt: DateTime.utc(2026, 1, 1),
      lastActivityAt: DateTime.utc(2026, 1, 5),
      isGroup: true,
      peerUsers: const [],
    );
    final directConversation = MessengerConversation(
      id: 'd1',
      title: 'alice_jones',
      subtitle: 'Latest direct update',
      avatarLabel: 'AJ',
      createdAt: DateTime.utc(2026, 1, 1),
      lastActivityAt: DateTime.utc(2026, 1, 20),
      peerUsers: const [alice],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 520,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: [groupConversation, directConversation],
                users: const [alice],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Alice Jones')).dy,
      lessThan(tester.getTopLeft(find.text('Care Team')).dy),
    );
  });

  testWidgets('required group name blocks create until provided',
      (tester) async {
    const alice = MessengerUser(id: 'a', username: 'alice_jones');
    const bob = MessengerUser(id: 'b', username: 'bob_smith');
    MessengerGroupCreateRequest? request;

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 520,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: const [],
                users: const [alice, bob],
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onCreateGroupRequested: (value) async {
                  request = value;
                },
                groupNameInputBehavior:
                    MessengerGroupNameInputBehavior.required,
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                showHeaderComposeButton: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a group name to continue.'), findsOneWidget);
    expect(request, isNull);

    await tester.enterText(find.byType(TextField).first, 'Clinical Team');
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(request, isNotNull);
    expect(request!.groupName, 'Clinical Team');
    expect(
      request!.selectedUsers.map((user) => user.id).toList(growable: false),
      ['a', 'b'],
    );
  });

  testWidgets(
      'start-new-chat sheet updates when directory loads while sheet is open',
      (tester) async {
    final harnessKey = GlobalKey<_StartNewChatSheetLiveHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: _StartNewChatSheetLiveHarness(key: harnessKey),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('alice_after_load'), findsNothing);

    harnessKey.currentState!.applyLoadedUser();
    await tester.pump();
    await tester.pump();

    expect(find.text('Alice After Load'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Start New Chat'), findsNothing);
  });

  testWidgets('start-new-chat sheet debounced search invokes host callback',
      (tester) async {
    final debounced = <String>[];
    const users = [
      MessengerUser(id: 'a', username: 'alice', roleLabel: ''),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 520,
              width: 360,
              child: MessengerConversationList(
                currentUserName: 'me',
                conversations: const [],
                users: users,
                startNewChatUsers: users,
                selectedConversationId: null,
                openingDirectUserId: '',
                onRefresh: () async {},
                onLogout: () {},
                onOpenDirectChat: (_) async {},
                onSelectConversation: (_) async {},
                searchVisibility: MessengerSearchVisibility.never,
                startNewChatDirectory: MessengerStartNewChatDirectory(
                  searchDebounce: const Duration(milliseconds: 180),
                  onSearchQueryDebounced: debounced.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    final field = find.byType(TextField).last;
    await tester.enterText(field, 'ali');
    await tester.pump();
    expect(debounced, isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    expect(debounced, ['ali']);
  });

  testWidgets(
      'start-new-chat group selection survives directory user list replacement',
      (tester) async {
    final harnessKey = GlobalKey<_StartNewChatGroupSelectionHarnessState>();
    final created = <MessengerUser>[];

    await tester.pumpWidget(
      MaterialApp(
        home: _StartNewChatGroupSelectionHarness(
          key: harnessKey,
          created: created,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add').first);
    await tester.pumpAndSettle();
    expect(find.text('Selected people (2)'), findsOneWidget);

    harnessKey.currentState!.replaceUsers(const [
      MessengerUser(id: 'c', username: 'cara_doe'),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Selected people (2)'), findsOneWidget);

    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(created.map((user) => user.id).toList(), ['a', 'b']);
    expect(find.text('Start New Chat'), findsNothing);
  });
}

class _StartNewChatGroupSelectionHarness extends StatefulWidget {
  const _StartNewChatGroupSelectionHarness({
    super.key,
    required this.created,
  });

  final List<MessengerUser> created;

  @override
  State<_StartNewChatGroupSelectionHarness> createState() =>
      _StartNewChatGroupSelectionHarnessState();
}

class _StartNewChatGroupSelectionHarnessState
    extends State<_StartNewChatGroupSelectionHarness> {
  static const _alice = MessengerUser(id: 'a', username: 'alice_jones');
  static const _bob = MessengerUser(id: 'b', username: 'bob_smith');
  static const _cara = MessengerUser(id: 'c', username: 'cara_doe');

  List<MessengerUser> _users = const [_alice, _bob, _cara];

  void replaceUsers(List<MessengerUser> users) {
    setState(() => _users = users);
  }

  @override
  Widget build(BuildContext context) {
    return MessengerTheme(
      data: const MessengerThemeData(),
      child: Scaffold(
        body: SizedBox(
          height: 520,
          width: 360,
          child: MessengerConversationList(
            currentUserName: 'me',
            conversations: const [],
            users: _users,
            startNewChatUsers: _users,
            selectedConversationId: null,
            openingDirectUserId: '',
            onRefresh: () async {},
            onLogout: () {},
            onOpenDirectChat: (_) async {},
            onCreateGroupSelected: (selected) async {
              widget.created
                ..clear()
                ..addAll(selected);
            },
            onSelectConversation: (_) async {},
            searchVisibility: MessengerSearchVisibility.never,
            showHeaderComposeButton: false,
            startNewChatDirectory: const MessengerStartNewChatDirectory(
              searchDebounce: Duration.zero,
              onSearchQueryDebounced: _noopSearch,
            ),
          ),
        ),
      ),
    );
  }
}

void _noopSearch(String _) {}

class _StartNewChatSheetLiveHarness extends StatefulWidget {
  const _StartNewChatSheetLiveHarness({super.key});

  @override
  State<_StartNewChatSheetLiveHarness> createState() =>
      _StartNewChatSheetLiveHarnessState();
}

class _StartNewChatSheetLiveHarnessState
    extends State<_StartNewChatSheetLiveHarness> {
  static const _alice =
      MessengerUser(id: 'x', username: 'alice_after_load', roleLabel: '');

  List<MessengerUser> _users = const [];
  bool _directoryLoading = true;

  void applyLoadedUser() {
    setState(() {
      _users = const [_alice];
      _directoryLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MessengerTheme(
      data: const MessengerThemeData(),
      child: Scaffold(
        body: SizedBox(
          height: 520,
          width: 360,
          child: MessengerConversationList(
            currentUserName: 'me',
            conversations: const [],
            users: _users,
            selectedConversationId: null,
            openingDirectUserId: '',
            onRefresh: () async {},
            onLogout: () {},
            onOpenDirectChat: (_) async {},
            onSelectConversation: (_) async {},
            searchVisibility: MessengerSearchVisibility.never,
            startNewChatUsersLoading: _directoryLoading,
          ),
        ),
      ),
    );
  }
}
