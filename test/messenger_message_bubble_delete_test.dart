import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  MessengerChatMessage makeMessage({
    String content = 'Hello',
    bool isDeleted = false,
    String senderId = 'me',
  }) {
    return MessengerChatMessage(
      id: 'm-1',
      senderId: senderId,
      senderLabel: 'Me',
      type: MessengerMessageType.text,
      content: content,
      createdAt: DateTime.utc(2026),
      isDeleted: isDeleted,
    );
  }

  testWidgets('renders tombstone for deleted message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerMessageBubble(
              message: makeMessage(content: 'secret', isDeleted: true),
              isMine: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Message deleted'), findsOneWidget);
    expect(find.text('secret'), findsNothing);
  });

  testWidgets('shows delete action only when canDelete is true',
      (tester) async {
    var deleteCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: Column(
              children: [
                MessengerMessageBubble(
                  message: makeMessage(content: 'Allow delete'),
                  isMine: true,
                  canDelete: true,
                  onDelete: () {
                    deleteCalls++;
                  },
                ),
                MessengerMessageBubble(
                  message:
                      makeMessage(content: 'Blocked delete', senderId: 'other'),
                  isMine: false,
                  canDelete: false,
                  onDelete: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Allow delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete message'), findsOneWidget);
    await tester.tap(find.text('Delete message'));
    await tester.pumpAndSettle();
    expect(find.text('Delete message?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleteCalls, 1);

    await tester.longPress(find.text('Blocked delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete message'), findsNothing);
  });

  testWidgets(
    'long-press sheet shows reactions on top and delete below',
    (tester) async {
      String? chosenReaction;
      var deleteCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MessengerTheme(
            data: const MessengerThemeData(),
            child: Scaffold(
              body: MessengerMessageBubble(
                message: makeMessage(content: 'Actionable'),
                isMine: true,
                enableReactions: true,
                reactionOptions: const ['👍', '❤️'],
                onReact: (reaction) {
                  chosenReaction = reaction;
                },
                canDelete: true,
                onDelete: () {
                  deleteCalls++;
                },
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('Actionable'));
      await tester.pumpAndSettle();

      expect(find.text('👍'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('Delete message'), findsOneWidget);

      final reactY = tester.getCenter(find.text('👍')).dy;
      final deleteY = tester.getCenter(find.text('Delete message')).dy;
      expect(reactY, lessThan(deleteY));

      await tester.tap(find.text('👍'));
      await tester.pumpAndSettle();
      expect(chosenReaction, '👍');
      expect(deleteCalls, 0);
    },
  );

  testWidgets('long-press unfocuses active text input to avoid keyboard pop',
      (tester) async {
    final inputFocus = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: inputFocus),
                MessengerMessageBubble(
                  message: makeMessage(content: 'Focus test'),
                  isMine: true,
                  canDelete: true,
                  onDelete: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    inputFocus.requestFocus();
    await tester.pump();
    expect(inputFocus.hasFocus, isTrue);

    await tester.longPress(find.text('Focus test'));
    await tester.pumpAndSettle();
    expect(inputFocus.hasFocus, isFalse);
    expect(find.text('Delete message'), findsOneWidget);
  });

  testWidgets('delete dialog shows loader while delete is in progress',
      (tester) async {
    final completer = Completer<void>();
    var deleteCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerMessageBubble(
              message: makeMessage(content: 'Pending delete'),
              isMine: true,
              canDelete: true,
              onDelete: () async {
                deleteCalls++;
                await completer.future;
              },
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Pending delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete message'));
    await tester.pumpAndSettle();

    expect(find.text('Delete message?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pump();

    expect(deleteCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Delete message?'), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Delete message?'), findsNothing);
  });

  testWidgets('deleted message hides reaction panel in action sheet',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerMessageBubble(
              message: makeMessage(content: 'Deleted', isDeleted: true),
              isMine: true,
              enableReactions: true,
              reactionOptions: const ['👍', '❤️'],
              onReact: (_) {},
              canDelete: true,
              onDelete: () {},
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Message deleted'));
    await tester.pumpAndSettle();

    expect(find.text('👍'), findsNothing);
    expect(find.text('❤️'), findsNothing);
    expect(find.text('Delete message'), findsOneWidget);
  });

  testWidgets('delete confirmation dialog applies packageDialogTheme',
      (tester) async {
    const dialogTheme = DialogThemeData(
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      contentTextStyle: TextStyle(fontSize: 11, height: 1.2),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(dialogTheme: const DialogThemeData()),
        home: Builder(
          builder: (context) {
            return MessengerTheme(
              data: const MessengerThemeData(),
              child: Scaffold(
                body: MessengerMessageBubble(
                  message: makeMessage(content: 'Themed delete'),
                  isMine: true,
                  canDelete: true,
                  onDelete: () {},
                  packageDialogTheme: Theme.of(context).copyWith(
                    dialogTheme: dialogTheme,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.longPress(find.text('Themed delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete message'));
    await tester.pumpAndSettle();

    final titleStyle = DefaultTextStyle.of(
      tester.element(find.text('Delete message?')),
    ).style;
    final contentStyle = DefaultTextStyle.of(
      tester.element(
        find.textContaining('Are you sure you want to delete this message?'),
      ),
    ).style;
    expect(titleStyle.fontSize, 22);
    expect(titleStyle.fontWeight, FontWeight.w900);
    expect(contentStyle.fontSize, 11);
  });

  testWidgets('delete action uses custom icon and text style', (tester) async {
    const customStyle = TextStyle(color: Colors.purple, fontSize: 18);
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerMessageBubble(
              message: makeMessage(content: 'Styled delete'),
              isMine: true,
              canDelete: true,
              onDelete: () {},
              deleteActionIcon: Icons.delete_forever_rounded,
              deleteActionTextStyle: customStyle,
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Styled delete'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.delete_forever_rounded,
      ),
      findsOneWidget,
    );

    final purpleIcon = tester.widget<Icon>(
      find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            w.icon == Icons.delete_forever_rounded &&
            w.color == Colors.purple,
      ),
    );
    expect(purpleIcon.icon, Icons.delete_forever_rounded);

    final label = tester.widget<Text>(find.text('Delete message'));
    expect(label.style?.color, customStyle.color);
    expect(label.style?.fontSize, customStyle.fontSize);
  });

  testWidgets('long-press does nothing when no actions are available',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerMessageBubble(
              message: makeMessage(content: 'No actions'),
              isMine: true,
              enableReactions: false,
              canDelete: false,
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('No actions'));
    await tester.pumpAndSettle();
    expect(find.text('Delete message'), findsNothing);
    expect(find.text('React'), findsNothing);
  });

  testWidgets(
      'default theme uses blue outgoing bubble and white incoming bubble',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: Column(
              children: [
                MessengerMessageBubble(
                  message: makeMessage(content: 'Mine'),
                  isMine: true,
                ),
                MessengerMessageBubble(
                  message: makeMessage(
                    content: 'Theirs',
                    senderId: 'other',
                  ),
                  isMine: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final decoratedContainers = tester
        .widgetList<Container>(find.byType(Container))
        .where((widget) => widget.decoration is BoxDecoration)
        .toList(growable: false);
    final colors = decoratedContainers
        .map((widget) => (widget.decoration! as BoxDecoration).color)
        .whereType<Color>()
        .toList(growable: false);

    expect(colors, contains(const Color(0xFF1B74E4)));
    expect(colors, contains(Colors.white));
  });

  testWidgets('seen delivery state uses high-contrast status chip',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerMessageBubble(
              message: MessengerChatMessage(
                id: 'seen-1',
                senderId: 'me',
                senderLabel: 'Me',
                type: MessengerMessageType.text,
                content: 'Seen message',
                createdAt: DateTime.utc(2026),
                deliveryStatus: MessengerDeliveryStatus.seen,
              ),
              isMine: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
            (widget.decoration! as BoxDecoration).color == Colors.white,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.done_all &&
            widget.color == const Color(0xFF1B74E4),
      ),
      findsOneWidget,
    );
  });
}
