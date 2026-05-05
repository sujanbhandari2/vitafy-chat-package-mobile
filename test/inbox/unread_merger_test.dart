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
      final out = UnreadMerger.mergeFromConversations(prev, list);
      expect(out['a'], 3);
      expect(out.containsKey('b'), isFalse);
      expect(out['c'], 9);
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
