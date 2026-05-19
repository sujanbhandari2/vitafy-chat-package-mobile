import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  ChatMessage message({
    MessageType type = MessageType.text,
    String content = '',
    List<ChatAttachment> attachments = const [],
    DateTime? deletedAt,
  }) {
    return ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      tenantId: 't1',
      senderId: 'u1',
      type: type,
      content: content,
      attachments: attachments,
      replyToMessageId: null,
      replyTo: null,
      translatedMessage: null,
      transcribedMessage: null,
      editedAt: null,
      deletedAt: deletedAt,
      createdAt: DateTime.utc(2026, 1, 1),
      reactions: const [],
      deliveredReceipts: const [],
      readReceipts: const [],
    );
  }

  test('deleted message shows Message deleted', () {
    expect(
      messengerConversationPreview(
        message(deletedAt: DateTime.utc(2026, 1, 2)),
      ),
      'Message deleted',
    );
  });

  test('content sentinel [deleted] shows Message deleted', () {
    expect(
      messengerConversationPreview(message(content: '[deleted]')),
      'Message deleted',
    );
  });

  test('image with attachment and empty content shows Photo', () {
    expect(
      messengerConversationPreview(
        message(
          type: MessageType.image,
          attachments: const [
            ChatAttachment(
              url: '/api/upload/photo.jpg',
              mimeType: 'image/jpeg',
              kind: 'image',
            ),
          ],
        ),
        mediaBaseOrigin: 'https://api.example.com',
      ),
      'Photo',
    );
  });

  test('voice message shows Voice message', () {
    expect(
      messengerConversationPreview(
        message(
          type: MessageType.voice,
          attachments: const [
            ChatAttachment(url: 'https://cdn.example.com/a.m4a', kind: 'voice'),
          ],
        ),
      ),
      'Voice message',
    );
  });

  test('file attachment shows File', () {
    expect(
      messengerConversationPreview(
        message(
          type: MessageType.file,
          attachments: const [
            ChatAttachment(
              url: 'https://cdn.example.com/doc.pdf',
              mimeType: 'application/pdf',
              fileName: 'report.pdf',
              kind: 'file',
            ),
          ],
        ),
      ),
      'File',
    );
  });

  test('text body is shown for text messages', () {
    expect(
      messengerConversationPreview(message(content: 'Hello team')),
      'Hello team',
    );
  });

  test('content equal to attachment URL shows Photo not URL', () {
    expect(
      messengerConversationPreview(
        message(
          type: MessageType.image,
          content: 'https://cdn.example.com/photo.jpg',
          attachments: const [
            ChatAttachment(
              url: 'https://cdn.example.com/photo.jpg',
              mimeType: 'image/jpeg',
              kind: 'image',
            ),
          ],
        ),
      ),
      'Photo',
    );
  });

  test('relative attachment URL matches absolutized content', () {
    expect(
      messengerConversationPreview(
        message(
          type: MessageType.image,
          content: 'https://api.example.com/api/upload/photo.jpg',
          attachments: const [
            ChatAttachment(
              url: '/api/upload/photo.jpg',
              mimeType: 'image/jpeg',
              kind: 'image',
            ),
          ],
        ),
        mediaBaseOrigin: 'https://api.example.com',
      ),
      'Photo',
    );
  });

  test('messengerMediaPreviewLabel matches reply snippet media labels', () {
    expect(
      messengerMediaPreviewLabel(MessengerMessageType.image),
      'Photo',
    );
    expect(
      messengerReplyPreviewSnippet(
        MessengerChatMessage(
          id: '1',
          senderId: 'u',
          senderLabel: 'You',
          type: MessengerMessageType.voice,
          content: 'https://cdn.example.com/a.m4a',
          createdAt: DateTime.utc(2026),
        ),
      ),
      'Voice message',
    );
  });
}
