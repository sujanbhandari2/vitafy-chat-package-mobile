import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/models/conversation.dart';

void main() {
  group('Conversation.fromJson', () {
    test('parses optional latestMessage from REST list shape', () {
      final created = DateTime.utc(2026, 5, 4, 12, 0, 13);
      final msgCreated = DateTime.utc(2026, 5, 4, 12, 9, 11, 201);

      final c = Conversation.fromJson({
        'id': '35',
        'tenantId': '1',
        'type': 'DIRECT',
        'createdAt': created.toIso8601String(),
        'updatedAt': created.toIso8601String(),
        'participants': <dynamic>[],
        'latestMessage': {
          'id': '224',
          'conversationId': '35',
          'tenantId': '1',
          'senderId': '21',
          'type': 'TEXT',
          'content': 'ssdsdsds',
          'status': 'SENT',
          'createdAt': msgCreated.toIso8601String(),
          'sender': {'id': '21', 'name': 'Sujan Flutter'},
        },
      });

      expect(c.latestMessage, isNotNull);
      expect(c.latestMessage!.content, 'ssdsdsds');
      expect(c.latestMessage!.id, '224');
      expect(c.latestMessage!.conversationId, '35');
      expect(c.latestMessage!.createdAt, msgCreated);
      expect(c.latestMessage!.sender?.name, 'Sujan Flutter');
    });

    test('parses latest_message snake_case alias', () {
      final c = Conversation.fromJson({
        'id': 'a',
        'tenantId': 't',
        'type': 'DIRECT',
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'updatedAt': DateTime.utc(2026).toIso8601String(),
        'participants': <dynamic>[],
        'latest_message': {
          'id': '1',
          'conversationId': 'a',
          'tenantId': 't',
          'senderId': '9',
          'type': 'TEXT',
          'content': 'snake',
          'createdAt': DateTime.utc(2026, 6, 1).toIso8601String(),
        },
      });

      expect(c.latestMessage?.content, 'snake');
    });

    test('latestMessage is null when absent', () {
      final c = Conversation.fromJson({
        'id': 'a',
        'tenantId': 't',
        'type': 'DIRECT',
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'updatedAt': DateTime.utc(2026).toIso8601String(),
        'participants': <dynamic>[],
      });

      expect(c.latestMessage, isNull);
    });
  });
}
