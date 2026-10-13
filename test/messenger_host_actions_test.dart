import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';
import 'package:health_messenger_ui/lib/health_messenger_client_testing.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  const auth = ChatAuth(apiKey: 'k', chatUserId: 'actor-1', accessToken: 'jwt');

  group('ChatClient.removeParticipant', () {
    test('forwards to repository', () async {
      final fake = FakeChatRepository();
      final client = ChatClient(
        config: const ChatServiceConfig(
          apiBaseUrl: 'https://example.com',
          socketUrl: 'https://example.com',
        ),
        repository: fake,
      );

      await client.removeParticipant(
        auth,
        conversationId: 'c1',
        userId: 'u2',
        actorUserId: 'actor-1',
      );

      expect(fake.removeParticipantCalls, 1);
      expect(fake.lastRemovedParticipantConversationId, 'c1');
      expect(fake.lastRemovedParticipantUserId, 'u2');
      expect(fake.lastRemovedParticipantActorUserId, 'actor-1');
    });
  });

  group('MessengerHostActions', () {
    late FakeChatRepository fake;
    late ChatClient client;
    late MessengerHostActions actions;

    setUp(() {
      fake = FakeChatRepository();
      client = ChatClient(
        config: const ChatServiceConfig(
          apiBaseUrl: 'https://example.com',
          socketUrl: 'https://example.com',
        ),
        repository: fake,
      );
      actions = MessengerHostActions(client: client);
    });

    test('deleteConversation forwards to client', () async {
      await actions.deleteConversation(
        auth,
        conversationId: 'c-del',
        actorUserId: 'actor-1',
      );
      expect(fake.lastDeletedConversationId, 'c-del');
    });

    test('listGroupMembers returns participants for matched conversation',
        () async {
      fake.conversationsToReturn = [
        Conversation.fromJson({
          'id': 'c1',
          'type': 'GROUP',
          'tenantId': 'test-tenant',
          'name': 'Team',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
          'participants': [
            {
              'id': 'part-a',
              'conversationId': 'c1',
              'userId': 'u-a',
              'chatUser': {
                'id': 'u-a',
                'username': 'Alice',
                'role': 'CLIENT',
              },
            },
            {
              'id': 'part-b',
              'conversationId': 'c1',
              'userId': 'u-b',
              'chatUser': {
                'id': 'u-b',
                'username': 'Bob',
                'role': 'CLIENT',
              },
            },
          ],
        }),
      ];

      final members = await actions.listGroupMembers(
        auth,
        conversationId: 'c1',
      );

      expect(members.map((p) => p.userId), ['u-a', 'u-b']);
    });

    test('listGroupMembers throws when conversation is missing', () async {
      fake.conversationsToReturn = const [];
      expect(
        () => actions.listGroupMembers(auth, conversationId: 'missing'),
        throwsA(isA<ChatUnexpectedResponseException>()),
      );
    });

    test('addGroupMember and removeGroupMember forward to client', () async {
      final added = await actions.addGroupMember(
        auth,
        conversationId: 'c1',
        userId: 'u-new',
        actorUserId: 'actor-1',
      );
      expect(added.userId, 'u-new');

      await actions.removeGroupMember(
        auth,
        conversationId: 'c1',
        userId: 'u-old',
        actorUserId: 'actor-1',
      );
      expect(fake.removeParticipantCalls, 1);
      expect(fake.lastRemovedParticipantUserId, 'u-old');
    });

    test('editMessage and deleteMessage forward to client', () async {
      final edited = await actions.editMessage(
        conversationId: 'c1',
        messageId: 'm1',
        content: 'updated',
      );
      expect(edited.id, 'm1');
      expect(edited.content, 'updated');

      final deleted = await actions.deleteMessage(
        auth,
        conversationId: 'c1',
        messageId: 'm1',
        userId: 'actor-1',
      );
      expect(deleted.messageId, 'm1');
      expect(deleted.deleted, isTrue);
    });

    test('pickAttachments and sendAttachments require media orchestrator',
        () async {
      expect(
        () => actions.pickAttachments(MessengerMediaKind.image),
        throwsA(isA<StateError>()),
      );
      expect(
        () => actions.sendAttachments(
          conversationId: 'c1',
          pending: const [],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('pickAttachments and sendAttachments forward to media orchestrator',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('host-actions-media');
      final mediaFile = File('${tempDir.path}/photo.png');
      await mediaFile.writeAsBytes(const <int>[1, 2, 3]);
      addTearDown(() async {
        await tempDir.delete(recursive: true);
      });

      final mediaClient = _FakeMediaClient();
      final orchestrator = MessengerMediaSendOrchestrator(
        client: mediaClient,
        auth: auth,
        senderId: 'actor-1',
        picker: _FakeMediaPicker(
          MessengerPickedMedia(
            file: mediaFile,
            messageType: MessageType.image,
            displayName: 'photo.png',
          ),
        ),
        recorder: _FakeAudioRecorder(),
      );
      final withMedia = MessengerHostActions(
        client: client,
        media: orchestrator,
      );

      final picked = await withMedia.pickAttachments(MessengerMediaKind.image);
      expect(picked, hasLength(1));
      expect(picked.first.displayName, 'photo.png');

      final sent = await withMedia.sendAttachments(
        conversationId: 'c1',
        pending: picked,
        caption: 'hi',
      );
      expect(sent.ok, isTrue);
      expect(sent.sentMessages, hasLength(1));
      expect(mediaClient.sendCallCount, 1);
    });
  });
}

class _FakeMediaPicker implements MessengerMediaPicker {
  const _FakeMediaPicker(this.result);

  final MessengerPickedMedia? result;

  @override
  Future<MessengerPickedMedia?> pick(MessengerMediaKind kind) async => result;

  @override
  Future<List<MessengerPickedMedia>> pickMany(MessengerMediaKind kind) async {
    if (result == null) {
      return const [];
    }
    return [result!];
  }
}

class _FakeAudioRecorder implements MessengerAudioRecorder {
  @override
  bool get isRecording => false;

  @override
  Future<void> start() async {}

  @override
  Future<MessengerRecordedAudio?> stop() async => null;

  @override
  Future<void> cancel() async {}
}

class _FakeMediaClient extends ChatClient {
  _FakeMediaClient()
      : super(
          config: const ChatServiceConfig(
            apiBaseUrl: 'https://example.com',
            socketUrl: 'https://example.com',
          ),
        );

  int sendCallCount = 0;

  @override
  Future<ChatAttachment> uploadFile(
    ChatAuth auth,
    File file, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    onSendProgress?.call(1, 1);
    return const ChatAttachment(
      url: 'https://example.com/uploaded/photo.png',
      fileName: 'photo.png',
      mimeType: 'image/png',
    );
  }

  @override
  Future<List<ChatAttachment>> uploadFiles(
    ChatAuth auth,
    List<File> files, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    return [
      for (final file in files)
        ChatAttachment(
          url: 'https://example.com/uploaded/${file.uri.pathSegments.last}',
          fileName: file.uri.pathSegments.last,
        ),
    ];
  }

  @override
  Future<ChatMessage> sendRestMessage(
    ChatAuth auth, {
    required String conversationId,
    required String senderId,
    required MessageType type,
    String content = '',
    List<ChatAttachment> attachments = const [],
    String? replyToMessageId,
  }) async {
    sendCallCount++;
    return ChatMessage.fromJson({
      'id': 'msg-media-1',
      'conversationId': conversationId,
      'tenantId': 'test-tenant',
      'senderId': senderId,
      'type': type.apiValue,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
    });
  }
}
