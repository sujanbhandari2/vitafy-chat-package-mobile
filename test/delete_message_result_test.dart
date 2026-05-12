import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';

void main() {
  group('DeleteMessageResult.fromJson', () {
    test('parses delete payload with deletedAt', () {
      final deletedAt = DateTime.utc(2026, 5, 5, 10, 0, 0);
      final parsed = DeleteMessageResult.fromJson({
        'deleted': true,
        'messageId': 'm-1',
        'conversationId': 'c-1',
        'deletedAt': deletedAt.toIso8601String(),
      });

      expect(parsed.deleted, isTrue);
      expect(parsed.messageId, 'm-1');
      expect(parsed.conversationId, 'c-1');
      expect(parsed.deletedAt, deletedAt);
    });

    test('handles optional deletedAt and mixed deleted values', () {
      final parsed = DeleteMessageResult.fromJson({
        'deleted': '1',
        'message_id': 'm-2',
        'conversation_id': 'c-2',
      });

      expect(parsed.deleted, isTrue);
      expect(parsed.messageId, 'm-2');
      expect(parsed.conversationId, 'c-2');
      expect(parsed.deletedAt, isNull);
    });
  });
}
