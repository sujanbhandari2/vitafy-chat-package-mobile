import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

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
    // Tap the row action: title text is not wired to onTap (only the Chat button is).
    await tester.tap(find.text('Chat').at(1));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(_HostShellHarnessState.openDirectCallCount, 1);
    expect(_HostShellHarnessState.latestSelectedConversationId, 'c2');
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
    await tester.tap(find.text('Chat').at(1));
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
      'isListPaneRefreshing with suggested slot shows inline spinner not panel',
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

class _DeferredOpenDirectHarnessState extends State<_DeferredOpenDirectHarness> {
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
