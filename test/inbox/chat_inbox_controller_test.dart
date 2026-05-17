import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/chat_client.dart';
import 'package:health_messenger_ui/lib/src/client/chat_config.dart';
import 'package:health_messenger_ui/lib/src/client/chat_connection_state.dart';
import 'package:health_messenger_ui/lib/src/client/chat_repository.dart';
import 'package:health_messenger_ui/lib/src/client/inbox/chat_inbox_controller.dart';
import 'package:health_messenger_ui/lib/src/client/models/chat_message.dart';
import 'package:health_messenger_ui/lib/src/client/models/conversation.dart';
import 'package:health_messenger_ui/lib/src/client/testing/fake_chat_repository.dart';

void main() {
  group('ChatInboxController', () {
    test('setActiveConversation joins then marks conversation read', () async {
      final fake = FakeChatRepository();
      final client = ChatClient(
        config: const ChatServiceConfig(
          apiBaseUrl: 'http://localhost',
          socketUrl: 'http://localhost',
        ),
        repository: fake,
      );
      final connection = StreamController<ChatConnectionState>.broadcast();
      final controller = ChatInboxController(
        client: client,
        currentUserId: 'user-1',
        connectionState: connection.stream,
      );

      await controller.setActiveConversation('room-a');

      expect(fake.joinConversationLog, ['room-a']);
      expect(fake.markConversationReadLog, isEmpty);

      await controller.setThreadVisible(true);

      expect(fake.markConversationReadLog, ['room-a']);

      await controller.dispose();
      await connection.close();
    });

    test('peer message increments unread when not active', () async {
      final fake = FakeChatRepository();
      final client = ChatClient(
        config: const ChatServiceConfig(
          apiBaseUrl: 'http://localhost',
          socketUrl: 'http://localhost',
        ),
        repository: fake,
      );
      final connection = StreamController<ChatConnectionState>.broadcast();
      final controller = ChatInboxController(
        client: client,
        currentUserId: 'user-1',
        connectionState: connection.stream,
      );

      fake.emitSocket(
        ChatSocketEvent(
          type: ChatSocketEventType.messageReceived,
          message: ChatMessage.fromJson({
            'id': 'm-ext',
            'conversationId': 'c2',
            'tenantId': 't',
            'senderId': 'user-2',
            'type': 'TEXT',
            'content': 'hello',
            'createdAt': DateTime.utc(2026).toIso8601String(),
          }),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(controller.unreadByConversation.value['c2'], 1);
      expect(fake.markAsDeliveredLog, contains('c2:m-ext'));
      expect(fake.markAsReadLog, isEmpty);

      await controller.dispose();
      await connection.close();
    });

    test('peer message does not mark read when thread is not visible', () async {
      final fake = FakeChatRepository();
      final client = ChatClient(
        config: const ChatServiceConfig(
          apiBaseUrl: 'http://localhost',
          socketUrl: 'http://localhost',
        ),
        repository: fake,
      );
      final connection = StreamController<ChatConnectionState>.broadcast();
      final controller = ChatInboxController(
        client: client,
        currentUserId: 'user-1',
        connectionState: connection.stream,
      );

      await controller.setActiveConversation('c-open');
      expect(fake.markConversationReadLog, isEmpty);

      fake.emitSocket(
        ChatSocketEvent(
          type: ChatSocketEventType.messageReceived,
          message: ChatMessage.fromJson({
            'id': 'm1',
            'conversationId': 'c-open',
            'tenantId': 't',
            'senderId': 'user-2',
            'type': 'TEXT',
            'content': 'hello',
            'createdAt': DateTime.utc(2026).toIso8601String(),
          }),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(fake.markAsReadLog, isEmpty);

      await controller.setThreadVisible(true);
      expect(fake.markConversationReadLog, ['c-open']);

      fake.emitSocket(
        ChatSocketEvent(
          type: ChatSocketEventType.messageReceived,
          message: ChatMessage.fromJson({
            'id': 'm2',
            'conversationId': 'c-open',
            'tenantId': 't',
            'senderId': 'user-2',
            'type': 'TEXT',
            'content': 'again',
            'createdAt': DateTime.utc(2026, 1, 2).toIso8601String(),
          }),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(fake.markAsReadLog, contains('c-open:m2'));

      await controller.dispose();
      await connection.close();
    });

    test('conversation_message does not double count with message', () async {
      final fake = FakeChatRepository();
      final client = ChatClient(
        config: const ChatServiceConfig(
          apiBaseUrl: 'http://localhost',
          socketUrl: 'http://localhost',
        ),
        repository: fake,
      );
      final connection = StreamController<ChatConnectionState>.broadcast();
      final controller = ChatInboxController(
        client: client,
        currentUserId: 'user-1',
        connectionState: connection.stream,
      );

      final msg = ChatMessage.fromJson({
        'id': 'm-dup',
        'conversationId': 'c3',
        'tenantId': 't',
        'senderId': 'user-2',
        'type': 'TEXT',
        'content': 'hello',
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });

      fake.emitSocket(
        ChatSocketEvent(
          type: ChatSocketEventType.conversationMessage,
          conversationMessage: ConversationMessageEvent.fromJson({
            'conversationId': 'c3',
            'message': {
              'id': 'm-dup',
              'conversationId': 'c3',
              'tenantId': 't',
              'senderId': 'user-2',
              'type': 'TEXT',
              'content': 'hello',
              'createdAt': DateTime.utc(2026).toIso8601String(),
            },
            'unreadCount': 5,
          }),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      fake.emitSocket(
        ChatSocketEvent(
          type: ChatSocketEventType.messageReceived,
          message: msg,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.unreadByConversation.value['c3'], 5);

      await controller.dispose();
      await connection.close();
    });

    test('connected replays join and mark for active conversation', () async {
      final fake = FakeChatRepository();
      final client = ChatClient(
        config: const ChatServiceConfig(
          apiBaseUrl: 'http://localhost',
          socketUrl: 'http://localhost',
        ),
        repository: fake,
      );
      final connection = StreamController<ChatConnectionState>.broadcast();
      final controller = ChatInboxController(
        client: client,
        currentUserId: 'user-1',
        connectionState: connection.stream,
      );

      fake.joinConversationLog.clear();
      fake.markConversationReadLog.clear();

      await controller.setActiveConversation('room-z');
      await controller.setThreadVisible(true);
      expect(fake.joinConversationLog.length, 1);

      fake.joinConversationLog.clear();
      fake.markConversationReadLog.clear();

      connection.add(ChatConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      expect(fake.joinConversationLog, ['room-z']);
      expect(fake.markConversationReadLog, ['room-z']);

      await controller.dispose();
      await connection.close();
    });

    test('seedFromConversations assigns apiRank and preserves live promotions',
        () async {
      final fake = FakeChatRepository();
      final client = ChatClient(
        config: const ChatServiceConfig(
          apiBaseUrl: 'http://localhost',
          socketUrl: 'http://localhost',
        ),
        repository: fake,
      );
      final connection = StreamController<ChatConnectionState>.broadcast();
      final controller = ChatInboxController(
        client: client,
        currentUserId: 'user-1',
        connectionState: connection.stream,
      );

      controller.bumpConversation('a');
      expect(controller.conversationOrder.value.promotedAt.containsKey('a'),
          isTrue);

      controller.seedFromConversations([
        Conversation.fromJson({
          'id': 'x',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
        }),
        Conversation.fromJson({
          'id': 'y',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
        }),
      ]);

      expect(controller.conversationOrder.value.apiRank, {'x': 0, 'y': 1});
      expect(controller.conversationOrder.value.promotedAt, isEmpty);

      controller.bumpConversation('x');
      expect(controller.conversationOrder.value.promotedAt.containsKey('x'),
          isTrue);

      controller.seedFromConversations([
        Conversation.fromJson({
          'id': 'x',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026, 1, 2).toIso8601String(),
          'participants': [],
        }),
      ]);

      expect(controller.conversationOrder.value.apiRank, {'x': 0});
      expect(controller.conversationOrder.value.promotedAt.keys, {'x'});

      await controller.dispose();
      await connection.close();
    });

    test(
        'seedFromConversations derives unread from messageStatus and force-clears active',
        () async {
      final fake = FakeChatRepository();
      final client = ChatClient(
        config: const ChatServiceConfig(
          apiBaseUrl: 'http://localhost',
          socketUrl: 'http://localhost',
        ),
        repository: fake,
      );
      final connection = StreamController<ChatConnectionState>.broadcast();
      final controller = ChatInboxController(
        client: client,
        currentUserId: 'user-1',
        connectionState: connection.stream,
      );

      await controller.setActiveConversation('open');
      fake.markConversationReadLog.clear();

      controller.seedFromConversations([
        Conversation.fromJson({
          'id': 'unread-room',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'latestMessageId': '200',
          'messageStatus': [
            {'userId': 'user-1', 'lastReadMessageId': '180'},
          ],
        }),
        Conversation.fromJson({
          'id': 'open',
          'tenantId': 't',
          'type': 'DIRECT',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
          'participants': [],
          'latestMessageId': '300',
          'messageStatus': [
            {'userId': 'user-1', 'lastReadMessageId': '280'},
          ],
        }),
      ]);

      expect(controller.unreadByConversation.value['unread-room'], 1);
      expect(
          controller.unreadByConversation.value.containsKey('open'), isFalse);

      await controller.dispose();
      await connection.close();
    });

    test('deleted message does not bump conversation', () async {
      final fake = FakeChatRepository();
      final client = ChatClient(
        config: const ChatServiceConfig(
          apiBaseUrl: 'http://localhost',
          socketUrl: 'http://localhost',
        ),
        repository: fake,
      );
      final connection = StreamController<ChatConnectionState>.broadcast();
      final controller = ChatInboxController(
        client: client,
        currentUserId: 'user-1',
        connectionState: connection.stream,
      );

      fake.emitSocket(
        ChatSocketEvent(
          type: ChatSocketEventType.messageReceived,
          message: ChatMessage.fromJson({
            'id': 'm-del',
            'conversationId': 'c-del',
            'tenantId': 't',
            'senderId': 'user-2',
            'type': 'TEXT',
            'content': 'x',
            'deletedAt': DateTime.utc(2026).toIso8601String(),
            'createdAt': DateTime.utc(2026).toIso8601String(),
          }),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.conversationOrder.value.promotedAt['c-del'], isNull);

      await controller.dispose();
      await connection.close();
    });
  });
}
