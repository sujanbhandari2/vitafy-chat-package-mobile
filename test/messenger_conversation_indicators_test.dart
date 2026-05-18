import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  testWidgets('group conversation tile does not show online presence',
      (tester) async {
    final conversation = MessengerConversation(
      id: 'g1',
      title: 'Team Group',
      subtitle: 'Latest preview',
      avatarLabel: 'TG',
      createdAt: DateTime.utc(2026, 1, 1),
      isGroup: true,
      unreadCount: 2,
      isOnline: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerConversationTile(
              conversation: conversation,
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final avatar = tester.widget<MessengerAvatar>(find.byType(MessengerAvatar));
    expect(avatar.showUnreadIndicator, isFalse);
    expect(avatar.showOnlineIndicator, isFalse);

    final title = tester.widget<Text>(
      find.text('Team Group'),
    );
    expect(title.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('direct conversation tile shows online when isOnline is set',
      (tester) async {
    final conversation = MessengerConversation(
      id: 'd1',
      title: 'Alice',
      subtitle: 'Hi',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026, 1, 1),
      isGroup: false,
      isOnline: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerConversationTile(
              conversation: conversation,
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final avatar = tester.widget<MessengerAvatar>(find.byType(MessengerAvatar));
    expect(avatar.showUnreadIndicator, isFalse);
    expect(avatar.showOnlineIndicator, isTrue);
    expect(avatar.isOnline, isTrue);
  });

  testWidgets('group row in conversation list does not show Online subtitle',
      (tester) async {
    final group = MessengerConversation(
      id: 'g1',
      title: 'Ops Group',
      subtitle: 'New message',
      avatarLabel: 'OG',
      createdAt: DateTime.utc(2026, 1, 1),
      isGroup: true,
      unreadCount: 1,
      peerUsers: [
        MessengerUser(
          id: 'p1',
          username: 'peer_one',
          roleLabel: '',
          isOnline: true,
        ),
      ],
    );

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
                conversations: [group],
                users: const [],
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

    expect(find.text('Ops Group'), findsOneWidget);
    expect(find.textContaining('Online'), findsNothing);
    expect(find.textContaining('Offline'), findsNothing);
  });
}
