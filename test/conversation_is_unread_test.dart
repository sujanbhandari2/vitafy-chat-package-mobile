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

    test('unread when lastReadMessageId is null and latest is from peer', () {
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
        messageState: {'lastReadMessageId': null},
        unreadCount: 0,
      );

      expect(c.isUnreadFor('me'), isTrue);
    });

    test('not unread when latest message is from current user', () {
      final c = conversationFrom(
        latestMessage: {
          'id': '373',
          'conversationId': '213',
          'tenantId': '1',
          'senderId': 'me',
          'type': 'TEXT',
          'content': 'kamoo',
          'createdAt': DateTime.utc(2026, 5, 17).toIso8601String(),
        },
        messageState: {
          'lastReadMessageId': null,
          'lastDeliveredMessageId': null,
        },
        unreadCount: 0,
      );

      expect(c.isUnreadFor('me'), isFalse);
    });

    test(
        'not unread when lastRead and lastDelivered match latest (Vitafy list shape)',
        () {
      final c = Conversation.fromJson({
        'id': '212',
        'tenantId': '1',
        'type': 'DIRECT',
        'createdAt': DateTime.utc(2026, 5, 17).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 5, 17).toIso8601String(),
        'participants': <dynamic>[],
        'unreadCount': 0,
        'latestMessage': {
          'id': '371',
          'conversationId': '212',
          'tenantId': '1',
          'senderId': '243',
          'type': 'TEXT',
          'content': 'nothing?',
          'createdAt': DateTime.utc(2026, 5, 17).toIso8601String(),
        },
        'messageState': {
          'lastReadMessageId': '371',
          'lastDeliveredMessageId': '371',
        },
      });

      expect(c.isUnreadFor('me'), isFalse);
    });

    test(
        'unread when lastRead equals lastDelivered but latest message is newer',
        () {
      final c = conversationFrom(
        latestMessage: {
          'id': '400',
          'conversationId': '200',
          'tenantId': '1',
          'senderId': '243',
          'type': 'TEXT',
          'content': 'new',
          'createdAt': DateTime.utc(2026, 5, 17).toIso8601String(),
        },
        messageState: {
          'lastReadMessageId': '371',
          'lastDeliveredMessageId': '371',
        },
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
