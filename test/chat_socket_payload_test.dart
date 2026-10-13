import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';

void main() {
  group('mapChatSocketPayload', () {
    test('unwraps nested message for flat ChatMessage paths', () {
      final mapped = mapChatSocketPayload({
        'conversationId': 'c1',
        'message': {
          'id': 'm1',
          'conversationId': 'c1',
          'tenantId': 't1',
          'senderId': 'u1',
          'type': 'TEXT',
          'content': 'hello',
          'createdAt': '2026-07-17T12:00:00.000Z',
        },
      });

      expect(mapped['id'], 'm1');
      expect(mapped['content'], 'hello');
      expect(mapped['senderId'], 'u1');
    });

    test('preserves conversation_message envelope when unwrap disabled', () {
      final envelope = {
        'conversationId': 'c1',
        'message': {
          'id': 'm1',
          'conversationId': 'c1',
          'tenantId': 't1',
          'senderId': 'u2',
          'type': 'TEXT',
          'content': 'hello',
          'createdAt': '2026-07-17T12:00:00.000Z',
        },
        'unreadCount': 4,
      };

      final mapped = mapChatSocketPayload(
        envelope,
        unwrapNestedMessage: false,
      );
      final event = ConversationMessageEvent.fromJson(mapped);

      expect(event.conversationId, 'c1');
      expect(event.unreadCount, 4);
      expect(event.message.id, 'm1');
      expect(event.message.content, 'hello');
      expect(event.message.senderId, 'u2');
    });

    test('fromJson recovers message if envelope was unwrapped', () {
      // Defense in depth: even if unwrap runs, the message body is recovered.
      // Outer unreadCount is still lost — that is why event parsers disable unwrap.
      final mapped = mapChatSocketPayload({
        'conversationId': 'c1',
        'message': {
          'id': 'm1',
          'conversationId': 'c1',
          'tenantId': 't1',
          'senderId': 'u2',
          'type': 'TEXT',
          'content': 'hello',
          'createdAt': '2026-07-17T12:00:00.000Z',
        },
        'unreadCount': 4,
      });
      final event = ConversationMessageEvent.fromJson(mapped);

      expect(event.message.id, 'm1');
      expect(event.message.content, 'hello');
      expect(event.conversationId, 'c1');
      expect(event.unreadCount, isNull);
    });
  });

  group('ConversationMessageEvent.fromJson', () {
    test('accepts flat message payloads', () {
      final event = ConversationMessageEvent.fromJson({
        'id': 'm9',
        'conversationId': 'c1',
        'tenantId': 't1',
        'senderId': 'u2',
        'type': 'TEXT',
        'content': 'flat',
        'createdAt': '2026-07-17T12:00:00.000Z',
      });

      expect(event.conversationId, 'c1');
      expect(event.message.id, 'm9');
      expect(event.message.content, 'flat');
    });
  });
}
