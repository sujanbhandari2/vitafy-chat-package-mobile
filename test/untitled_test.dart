import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';

void main() {
  group('Chat client models', () {
    test('ChatAuth builds API headers and socket auth payload', () {
      const auth = ChatAuth(
        apiKey: 'access:secret',
        chatUserId: '42',
      );

      expect(auth.toApiHeaders()['X-Api-Key'], 'access:secret');
      expect(
        auth.toSocketAuth(),
        {
          'apiKey': 'access:secret',
          'xApiKey': 'access:secret',
          'userId': '42',
          'chatUserId': '42',
        },
      );
    });

    test('ChatMessage parses attachments and reply snapshots', () {
      final message = ChatMessage.fromJson({
        'id': '100',
        'conversationId': '55',
        'tenantId': '8',
        'senderId': '42',
        'type': 'IMAGE',
        'content': 'hello',
        'attachments': [
          {
            'url': 'https://cdn.example.com/file.png',
            'mimeType': 'image/png',
            'fileName': 'file.png',
            'byteSize': 1200,
            'kind': 'upload',
          },
        ],
        'replyToMessageId': '99',
        'replyTo': {
          'id': '99',
          'senderId': '11',
          'type': 'TEXT',
          'content': 'original',
          'createdAt': '2026-04-23T10:00:00.000Z',
        },
        'createdAt': '2026-04-23T10:10:00.000Z',
      });

      expect(message.type, MessageType.image);
      expect(
          message.attachments.single.url, 'https://cdn.example.com/file.png');
      expect(message.replyToMessageId, '99');
      expect(message.replyTo?.content, 'original');
    });
  });
}
