import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';

void main() {
  String jwtWithChatUserId(String chatUserId) {
    String enc(String raw) =>
        base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
    return '${enc('{"alg":"none","typ":"JWT"}')}.${enc('{"chatUserId":"$chatUserId"}')}.sig';
  }

  group('Chat client models', () {
    test('ChatAuth: API-key-only headers omit Bearer', () {
      const auth = ChatAuth(
        apiKey: 'access:secret',
        chatUserId: '42',
      );

      final headers = auth.toApiHeaders(includeChatUserBearer: false);
      expect(headers['X-Api-Key'], 'access:secret');
      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('ChatAuth: Bearer and socket token when accessToken set', () {
      const auth = ChatAuth(
        apiKey: 'access:secret',
        chatUserId: '42',
        accessToken: 'jwt.token.here',
      );

      expect(auth.toApiHeaders()['Authorization'], 'Bearer jwt.token.here');
      final handshakeHeaders = auth.toSocketHandshakeHeaders();
      expect(handshakeHeaders['Authorization'], 'Bearer jwt.token.here');
      expect(handshakeHeaders['auth'], 'Bearer jwt.token.here');
      expect(
        auth.toSocketAuth(),
        {
          'apiKey': 'access:secret',
          'xApiKey': 'access:secret',
          'userId': '42',
          'chatUserId': '42',
          'token': 'jwt.token.here',
          'accessToken': 'jwt.token.here',
        },
      );
    });

    test('ChatAuth: strips Bearer prefix from socket auth token only', () {
      const auth = ChatAuth(
        apiKey: 'access:secret',
        chatUserId: '42',
        accessToken: 'Bearer jwt.token.here',
      );

      expect(auth.toApiHeaders()['Authorization'], 'Bearer jwt.token.here');
      expect(
        auth.toSocketAuth(),
        {
          'apiKey': 'access:secret',
          'xApiKey': 'access:secret',
          'userId': '42',
          'chatUserId': '42',
          'token': 'jwt.token.here',
          'accessToken': 'jwt.token.here',
        },
      );
    });

    test('ChatAuth: API-key-only socket connect validation passes', () {
      const auth = ChatAuth(apiKey: 'access:secret');
      expect(auth.validateForSocketConnect, returnsNormally);
    });

    test('ChatAuth: socket connect rejects userId without JWT', () {
      const auth = ChatAuth(
        apiKey: 'access:secret',
        chatUserId: '42',
      );
      expect(
        auth.validateForSocketConnect,
        throwsA(isA<ChatSocketAuthException>()),
      );
    });

    test('ChatAuth: socket connect rejects JWT without userId', () {
      final auth = ChatAuth(
        apiKey: 'access:secret',
        accessToken: jwtWithChatUserId('42'),
      );
      expect(
        auth.validateForSocketConnect,
        throwsA(isA<ChatSocketAuthException>()),
      );
    });

    test('ChatAuth: socket connect rejects mismatched JWT chatUserId', () {
      final auth = ChatAuth(
        apiKey: 'access:secret',
        chatUserId: '42',
        accessToken: jwtWithChatUserId('99'),
      );
      expect(
        auth.validateForSocketConnect,
        throwsA(isA<ChatSocketAuthException>()),
      );
    });

    test('ChatAuth: socket action rejects API-key-only session', () {
      const auth = ChatAuth(apiKey: 'access:secret');
      expect(
        () => auth.validateForSocketAction('join_conversation'),
        throwsA(isA<ChatSocketAuthException>()),
      );
    });

    test('ChatAuth: socket handshake headers omit auth when no JWT', () {
      const auth = ChatAuth(
        apiKey: 'access:secret',
        chatUserId: '42',
      );
      final h = auth.toSocketHandshakeHeaders();
      expect(h['X-Api-Key'], 'access:secret');
      expect(h.containsKey('Authorization'), isFalse);
      expect(h.containsKey('auth'), isFalse);
    });

    test('TenantUser.fromJson reads accessToken from POST /users payload', () {
      final user = TenantUser.fromJson({
        'id': '7',
        'tenantId': '1',
        'name': 'A',
        'email': 'a@b.com',
        'role': 'CLIENT',
        'isOnline': false,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'accessToken': 'tok',
        'tokenType': 'Bearer',
      });
      expect(user.accessToken, 'tok');
      expect(user.tokenType, 'Bearer');
    });

    test('TenantUser.displayName falls back to provider_user_id then id', () {
      final u1 = TenantUser.fromJson({
        'id': '42',
        'tenant_id': '1',
        'name': '',
        'email': '',
        'provider_user_id': 'ext-abc',
        'role': 'CLIENT',
        'is_online': false,
        'created_at': '2026-01-01T00:00:00.000Z',
      });
      expect(u1.displayName, 'ext-abc');

      final u2 = TenantUser.fromJson({
        'id': '99',
        'tenantId': '1',
        'name': '',
        'email': '',
        'role': 'CLIENT',
        'isOnline': false,
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
      expect(u2.displayName, 'User 99');
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

  group('Socket auth guardrails', () {
    test('SocketClient.connect rejects partial auth before network', () async {
      final client = SocketClient(
        socketUrl: 'https://example.com',
        config: const ChatServiceConfig(
          apiBaseUrl: 'https://example.com',
          socketUrl: 'https://example.com',
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.connect(
          const ChatAuth(
            apiKey: 'access:secret',
            chatUserId: '42',
          ),
        ),
        throwsA(isA<ChatSocketAuthException>()),
      );
    });
  });
}
