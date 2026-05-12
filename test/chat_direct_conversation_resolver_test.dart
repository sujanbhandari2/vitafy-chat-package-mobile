import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';
import 'package:health_messenger_ui/lib/health_messenger_client_testing.dart';

void main() {
  const auth = ChatAuth(apiKey: 'k');

  test('resolveDirectConversation returns existing direct conversation',
      () async {
    final existing = _directConversation(
      id: 'conv-existing',
      currentUserId: '100',
      peerUserId: '200',
    );
    final fake = _DirectResolverFake(conversations: [existing]);
    final client = ChatClient(
      config: const ChatServiceConfig(
        apiBaseUrl: 'https://example.com',
        socketUrl: 'https://example.com',
      ),
      repository: fake,
    );

    final resolved = await client.resolveDirectConversation(
      auth,
      currentUserId: '100',
      peerUserId: '200',
    );

    expect(resolved.created, isFalse);
    expect(resolved.conversation.id, existing.id);
    expect(fake.createConversationCalls, 0);
  });

  test('resolveDirectConversation creates direct conversation when missing',
      () async {
    final createdConversation = _directConversation(
      id: 'conv-created',
      currentUserId: '100',
      peerUserId: '300',
    );
    final fake = _DirectResolverFake(
      conversations: const [],
      createdConversation: createdConversation,
    );
    final client = ChatClient(
      config: const ChatServiceConfig(
        apiBaseUrl: 'https://example.com',
        socketUrl: 'https://example.com',
      ),
      repository: fake,
    );

    final resolved = await client.resolveDirectConversation(
      auth,
      currentUserId: '100',
      peerUserId: '300',
    );

    expect(resolved.created, isTrue);
    expect(resolved.conversation.id, createdConversation.id);
    expect(fake.createConversationCalls, 1);
    expect(fake.lastCreateParticipantIds, ['100', '300']);
  });
}

class _DirectResolverFake extends FakeChatRepository {
  _DirectResolverFake({
    required this.conversations,
    Conversation? createdConversation,
  }) : _createdConversation = createdConversation ??
            _directConversation(
              id: 'conv-created-default',
              currentUserId: '1',
              peerUserId: '2',
            );

  final List<Conversation> conversations;
  final Conversation _createdConversation;

  int createConversationCalls = 0;
  List<String>? lastCreateParticipantIds;

  @override
  Future<List<Conversation>> getConversations(
    ChatAuth auth, {
    String? forUserId,
  }) async {
    return conversations;
  }

  @override
  Future<Conversation> createConversation(
    ChatAuth auth, {
    String type = 'DIRECT',
    String? creatorUserId,
    List<String>? participantIds,
  }) async {
    createConversationCalls++;
    lastCreateParticipantIds = participantIds;
    return _createdConversation;
  }
}

Conversation _directConversation({
  required String id,
  required String currentUserId,
  required String peerUserId,
}) {
  final now = DateTime.utc(2026, 1, 1).toIso8601String();
  return Conversation.fromJson({
    'id': id,
    'tenantId': 'tenant-1',
    'type': 'DIRECT',
    'createdAt': now,
    'updatedAt': now,
    'participants': [
      {
        'id': 'p-1',
        'conversationId': id,
        'chatUserId': currentUserId,
        'chatUser': {
          'id': currentUserId,
          'username': 'Self User',
          'role': 'CLIENT',
          'email': 'self@example.com',
        },
      },
      {
        'id': 'p-2',
        'conversationId': id,
        'chatUserId': peerUserId,
        'chatUser': {
          'id': peerUserId,
          'username': 'Peer User',
          'role': 'CLIENT',
          'email': 'peer@example.com',
        },
      },
    ],
  });
}
