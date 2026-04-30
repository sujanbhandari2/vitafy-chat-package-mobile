import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';
import 'package:health_messenger_ui/lib/src/client/chat_auth.dart';
import 'package:health_messenger_ui/lib/src/client/chat_client.dart';
import 'package:health_messenger_ui/lib/src/client/chat_config.dart';

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
              onRefresh: () {},
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
              onRefresh: () {},
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
              onRefresh: () {},
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
              onRefresh: () {},
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

  testWidgets('loading conversation does not render stale thread message',
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
              desktopBreakpoint: 200,
              onRefresh: () {},
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
    expect(find.text('old-thread-message'), findsNothing);
    expect(find.text('Loading messages...'), findsOneWidget);
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
              onRefresh: () {},
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
              onRefresh: () {},
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
              onRefresh: () {},
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
}

class _ThrowingMediaPicker implements MessengerMediaPicker {
  const _ThrowingMediaPicker();

  @override
  Future<MessengerPickedMedia?> pick(MessengerMediaKind kind) async {
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
