import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';
import 'package:health_messenger_ui/lib/health_messenger_client_testing.dart';

void main() {
  test('FakeChatRepository tracks join and connect calls', () async {
    final fake = FakeChatRepository();
    const auth = ChatAuth(apiKey: 'k', chatUserId: 'u');

    await fake.connectSocket(auth);
    expect(fake.connectSocketCalls, 1);

    await fake.joinConversation('c1');
    await fake.joinConversation('c2');
    expect(fake.joinConversationLog, ['c1', 'c2']);

    await fake.leaveConversation('c1');
    expect(fake.leaveConversationLog, ['c1']);

    fake.disconnectSocket();
    expect(fake.disconnectSocketCalls, 1);

    await fake.close();
  });

  test('FakeChatRepository startConversation records users and groupName',
      () async {
    final fake = FakeChatRepository();
    const auth = ChatAuth(apiKey: 'k', chatUserId: '1', accessToken: 'jwt');
    final users = [
      const ChatUserRegistrationBody(
        externalTenantId: 't',
        externalUserId: 'a',
        externalUserRole: 'user',
        email: 'a@b.com',
      ),
      const ChatUserRegistrationBody(
        externalTenantId: 't',
        externalUserId: 'b',
        externalUserRole: 'user',
      ),
    ];
    final conv = await fake.startConversation(
      auth,
      users: users,
      groupName: 'Team',
    );
    expect(fake.startConversationCalls, 1);
    expect(fake.lastStartConversationGroupName, 'Team');
    expect(fake.lastStartConversationUsers?.length, 2);
    expect(conv.id, 'conv-start');
  });
}
