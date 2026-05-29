import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/models/app_role.dart';
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

    test('parses latestReaction from REST list shape', () {
      final reactedAt = DateTime.utc(2026, 5, 4, 12, 10);

      final c = Conversation.fromJson({
        'id': 'a',
        'tenantId': 't',
        'type': 'DIRECT',
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'updatedAt': DateTime.utc(2026).toIso8601String(),
        'participants': <dynamic>[],
        'latestReaction': {
          'id': 'r1',
          'messageId': 'm1',
          'chatUserId': 'u1',
          'reactionType': '😂',
          'userName': 'Sujan Bhandari',
          'createdAt': reactedAt.toIso8601String(),
        },
      });

      expect(c.latestReaction, isNotNull);
      expect(c.latestReaction!.messageId, 'm1');
      expect(c.latestReaction!.chatUserId, 'u1');
      expect(c.latestReaction!.reactionType, '😂');
      expect(c.latestReaction!.userName, 'Sujan Bhandari');
      expect(c.latestReaction!.createdAt, reactedAt);
    });

    test('falls back to name when title is absent', () {
      final c = Conversation.fromJson({
        'id': 'group-1',
        'tenantId': 't',
        'type': 'GROUP',
        'name': 'Care team',
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'updatedAt': DateTime.utc(2026).toIso8601String(),
        'participants': <dynamic>[],
      });

      expect(c.title, 'Care team');
    });

    test('uses participant chatUser.externalUserRole for role mapping', () {
      final c = Conversation.fromJson({
        'id': '253',
        'tenantId': '1',
        'type': 'DIRECT',
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'updatedAt': DateTime.utc(2026).toIso8601String(),
        'participants': [
          {
            'id': '629',
            'conversationId': '253',
            'chatUserId': '213',
            'role': 'MEMBER',
            'chatUser': {
              'id': '213',
              'name': 'Arjun Saud',
              'externalUserRole': 'ADMIN',
            },
          },
        ],
      });

      expect(c.participants, hasLength(1));
      expect(c.participants.first.user.role, AppRole.admin);
    });

    test('uses participant chatUser.profile as avatarUrl', () {
      final c = Conversation.fromJson({
        'id': '254',
        'tenantId': '1',
        'type': 'DIRECT',
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'updatedAt': DateTime.utc(2026).toIso8601String(),
        'participants': [
          {
            'id': '630',
            'conversationId': '254',
            'chatUserId': '228',
            'chatUser': {
              'id': '228',
              'name': 'Sujan Bhandari',
              'externalUserRole': 'ADMIN',
              'profile': 'https://example.com/avatar.png',
            },
          },
        ],
      });

      expect(c.participants, hasLength(1));
      expect(
        c.participants.first.user.avatarUrl,
        'https://example.com/avatar.png',
      );
    });

    test('uses participant chatUser.profilePicture as avatarUrl', () {
      final c = Conversation.fromJson({
        'id': '255',
        'tenantId': '1',
        'type': 'DIRECT',
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'updatedAt': DateTime.utc(2026).toIso8601String(),
        'participants': [
          {
            'id': '631',
            'conversationId': '255',
            'chatUserId': '229',
            'chatUser': {
              'id': '229',
              'name': 'Profile Picture User',
              'profilePicture': 'https://example.com/profile-picture.png',
            },
          },
        ],
      });

      expect(c.participants, hasLength(1));
      expect(
        c.participants.first.user.avatarUrl,
        'https://example.com/profile-picture.png',
      );
    });
  });
}
