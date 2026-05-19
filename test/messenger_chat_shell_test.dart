import 'dart:io';

import 'package:flutter/material.dart';
import 'package:health_messenger_ui/lib/src/client/models/chat_message.dart';
import 'package:health_messenger_ui/lib/src/widgets/messenger_media_send_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

Finder _packageDeleteChatConfirmButton() {
  return find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, 'Delete'),
  );
}

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
    expect(find.text('No chats yet'), findsOneWidget);
  });

  testWidgets('selected conversation updates do not auto-open mobile thread',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const user = MessengerUser(id: 'u1', username: 'alice_jones');
    final conversation = MessengerConversation(
      id: 'c1',
      title: 'Alice Jones',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
      peerUsers: const [user],
    );

    Widget buildShell(String? selectedConversationId) {
      return MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerChatShell(
              currentUserId: 'me',
              currentUserName: 'Me',
              conversations: [conversation],
              users: const [user],
              selectedConversationId: selectedConversationId,
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
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildShell(null));
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsOneWidget);

    await tester.pumpWidget(buildShell('c1'));
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsOneWidget);
  });

  testWidgets('mobile thread opens only after explicit user tap',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const user = MessengerUser(id: 'u1', username: 'alice_jones');
    final conversation = MessengerConversation(
      id: 'c1',
      title: 'Alice Jones',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
      peerUsers: const [user],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerChatShell(
              currentUserId: 'me',
              currentUserName: 'Me',
              conversations: [conversation],
              users: const [user],
              selectedConversationId: 'c1',
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
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsOneWidget);
    await tester.tap(find.text('Alice Jones'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsOneWidget);
  });

  testWidgets('mobile open-direct picker delegates and updates host state',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const existingUser = MessengerUser(id: 'u1', username: 'alice_jones');
    const newPeer = MessengerUser(id: 'u2', username: 'bob');
    final c1 = MessengerConversation(
      id: 'c1',
      title: 'Alice Jones',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
      peerUsers: const [existingUser],
    );
    final c2 = MessengerConversation(
      id: 'c2',
      title: 'Bob',
      subtitle: 'New thread',
      avatarLabel: 'B',
      createdAt: DateTime.utc(2026),
      peerUsers: const [newPeer],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: _HostShellHarness(
            composer: composer,
            scroll: scroll,
            initialConversations: [c1],
            users: const [existingUser, newPeer],
            createdConversation: c2,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_square));
    await tester.pumpAndSettle();
    // Start-new-chat sheet uses [FilledButton] labels, not row trailing icons.
    await tester.tap(find.widgetWithText(FilledButton, 'Chat').at(1));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(_HostShellHarnessState.openDirectCallCount, 1);
    expect(_HostShellHarnessState.latestSelectedConversationId, 'c2');
  });

  testWidgets('mobile create-group from picker opens created conversation',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const existingUser = MessengerUser(id: 'u1', username: 'alice_jones');
    const bob = MessengerUser(id: 'u2', username: 'bob');
    const cara = MessengerUser(id: 'u3', username: 'cara');
    final c1 = MessengerConversation(
      id: 'c1',
      title: 'Alice Jones',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
      peerUsers: const [existingUser],
    );
    final groupConversation = MessengerConversation(
      id: 'g1',
      title: 'Bob, Cara',
      subtitle: 'New group',
      avatarLabel: 'BC',
      createdAt: DateTime.utc(2026),
      peerUsers: const [bob, cara],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: _GroupCreateHarness(
            composer: composer,
            scroll: scroll,
            initialConversations: [c1],
            users: const [existingUser, bob, cara],
            createdConversation: groupConversation,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_square));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();
    final addButtons = find.widgetWithText(FilledButton, 'Add');
    await tester.tap(addButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(addButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(_GroupCreateHarnessState.latestSelectedConversationId, 'g1');
  });

  testWidgets(
      'mobile open-direct uses host selection after async gap (not stale id)',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const existingUser = MessengerUser(id: 'u1', username: 'alice_jones');
    const newPeer = MessengerUser(id: 'u2', username: 'bob');
    final c1 = MessengerConversation(
      id: 'c1',
      title: 'Alice Jones',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
      peerUsers: const [existingUser],
    );
    final c2 = MessengerConversation(
      id: 'c2',
      title: 'Bob',
      subtitle: 'New thread',
      avatarLabel: 'B',
      createdAt: DateTime.utc(2026),
      peerUsers: const [newPeer],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: _DeferredOpenDirectHarness(
            composer: composer,
            scroll: scroll,
            initialConversations: [c1],
            users: const [existingUser, newPeer],
            createdConversation: c2,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_square));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Chat').at(1));
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsWidgets);
    expect(_DeferredOpenDirectHarnessState.latestOpenedConversationId, 'c2');
  });

  testWidgets('desktop thread shows loading state instead of empty text',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const user = MessengerUser(id: 'u1', username: 'alice_jones');
    final conversation = MessengerConversation(
      id: 'c1',
      title: 'Alice Jones',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
      peerUsers: const [user],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerChatShell(
              currentUserId: 'me',
              currentUserName: 'Me',
              conversations: [conversation],
              users: const [user],
              selectedConversationId: 'c1',
              messages: const [],
              composerController: composer,
              messagesScrollController: scroll,
              isSending: false,
              isRecording: false,
              isConversationLoading: true,
              loadingConversationId: 'c1',
              desktopBreakpoint: 200,
              onRefresh: () async {},
              onLogout: () {},
              onSelectConversation: (_) async {},
              onOpenDirectChat: (_) async {},
              onSend: () {},
              onPickImage: () {},
              onPickAudio: () {},
              onToggleRecording: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Loading messages...'), findsOneWidget);
    expect(find.text('No messages yet.'), findsNothing);
  });

  testWidgets(
      'loading conversation keeps thread messages visible without overlay',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const user = MessengerUser(id: 'u1', username: 'alice_jones');
    final conversation = MessengerConversation(
      id: 'c1',
      title: 'Alice Jones',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
      peerUsers: const [user],
    );
    final staleMessage = MessengerChatMessage(
      id: 'm1',
      senderId: 'u1',
      senderLabel: 'Alice',
      type: MessengerMessageType.text,
      content: 'old-thread-message',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerChatShell(
              currentUserId: 'me',
              currentUserName: 'Me',
              conversations: [conversation],
              users: const [user],
              selectedConversationId: 'c1',
              messages: [staleMessage],
              composerController: composer,
              messagesScrollController: scroll,
              isSending: false,
              isRecording: false,
              isConversationLoading: true,
              loadingConversationId: 'c1',
              threadFetchLoadingMode:
                  MessengerThreadFetchLoadingMode.keepMessagesVisible,
              desktopBreakpoint: 200,
              onRefresh: () async {},
              onLogout: () {},
              onSelectConversation: (_) async {},
              onOpenDirectChat: (_) async {},
              onSend: () {},
              onPickImage: () {},
              onPickAudio: () {},
              onToggleRecording: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('old-thread-message'), findsOneWidget);
    expect(find.text('Updating messages...'), findsNothing);
  });

  testWidgets('shell composer style params reach composer bar', (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const inputStyle = TextStyle(
      color: Color(0xFF111827),
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    const hintStyle = TextStyle(
      color: Color(0xFF9CA3AF),
      fontSize: 12.5,
    );
    const fieldColor = Color(0xFFEFF6FF);
    const fieldPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
    const user = MessengerUser(id: 'u1', username: 'alice_jones');
    final conversation = MessengerConversation(
      id: 'c1',
      title: 'Alice Jones',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
      peerUsers: const [user],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerChatShell(
              currentUserId: 'me',
              currentUserName: 'Me',
              conversations: [conversation],
              users: const [user],
              selectedConversationId: 'c1',
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
              desktopBreakpoint: 200,
              composerInputTextStyle: inputStyle,
              composerHintTextStyle: hintStyle,
              composerFieldBackgroundColor: fieldColor,
              composerFieldContentPadding: fieldPadding,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final composerBar =
        tester.widget<MessengerComposerBar>(find.byType(MessengerComposerBar));
    expect(composerBar.inputTextStyle, inputStyle);
    expect(composerBar.hintTextStyle, hintStyle);
    expect(composerBar.fieldBackgroundColor, fieldColor);
    expect(composerBar.fieldContentPadding, fieldPadding);
  });

  testWidgets('shell search style params reach conversation list',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const inputStyle = TextStyle(
      color: Color(0xFF1F2937),
      fontSize: 14,
    );
    const hintStyle = TextStyle(
      color: Color(0xFF9CA3AF),
      fontSize: 13,
    );
    const bgColor = Color(0xFFF8FAFC);
    const contentPadding = EdgeInsets.symmetric(horizontal: 12);
    const iconColor = Color(0xFF64748B);
    const borderRadius = 14.0;

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
              searchInputTextStyle: inputStyle,
              searchHintTextStyle: hintStyle,
              searchFieldBackgroundColor: bgColor,
              searchFieldContentPadding: contentPadding,
              searchIconColor: iconColor,
              searchFieldBorderRadius: borderRadius,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final list = tester.widget<MessengerConversationList>(
      find.byType(MessengerConversationList).first,
    );
    expect(list.searchInputTextStyle, inputStyle);
    expect(list.searchHintTextStyle, hintStyle);
    expect(list.searchFieldBackgroundColor, bgColor);
    expect(list.searchFieldContentPadding, contentPadding);
    expect(list.searchIconColor, iconColor);
    expect(list.searchFieldBorderRadius, borderRadius);
  });

  testWidgets('media picker plugin error falls back without crashing',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const user = MessengerUser(id: 'u1', username: 'alice_jones');
    final conversation = MessengerConversation(
      id: 'c1',
      title: 'Alice Jones',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
      peerUsers: const [user],
    );

    var fallbackCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerChatShell(
              currentUserId: 'me',
              currentUserName: 'Me',
              conversations: [conversation],
              users: const [user],
              selectedConversationId: 'c1',
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
              onPickImage: () {
                fallbackCalls++;
              },
              onPickAudio: () {},
              onToggleRecording: () {},
              desktopBreakpoint: 200,
              enablePackageMediaSending: true,
              mediaChatClient: _NoopMediaClient(),
              mediaChatAuth: const ChatAuth(apiKey: 'k'),
              mediaSenderId: 'me',
              mediaPicker: const _ThrowingMediaPicker(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final composerBar =
        tester.widget<MessengerComposerBar>(find.byType(MessengerComposerBar));
    composerBar.onPickImage();
    await tester.pump();

    expect(fallbackCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multi-pick queues attachments with per-item removal',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const user = MessengerUser(id: 'u1', username: 'alice_jones');
    final conversation = MessengerConversation(
      id: 'c1',
      title: 'Alice Jones',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
      peerUsers: const [user],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerChatShell(
              currentUserId: 'me',
              currentUserName: 'Me',
              conversations: [conversation],
              users: const [user],
              selectedConversationId: 'c1',
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
              desktopBreakpoint: 200,
              enablePackageMediaSending: true,
              mediaChatClient: _NoopMediaClient(),
              mediaChatAuth: const ChatAuth(apiKey: 'k'),
              mediaSenderId: 'me',
              mediaPicker: _QueueingMediaPicker([
                MessengerPickedMedia(
                  file: File('a.pdf'),
                  messageType: MessageType.file,
                  displayName: 'a.pdf',
                ),
                MessengerPickedMedia(
                  file: File('b.pdf'),
                  messageType: MessageType.file,
                  displayName: 'b.pdf',
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final composerBar =
        tester.widget<MessengerComposerBar>(find.byType(MessengerComposerBar));
    composerBar.onPickImage();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.pdf'), findsOneWidget);
    expect(find.text('Remove all'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove attachment').first);
    await tester.pump();

    expect(find.text('a.pdf'), findsNothing);
    expect(find.text('b.pdf'), findsOneWidget);
  });

  testWidgets(
      'isListPaneRefreshing shows inline spinner replacing conversation list',
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
              height: 600,
              width: 800,
              child: MessengerChatShell(
                currentUserId: 'me',
                currentUserName: 'Me',
                isListPaneRefreshing: true,
                conversations: const [],
                users: const [
                  MessengerUser(id: 'u1', username: 'alice'),
                ],
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
                searchVisibility: MessengerSearchVisibility.never,
                showStartChatFab: false,
                desktopBreakpoint: 400,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(
        find.byKey(const ValueKey('conversationListLoading')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('alice'), findsNothing);
  });

  testWidgets(
      'isListPaneRefreshing with suggested slot shows full-pane spinner',
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
              height: 600,
              width: 960,
              child: MessengerChatShell(
                currentUserId: 'me',
                currentUserName: 'Me',
                isListPaneRefreshing: true,
                conversations: const [],
                users: const [
                  MessengerUser(id: 'u1', username: 'alice'),
                ],
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
                desktopBreakpoint: 400,
                suggestedPeopleBuilder: (context, users, _) =>
                    MessengerSuggestedPeoplePanel(
                  users: users,
                  onUserSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Suggested people'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets(
      'isListPaneRefreshing false shows suggested people when inbox is empty',
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
              height: 600,
              width: 960,
              child: MessengerChatShell(
                currentUserId: 'me',
                currentUserName: 'Me',
                isListPaneRefreshing: false,
                conversations: const [],
                users: const [
                  MessengerUser(id: 'u1', username: 'alice'),
                ],
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
                desktopBreakpoint: 400,
                suggestedPeopleBuilder: (context, users, _) =>
                    MessengerSuggestedPeoplePanel(
                  users: users,
                  onUserSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Suggested people'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.byKey(const ValueKey('conversationListLoading')), findsNothing);
  });

  testWidgets(
      'suggestedPeopleBuilder with isLoading uses panel spinner not list-pane key',
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
              height: 600,
              width: 960,
              child: MessengerChatShell(
                currentUserId: 'me',
                currentUserName: 'Me',
                isListPaneRefreshing: false,
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
                desktopBreakpoint: 400,
                suggestedPeopleBuilder: (context, users, _) =>
                    MessengerSuggestedPeoplePanel(
                  users: users,
                  isLoading: true,
                  onUserSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Suggested people'), findsOneWidget);
    expect(find.byKey(const ValueKey('conversationListLoading')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets(
      'isListPaneRefreshing with non-empty inbox replaces list only',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    final conversation = MessengerConversation(
      id: 'c1',
      title: 'Alice',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 600,
              width: 960,
              child: MessengerChatShell(
                currentUserId: 'me',
                currentUserName: 'Me',
                isListPaneRefreshing: true,
                conversations: [conversation],
                users: const [
                  MessengerUser(id: 'u1', username: 'alice'),
                ],
                selectedConversationId: 'c1',
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
                desktopBreakpoint: 400,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(
        find.byKey(const ValueKey('conversationListLoading')), findsOneWidget);
    expect(find.text('Suggested people'), findsNothing);
  });

  testWidgets('attachment sheet applies custom option label style',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });
    const optionStyle = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: Colors.deepPurple,
    );
    final conversation = MessengerConversation(
      id: 'c1',
      title: 'Alice',
      subtitle: 'Hello',
      avatarLabel: 'A',
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              height: 700,
              width: 960,
              child: MessengerChatShell(
                currentUserId: 'me',
                currentUserName: 'Me',
                conversations: [conversation],
                users: const [],
                selectedConversationId: 'c1',
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
                desktopBreakpoint: 400,
                attachmentOptionTextStyle: optionStyle,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.text('Images'));
    expect(label.style?.fontSize, optionStyle.fontSize);
    expect(label.style?.fontWeight, optionStyle.fontWeight);
    expect(label.style?.color, optionStyle.color);
  });
  testWidgets('group thread header exposes action menu callbacks',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const alice = MessengerUser(id: 'u1', username: 'alice_jones');
    final conversation = MessengerConversation(
      id: 'g1',
      title: 'Care Team',
      subtitle: 'Hello',
      avatarLabel: 'CT',
      createdAt: DateTime.utc(2026),
      isGroup: true,
      peerUsers: const [alice],
    );

    var editCount = 0;
    var addPeopleCount = 0;
    var deleteCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              width: 1200,
              child: MessengerChatShell(
                currentUserId: 'me',
                currentUserName: 'Me',
                conversations: [conversation],
                users: const [alice],
                selectedConversationId: 'g1',
                messages: const [],
                composerController: composer,
                messagesScrollController: scroll,
                isSending: false,
                isRecording: false,
                onRefresh: () async {},
                onLogout: () {},
                onSelectConversation: (_) async {},
                onOpenDirectChat: (_) async {},
                onEditGroupConversation: (_) async => editCount++,
                onAddPeopleToGroupConversation: (_) async => addPeopleCount++,
                onDeleteConversation: (_) async => deleteCount++,
                onSend: () {},
                onPickImage: () {},
                onPickAudio: () {},
                onToggleRecording: () {},
                desktopBreakpoint: 400,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsWidgets);
    expect(find.text('Add people'), findsOneWidget);
    expect(find.text('Delete chat'), findsOneWidget);

    await tester.tap(find.text('Add people'));
    await tester.pumpAndSettle();
    expect(editCount, 0);
    expect(addPeopleCount, 1);
    expect(deleteCount, 0);
  });

  testWidgets('direct thread header shows delete without group edit actions',
      (tester) async {
    final composer = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      composer.dispose();
      scroll.dispose();
    });

    const bob = MessengerUser(id: 'u2', username: 'bob');
    final conversation = MessengerConversation(
      id: 'd1',
      title: 'Direct Bob',
      subtitle: 'Hello',
      avatarLabel: 'B',
      createdAt: DateTime.utc(2026),
      isGroup: false,
      peerUsers: const [bob],
    );

    var editCount = 0;
    var addPeopleCount = 0;
    var deleteCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: SizedBox(
              width: 1200,
              child: MessengerChatShell(
                currentUserId: 'me',
                currentUserName: 'Me',
                conversations: [conversation],
                users: const [bob],
                selectedConversationId: 'd1',
                messages: const [],
                composerController: composer,
                messagesScrollController: scroll,
                isSending: false,
                isRecording: false,
                onRefresh: () async {},
                onLogout: () {},
                onSelectConversation: (_) async {},
                onOpenDirectChat: (_) async {},
                onEditGroupConversation: (_) async => editCount++,
                onAddPeopleToGroupConversation: (_) async => addPeopleCount++,
                onDeleteConversation: (_) async => deleteCount++,
                onSend: () {},
                onPickImage: () {},
                onPickAudio: () {},
                onToggleRecording: () {},
                desktopBreakpoint: 400,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Add people'), findsNothing);
    expect(find.text('Delete chat'), findsOneWidget);

    await tester.tap(find.text('Delete chat'));
    await tester.pumpAndSettle();
    await tester.tap(_packageDeleteChatConfirmButton());
    await tester.pumpAndSettle();
    expect(deleteCount, 1);
    expect(editCount, 0);
    expect(addPeopleCount, 0);
  });

  testWidgets('mobile thread route pops when conversation is deleted',
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
            body: _MobileDeleteThreadHarness(
              composer: composer,
              scroll: scroll,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice Jones'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete chat'));
    await tester.pumpAndSettle();
    await tester.tap(_packageDeleteChatConfirmButton());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });

  testWidgets(
      'mobile thread pops after delete without host removing conversation',
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
            body: _MobileDeleteThreadNoListUpdateHarness(
              composer: composer,
              scroll: scroll,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice Jones'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete chat'));
    await tester.pumpAndSettle();
    await tester.tap(_packageDeleteChatConfirmButton());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });
}

/// Delete succeeds but host does not mutate [conversations] / selection; the
/// package must still close the pushed mobile thread.
class _MobileDeleteThreadNoListUpdateHarness extends StatefulWidget {
  const _MobileDeleteThreadNoListUpdateHarness({
    required this.composer,
    required this.scroll,
  });

  final TextEditingController composer;
  final ScrollController scroll;

  @override
  State<_MobileDeleteThreadNoListUpdateHarness> createState() =>
      _MobileDeleteThreadNoListUpdateHarnessState();
}

class _MobileDeleteThreadNoListUpdateHarnessState
    extends State<_MobileDeleteThreadNoListUpdateHarness> {
  static const MessengerUser _peer =
      MessengerUser(id: 'u1', username: 'alice_jones');

  static final MessengerConversation _c1 = MessengerConversation(
    id: 'c1',
    title: 'Alice Jones',
    subtitle: 'Hi',
    avatarLabel: 'A',
    createdAt: DateTime.utc(2026),
    peerUsers: const [_peer],
  );

  late List<MessengerConversation> conversations;
  String? selectedConversationId;

  @override
  void initState() {
    super.initState();
    conversations = [_c1];
    selectedConversationId = _c1.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MessengerChatShell(
        currentUserId: 'me',
        currentUserName: 'Me',
        conversations: conversations,
        users: const [_peer],
        selectedConversationId: selectedConversationId,
        messages: const [],
        composerController: widget.composer,
        messagesScrollController: widget.scroll,
        isSending: false,
        isRecording: false,
        onRefresh: () async {},
        onLogout: () {},
        onSelectConversation: (id) async {
          setState(() => selectedConversationId = id);
        },
        onOpenDirectChat: (_) async {},
        onDeleteConversation: (_) async {
          await Future<void>.delayed(Duration.zero);
        },
        onSend: () {},
        onPickImage: () {},
        onPickAudio: () {},
        onToggleRecording: () {},
      ),
    );
  }
}

class _MobileDeleteThreadHarness extends StatefulWidget {
  const _MobileDeleteThreadHarness({
    required this.composer,
    required this.scroll,
  });

  final TextEditingController composer;
  final ScrollController scroll;

  @override
  State<_MobileDeleteThreadHarness> createState() =>
      _MobileDeleteThreadHarnessState();
}

class _MobileDeleteThreadHarnessState extends State<_MobileDeleteThreadHarness> {
  static const MessengerUser _peer =
      MessengerUser(id: 'u1', username: 'alice_jones');

  static final MessengerConversation _c1 = MessengerConversation(
    id: 'c1',
    title: 'Alice Jones',
    subtitle: 'Hi',
    avatarLabel: 'A',
    createdAt: DateTime.utc(2026),
    peerUsers: const [_peer],
  );

  late List<MessengerConversation> conversations;
  String? selectedConversationId;

  @override
  void initState() {
    super.initState();
    conversations = [_c1];
    selectedConversationId = _c1.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MessengerChatShell(
        currentUserId: 'me',
        currentUserName: 'Me',
        conversations: conversations,
        users: const [_peer],
        selectedConversationId: selectedConversationId,
        messages: const [],
        composerController: widget.composer,
        messagesScrollController: widget.scroll,
        isSending: false,
        isRecording: false,
        onRefresh: () async {},
        onLogout: () {},
        onSelectConversation: (id) async {
          setState(() => selectedConversationId = id);
        },
        onOpenDirectChat: (_) async {},
        onDeleteConversation: (_) async {
          setState(() {
            conversations = [];
            selectedConversationId = null;
          });
        },
        onSend: () {},
        onPickImage: () {},
        onPickAudio: () {},
        onToggleRecording: () {},
      ),
    );
  }
}

class _QueueingMediaPicker implements MessengerMediaPicker {
  const _QueueingMediaPicker(this.items);

  final List<MessengerPickedMedia> items;

  @override
  Future<MessengerPickedMedia?> pick(MessengerMediaKind kind) async {
    if (items.isEmpty) {
      return null;
    }
    return items.first;
  }

  @override
  Future<List<MessengerPickedMedia>> pickMany(MessengerMediaKind kind) async {
    return items;
  }
}

class _ThrowingMediaPicker implements MessengerMediaPicker {
  const _ThrowingMediaPicker();

  @override
  Future<MessengerPickedMedia?> pick(MessengerMediaKind kind) async {
    throw const MessengerMediaPickerUnavailableException('missing plugin');
  }

  @override
  Future<List<MessengerPickedMedia>> pickMany(MessengerMediaKind kind) async {
    throw const MessengerMediaPickerUnavailableException('missing plugin');
  }
}

class _NoopMediaClient extends ChatClient {
  _NoopMediaClient()
      : super(
          config: const ChatServiceConfig(
            apiBaseUrl: 'https://example.com',
            socketUrl: 'https://example.com',
          ),
        );
}

/// Host defers updating [selectedConversationId] until after an async gap,
/// reproducing stale-widget reads if the shell does not wait for a frame.
class _DeferredOpenDirectHarness extends StatefulWidget {
  const _DeferredOpenDirectHarness({
    required this.composer,
    required this.scroll,
    required this.initialConversations,
    required this.users,
    required this.createdConversation,
  });

  final TextEditingController composer;
  final ScrollController scroll;
  final List<MessengerConversation> initialConversations;
  final List<MessengerUser> users;
  final MessengerConversation createdConversation;

  @override
  State<_DeferredOpenDirectHarness> createState() =>
      _DeferredOpenDirectHarnessState();
}

class _DeferredOpenDirectHarnessState
    extends State<_DeferredOpenDirectHarness> {
  static String? latestOpenedConversationId;

  late List<MessengerConversation> conversations;
  String? selectedConversationId;

  @override
  void initState() {
    super.initState();
    conversations = [...widget.initialConversations];
    selectedConversationId = conversations.first.id;
    latestOpenedConversationId = selectedConversationId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MessengerChatShell(
        currentUserId: 'me',
        currentUserName: 'Me',
        conversations: conversations,
        users: widget.users,
        selectedConversationId: selectedConversationId,
        messages: const [],
        composerController: widget.composer,
        messagesScrollController: widget.scroll,
        isSending: false,
        isRecording: false,
        onRefresh: () async {},
        onLogout: () {},
        onSelectConversation: (id) async {
          setState(() => selectedConversationId = id);
          latestOpenedConversationId = id;
        },
        onOpenDirectChat: (_) async {
          await Future<void>.delayed(Duration.zero);
          if (!mounted) {
            return;
          }
          setState(() {
            selectedConversationId = widget.createdConversation.id;
            conversations = [
              ...conversations,
              widget.createdConversation,
            ];
          });
          latestOpenedConversationId = widget.createdConversation.id;
        },
        onSend: () {},
        onPickImage: () {},
        onPickAudio: () {},
        onToggleRecording: () {},
      ),
    );
  }
}

class _HostShellHarness extends StatefulWidget {
  const _HostShellHarness({
    required this.composer,
    required this.scroll,
    required this.initialConversations,
    required this.users,
    required this.createdConversation,
  });

  final TextEditingController composer;
  final ScrollController scroll;
  final List<MessengerConversation> initialConversations;
  final List<MessengerUser> users;
  final MessengerConversation createdConversation;

  @override
  State<_HostShellHarness> createState() => _HostShellHarnessState();
}

class _HostShellHarnessState extends State<_HostShellHarness> {
  static int openDirectCallCount = 0;
  static String? latestSelectedConversationId;

  late List<MessengerConversation> conversations;
  String? selectedConversationId;

  @override
  void initState() {
    super.initState();
    conversations = [...widget.initialConversations];
    selectedConversationId = conversations.first.id;
    openDirectCallCount = 0;
    latestSelectedConversationId = selectedConversationId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MessengerChatShell(
        currentUserId: 'me',
        currentUserName: 'Me',
        conversations: conversations,
        users: widget.users,
        selectedConversationId: selectedConversationId,
        messages: const [],
        composerController: widget.composer,
        messagesScrollController: widget.scroll,
        isSending: false,
        isRecording: false,
        onRefresh: () async {},
        onLogout: () {},
        onSelectConversation: (id) async {
          setState(() => selectedConversationId = id);
          latestSelectedConversationId = id;
        },
        onOpenDirectChat: (_) async {
          openDirectCallCount++;
          setState(() {
            selectedConversationId = widget.createdConversation.id;
            conversations = [
              ...conversations,
              widget.createdConversation,
            ];
          });
          latestSelectedConversationId = widget.createdConversation.id;
        },
        onSend: () {},
        onPickImage: () {},
        onPickAudio: () {},
        onToggleRecording: () {},
      ),
    );
  }
}

class _GroupCreateHarness extends StatefulWidget {
  const _GroupCreateHarness({
    required this.composer,
    required this.scroll,
    required this.initialConversations,
    required this.users,
    required this.createdConversation,
  });

  final TextEditingController composer;
  final ScrollController scroll;
  final List<MessengerConversation> initialConversations;
  final List<MessengerUser> users;
  final MessengerConversation createdConversation;

  @override
  State<_GroupCreateHarness> createState() => _GroupCreateHarnessState();
}

class _GroupCreateHarnessState extends State<_GroupCreateHarness> {
  static String? latestSelectedConversationId;

  late List<MessengerConversation> conversations;
  String? selectedConversationId;

  @override
  void initState() {
    super.initState();
    conversations = [...widget.initialConversations];
    selectedConversationId = conversations.first.id;
    latestSelectedConversationId = selectedConversationId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MessengerChatShell(
        currentUserId: 'me',
        currentUserName: 'Me',
        conversations: conversations,
        users: widget.users,
        selectedConversationId: selectedConversationId,
        messages: const [],
        composerController: widget.composer,
        messagesScrollController: widget.scroll,
        isSending: false,
        isRecording: false,
        onRefresh: () async {},
        onLogout: () {},
        onSelectConversation: (id) async {
          setState(() => selectedConversationId = id);
          latestSelectedConversationId = id;
        },
        onOpenDirectChat: (_) async {},
        onCreateGroupSelected: (_) async {
          await Future<void>.delayed(Duration.zero);
          if (!mounted) {
            return;
          }
          setState(() {
            selectedConversationId = widget.createdConversation.id;
            conversations = [
              ...conversations,
              widget.createdConversation,
            ];
          });
          latestSelectedConversationId = widget.createdConversation.id;
        },
        onSend: () {},
        onPickImage: () {},
        onPickAudio: () {},
        onToggleRecording: () {},
      ),
    );
  }
}
