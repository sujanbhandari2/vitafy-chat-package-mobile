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

    test('DeliveredReceipt and ReadReceipt parse snake_case keys', () {
      final delivered = DeliveredReceipt.fromJson({
        'id': 'd1',
        'message_id': 'm1',
        'user_id': 'u1',
        'deliveredAt': '2026-04-23T12:00:00.000Z',
        'conversation_id': 'c1',
      });
      expect(delivered.messageId, 'm1');
      expect(delivered.conversationId, 'c1');

      final read = ReadReceipt.fromJson({
        'id': 'r1',
        'messageId': 'm1',
        'chatUserId': 'u1',
        'readAt': '2026-04-23T12:01:00.000Z',
      });
      expect(read.userId, 'u1');
    });

    test('RemovedReactionEvent fromJson', () {
      final removed = RemovedReactionEvent.fromJson({
        'messageId': 'm1',
        'conversationId': 'c1',
        'userId': 'u2',
      });
      expect(removed.messageId, 'm1');
      expect(removed.userId, 'u2');
    });

    test('ChatTypingEvent.fromJson accepts snake_case keys', () {
      final typing = ChatTypingEvent.fromJson({
        'conversation_id': 'conv-9',
        'user_id': 'user-2',
        'name': 'Bob',
      });
      expect(typing.conversationId, 'conv-9');
      expect(typing.userId, 'user-2');
      expect(typing.name, 'Bob');
    });

    test('ChatTypingEvent.fromJson accepts chatUserId', () {
      final typing = ChatTypingEvent.fromJson({
        'conversationId': 'c1',
        'chatUserId': 'legacy-u',
      });
      expect(typing.userId, 'legacy-u');
    });
  });
}
