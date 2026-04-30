import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  testWidgets('peer list orders by latest activity, not selected conversation',
      (tester) async {
    const alice = MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');
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
                onRefresh: () {},
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

  testWidgets('tapping non-top row opens that exact user', (tester) async {
    const alice = MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');
    const bob = MessengerUser(id: 'b', username: 'bob_smith', roleLabel: '');
    const cara = MessengerUser(id: 'c', username: 'cara_doe', roleLabel: '');
    String? openedUserId;

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
                onRefresh: () {},
                onLogout: () {},
                onOpenDirectChat: (user) async {
                  openedUserId = user.id;
                },
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
    expect(
      tester.getTopLeft(find.text('Bob Smith')).dy,
      lessThan(tester.getTopLeft(find.text('Cara Doe')).dy),
    );

    await tester.tap(find.text('Cara Doe'));
    await tester.pumpAndSettle();

    expect(openedUserId, 'c');
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
                onRefresh: () {},
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
                onRefresh: () {},
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
    const alice = MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');

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
                onRefresh: () {},
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
    const alice = MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');

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
                onRefresh: () {},
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
    const alice = MessengerUser(id: 'a', username: 'alice_jones', roleLabel: '');

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
                onRefresh: () {},
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
}
