import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  MessengerChatMessage fileMessage({
    required String content,
    String? fileName,
    String? mimeType,
  }) {
    return MessengerChatMessage(
      id: 'm-file',
      senderId: 'u1',
      senderLabel: 'User',
      type: MessengerMessageType.file,
      content: content,
      createdAt: DateTime.utc(2026),
      attachments: fileName == null && mimeType == null
          ? const []
          : [
              MessengerMessageAttachment(
                url: content,
                fileName: fileName,
                mimeType: mimeType,
                kind: MessengerMessageAttachmentKind.file,
              ),
            ],
    );
  }

  testWidgets('tapping file tile opens preview dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerTheme(
          data: const MessengerThemeData(),
          child: Scaffold(
            body: MessengerMessageBubble(
              message: fileMessage(
                content: 'https://example.com/report.docx',
                fileName: 'report.docx',
              ),
              isMine: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('report.docx'), findsOneWidget);
    await tester.tap(find.text('report.docx'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Preview not available'), findsOneWidget);
    expect(find.byTooltip('Download'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  test('txt attachment is classified as in-app previewable', () {
    expect(
      messengerDocumentPreviewKind(
        fileName: 'hello.txt',
        mimeType: 'text/plain',
      ),
      MessengerDocumentPreviewKind.text,
    );
  });
}
