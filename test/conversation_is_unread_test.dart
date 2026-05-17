import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/models/conversation.dart';

void main() {
  group('Conversation.isUnreadFor', () {
    Conversation conversationFrom({
      String? latestMessageId,
      Map<String, dynamic>? latestMessage,
      Map<String, dynamic>? messageState,
      Object? messageStatus,
      int? unreadCount,
    }) {
      return Conversation.fromJson({
        'id': '200',
        'tenantId': '1',
        'type': 'DIRECT',
        'createdAt': DateTime.utc(2026, 5, 15).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 5, 15).toIso8601String(),
        'participants': <dynamic>[],
        if (latestMessageId != null) 'latestMessageId': latestMessageId,
        if (latestMessage != null) 'latestMessage': latestMessage,
        if (messageState != null) 'messageState': messageState,
        if (messageStatus != null) 'messageStatus': messageStatus,
        if (unreadCount != null) 'unreadCount': unreadCount,
      });
    }

    test('unread when latest id is greater than lastReadMessageId', () {
      final c = conversationFrom(
        latestMessage: {
          'id': '329',
          'conversationId': '200',
          'tenantId': '1',
          'senderId': '243',
          'type': 'TEXT',
          'content': 'hyy',
          'createdAt': DateTime.utc(2026, 5, 15).toIso8601String(),
        },
        messageState: {'lastReadMessageId': '320'},
        unreadCount: 0,
      );

      expect(c.isUnreadFor('me'), isTrue);
    });

    test('unread when lastReadMessageId is null', () {
      final c = conversationFrom(
        latestMessageId: '329',
        messageState: {'lastReadMessageId': null},
        unreadCount: 0,
      );

      expect(c.isUnreadFor('me'), isTrue);
    });

    test('read when latest id equals lastReadMessageId', () {
      final c = conversationFrom(
        latestMessage: {
          'id': '329',
          'conversationId': '200',
          'tenantId': '1',
          'senderId': '243',
          'type': 'TEXT',
          'content': 'hyy',
          'createdAt': DateTime.utc(2026, 5, 15).toIso8601String(),
        },
        messageState: {'lastReadMessageId': '329'},
        unreadCount: 0,
      );

      expect(c.isUnreadFor('me'), isFalse);
    });

    test('parses top-level messageState from REST list shape', () {
      final c = Conversation.fromJson({
        'id': '200',
        'tenantId': '1',
        'type': 'DIRECT',
        'createdAt': DateTime.utc(2026, 5, 15).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 5, 15).toIso8601String(),
        'participants': <dynamic>[],
        'unreadCount': 0,
        'latestMessage': {
          'id': '329',
          'conversationId': '200',
          'tenantId': '1',
          'senderId': '243',
          'type': 'TEXT',
          'content': 'hyy',
          'createdAt': DateTime.utc(2026, 5, 15, 9, 29, 39, 385).toIso8601String(),
        },
        'messageState': {
          'lastReadMessageId': '329',
          'lastDeliveredMessageId': null,
        },
      });

      expect(c.messageState?.lastReadMessageId, '329');
      expect(c.latestMessageId, '329');
      expect(c.isUnreadFor('me'), isFalse);
    });

    test('prefers per-user messageStatus over messageState', () {
      final c = conversationFrom(
        latestMessageId: '100',
        messageState: {'lastReadMessageId': '50'},
        messageStatus: [
          {'userId': 'me', 'lastReadMessageId': '100'},
        ],
      );

      expect(c.isUnreadFor('me'), isFalse);
    });
  });
}
