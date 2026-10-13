import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';

void main() {
  group('ChatUserRegistrationBody.resolve', () {
    test('maps deprecated provider ids to external wire fields', () {
      final body = ChatUserRegistrationBody.resolve(
        providerId: ' tenant-1 ',
        providerUserId: ' u1 ',
        externalUserRole: ' admin ',
        email: ' a@b.com ',
      );
      expect(body.externalTenantId, 'tenant-1');
      expect(body.externalUserId, 'u1');
      expect(body.externalUserRole, 'admin');
      expect(body.email, 'a@b.com');
      final json = body.toRegistrationJson();
      expect(json['externalTenantId'], 'tenant-1');
      expect(json['externalUserId'], 'u1');
      expect(json['externalUserRole'], 'admin');
      expect(json['email'], 'a@b.com');
      expect(json.containsKey('providerId'), isFalse);
    });

    test('lowercases user identifiers and strips tenant environment prefix', () {
      final body = ChatUserRegistrationBody.resolve(
        externalTenantId: ' UAT_7EB541E4-91A9-4DEB-BB7E-55813D3CA140 ',
        externalUserId: ' Surya Bhai Legend ',
        externalUserRole: ' user ',
        email: ' Sujan@Example.COM ',
      );

      expect(body.externalTenantId, '7eb541e4-91a9-4deb-bb7e-55813d3ca140');
      expect(body.externalUserId, 'surya bhai legend');
      expect(body.email, 'sujan@example.com');

      final json = body.toRegistrationJson();
      expect(json['externalTenantId'],
          '7eb541e4-91a9-4deb-bb7e-55813d3ca140');
      expect(json['externalUserId'], 'surya bhai legend');
      expect(json['email'], 'sujan@example.com');
    });

    test('normalizes directly constructed start-conversation user bodies', () {
      const body = ChatUserRegistrationBody(
        externalTenantId: 'DEV_ACME-TENANT',
        externalUserId: 'Peer User',
        externalUserRole: 'user',
        email: 'Peer@Example.COM',
      );

      final json = body.toRegistrationJson();
      expect(json['externalTenantId'], 'acme-tenant');
      expect(json['externalUserId'], 'peer user');
      expect(json['email'], 'peer@example.com');
    });

    test('defaults empty externalUserRole to kChatUserDefaultExternalRole', () {
      final body = ChatUserRegistrationBody.resolve(
        externalTenantId: 't',
        externalUserId: 'u',
        externalUserRole: '',
      );
      expect(body.externalUserRole, kChatUserDefaultExternalRole);
    });

    test('throws when both tenant id sources are missing', () {
      expect(
        () => ChatUserRegistrationBody.resolve(
          externalUserId: 'u',
        ),
        throwsArgumentError,
      );
    });
  });

  group('parseStartConversationResponse', () {
    test('reads conversation at root', () {
      final c = parseStartConversationResponse(<String, dynamic>{
        'conversation': <String, dynamic>{
          'id': '99',
          'type': 'DIRECT',
          'tenantId': 't1',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
          'participants': <dynamic>[],
        },
      });
      expect(c.id, '99');
    });

    test('reads conversation under data', () {
      final c = parseStartConversationResponse(<String, dynamic>{
        'data': <String, dynamic>{
          'conversation': <String, dynamic>{
            'id': '100',
            'type': 'GROUP',
            'tenantId': 't1',
            'name': 'G',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
            'participants': <dynamic>[],
          },
        },
      });
      expect(c.id, '100');
      expect(c.type, 'GROUP');
    });

    test('throws when conversation missing', () {
      expect(
        () => parseStartConversationResponse(<String, dynamic>{}),
        throwsA(isA<ChatUnexpectedResponseException>()),
      );
    });
  });
}
