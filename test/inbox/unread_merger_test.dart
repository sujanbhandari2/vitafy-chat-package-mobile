import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/chat_repository.dart';
import 'package:health_messenger_ui/lib/src/client/inbox/unread_merger.dart';
import 'package:health_messenger_ui/lib/src/client/models/chat_message.dart';
import 'package:health_messenger_ui/lib/src/client/models/conversation.dart';

ChatMessage _msg({
  required String id,
  required String conversationId,
  required String senderId,
}) {
  return ChatMessage.fromJson({
    'id': id,
    'conversationId': conversationId,
    'tenantId': 't1',
    'senderId': senderId,
    'type': 'TEXT',
    'content': 'hi',
    'createdAt': DateTime.utc(2026).toIso8601String(),
  });
}

void main() {
  group('UnreadMerger', () {
    test('mergeFromConversations ignores positive unreadCount for own latest',
        () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'unreadCount': 3,
          'latestMessage': {
            'id': '100',
            'conversationId': 'a',
            'tenantId': 't',
            'senderId': 'me',
            'type': 'TEXT',
            'content': 'sent',
            'createdAt': DateTime.utc(2026).toIso8601String(),
          },
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{'a': 2},
        list,
        currentUserId: 'me',
      );
      expect(out.containsKey('a'), isFalse);
    });

    test('mergeFromConversations sets and removes', () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'unreadCount': 3,
        }),
        Conversation.fromJson({
          'id': 'b',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'unread': 0,
        }),
      ];
      final prev = <String, int>{'c': 9};
      final out = UnreadMerger.mergeFromConversations(
        prev,
        list,
        currentUserId: 'me',
      );
      expect(out['a'], 3);
      expect(out.containsKey('b'), isFalse);
      expect(out['c'], 9);
    });

    test('mergeFromConversations derives unread from message status', () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'latestMessageId': '100',
          'messageStatus': [
            {'userId': 'me', 'lastReadMessageId': '90'},
          ],
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{},
        list,
        currentUserId: 'me',
      );
      expect(out['a'], 1);
    });

    test('mergeFromConversations preserves prior count when status says unread',
        () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'latestMessageId': '100',
          'messageStatus': [
            {'userId': 'me', 'lastReadMessageId': '50'},
          ],
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{'a': 7},
        list,
        currentUserId: 'me',
      );
      expect(out['a'], 7);
    });

    test('mergeFromConversations clears when REST unreadCount is 0', () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'unreadCount': 0,
          'latestMessageId': '100',
          'messageStatus': [
            {'userId': 'me', 'lastReadMessageId': '100'},
          ],
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{'a': 5},
        list,
        currentUserId: 'me',
      );
      expect(out.containsKey('a'), isFalse);
    });

    test(
        'mergeFromConversations preserves socket unread when REST omits unreadCount',
        () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'latestMessageId': '100',
          'messageStatus': [
            {'userId': 'me', 'lastReadMessageId': '100'},
          ],
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{'a': 3},
        list,
        currentUserId: 'me',
      );
      expect(out['a'], 3);
    });

    test('mergeFromConversations supports per-participant messageStatus', () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [
            {
              'id': 'p1',
              'chatUserId': 'me',
              'conversationId': 'a',
              'chatUser': {'id': 'me'},
              'messageStatus': {'lastReadMessageId': '90'},
            },
          ],
          'latestMessageId': '100',
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{},
        list,
        currentUserId: 'me',
      );
      expect(out['a'], 1);
    });

    test('mergeFromConversations force-clears active conversation when visible',
        () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'latestMessageId': '100',
          'messageStatus': [
            {'userId': 'me', 'lastReadMessageId': '50'},
          ],
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{'a': 3},
        list,
        currentUserId: 'me',
        activeConversationId: 'a',
        clearActiveConversationUnread: true,
      );
      expect(out.containsKey('a'), isFalse);
    });

    test(
        'mergeFromConversations does not clear active conversation when list only',
        () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'unreadCount': 2,
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{'a': 2},
        list,
        currentUserId: 'me',
        activeConversationId: 'a',
        clearActiveConversationUnread: false,
      );
      expect(out['a'], 2);
    });

    test(
        'mergeFromConversations derives unread from messageState over unreadCount 0',
        () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'unreadCount': 0,
          'latestMessage': {
            'id': '329',
            'conversationId': 'a',
            'tenantId': 't',
            'senderId': 'other',
            'type': 'TEXT',
            'content': 'hi',
            'createdAt': DateTime.utc(2026).toIso8601String(),
          },
          'messageState': {'lastReadMessageId': '320'},
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{},
        list,
        currentUserId: 'me',
      );
      expect(out['a'], 1);
    });

    test(
        'mergeFromConversations clears when messageState shows read despite unreadCount 0',
        () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'unreadCount': 0,
          'latestMessage': {
            'id': '329',
            'conversationId': 'a',
            'tenantId': 't',
            'senderId': 'other',
            'type': 'TEXT',
            'content': 'hi',
            'createdAt': DateTime.utc(2026).toIso8601String(),
          },
          'messageState': {'lastReadMessageId': '329'},
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{'a': 5},
        list,
        currentUserId: 'me',
      );
      expect(out.containsKey('a'), isFalse);
    });

    test(
        'mergeFromConversations unread when messageState lastRead is null and unreadCount 0',
        () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'unreadCount': 0,
          'latestMessageId': '329',
          'messageState': {'lastReadMessageId': null},
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{},
        list,
        currentUserId: 'me',
      );
      expect(out['a'], 1);
    });

    test(
        'mergeFromConversations uses explicit unreadCount when no latest message id',
        () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'unreadCount': 3,
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{},
        list,
        currentUserId: 'me',
      );
      expect(out['a'], 3);
    });

    test('mergeFromConversations leaves rows untouched when no signal', () {
      final list = [
        Conversation.fromJson({
          'id': 'a',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
        }),
      ];
      final out = UnreadMerger.mergeFromConversations(
        <String, int>{'a': 4},
        list,
        currentUserId: 'me',
      );
      expect(out['a'], 4);
    });

    test('applyConversationMessage uses server count', () {
      final event = ConversationMessageEvent.fromJson({
        'conversationId': 'c1',
        'message': {
          'id': 'm1',
          'conversationId': 'c1',
          'tenantId': 't',
          'senderId': 'other',
          'type': 'TEXT',
          'content': 'x',
          'createdAt': DateTime.utc(2026).toIso8601String(),
        },
        'unreadCount': 2,
      });
      final out = UnreadMerger.applyConversationMessage(
        {},
        event,
        currentUserId: 'me',
      );
      expect(out['c1'], 2);
    });

    test('applyConversationMessage own message without count leaves map', () {
      final event = ConversationMessageEvent.fromJson({
        'conversationId': 'c1',
        'message': {
          'id': 'm1',
          'conversationId': 'c1',
          'tenantId': 't',
          'senderId': 'me',
          'type': 'TEXT',
          'content': 'x',
          'createdAt': DateTime.utc(2026).toIso8601String(),
        },
      });
      final prev = <String, int>{'c1': 1};
      final out = UnreadMerger.applyConversationMessage(
        prev,
        event,
        currentUserId: 'me',
      );
      expect(out['c1'], 1);
    });

    test('applyUnreadCountUpdated ignores other user', () {
      final event = UnreadCountUpdatedEvent.fromJson({
        'conversationId': 'c1',
        'userId': 'other',
        'unread': 9,
      });
      final out = UnreadMerger.applyUnreadCountUpdated(
        {},
        event,
        currentUserId: 'me',
      );
      expect(out, isEmpty);
    });

    test('incrementForBroadcastFallback skips when conversation path seen', () {
      final m = _msg(id: 'm1', conversationId: 'c1', senderId: 'peer');
      final out = UnreadMerger.incrementForBroadcastFallback(
        {},
        m,
        currentUserId: 'me',
        activeConversationId: null,
        conversationMessageSeen: true,
      );
      expect(out, isEmpty);
    });

    test('applyOwnMessageInActiveThread clears unread', () {
      final m = _msg(id: 'm1', conversationId: 'c1', senderId: 'me');
      final out = UnreadMerger.applyOwnMessageInActiveThread(
        {'c1': 2},
        m,
        currentUserId: 'me',
        activeConversationId: 'c1',
      );
      expect(out.containsKey('c1'), isFalse);
    });
  });
}
