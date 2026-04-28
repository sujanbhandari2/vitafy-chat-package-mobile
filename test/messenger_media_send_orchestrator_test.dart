import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/chat_auth.dart';
import 'package:health_messenger_ui/lib/src/client/chat_client.dart';
import 'package:health_messenger_ui/lib/src/client/chat_config.dart';
import 'package:health_messenger_ui/lib/src/client/models/chat_message.dart';
import 'package:health_messenger_ui/lib/src/widgets/messenger_media_send_orchestrator.dart';

void main() {
  test('orchestrator picks media and sends uploaded attachment', () async {
    final tempDir = await Directory.systemTemp.createTemp('media-orchestrator');
    final mediaFile = File('${tempDir.path}/image.png');
    await mediaFile.writeAsBytes(const <int>[1, 2, 3, 4]);
    addTearDown(() async {
      await tempDir.delete(recursive: true);
    });

    final picker = _FakeMediaPicker(
      MessengerPickedMedia(
        file: mediaFile,
        messageType: MessageType.image,
        displayName: 'image.png',
      ),
    );
    final client = _FakeMediaClient();
    final orchestrator = MessengerMediaSendOrchestrator(
      client: client,
      auth: const ChatAuth(apiKey: 'key'),
      senderId: 'me',
      picker: picker,
    );

    final picked = await orchestrator.pickMedia(MessengerMediaKind.image);
    expect(picked, isNotNull);
    final progress = <double>[];
    final sent = await orchestrator.uploadAndSend(
      conversationId: 'c1',
      media: picked!,
      onUploadProgress: progress.add,
    );

    expect(sent.id, 'msg-media-1');
    expect(sent.type, MessageType.image);
    expect(client.lastSendConversationId, 'c1');
    expect(client.lastSendType, MessageType.image);
    expect(progress, containsAllInOrder([0.5, 1.0]));
  });

  test('orchestrator returns null when picker cancels', () async {
    final orchestrator = MessengerMediaSendOrchestrator(
      client: _FakeMediaClient(),
      auth: const ChatAuth(apiKey: 'key'),
      senderId: 'me',
      picker: const _FakeMediaPicker(null),
    );

    final picked = await orchestrator.pickMedia(MessengerMediaKind.file);
    expect(picked, isNull);
  });
}

class _FakeMediaPicker implements MessengerMediaPicker {
  const _FakeMediaPicker(this.result);

  final MessengerPickedMedia? result;

  @override
  Future<MessengerPickedMedia?> pick(MessengerMediaKind kind) async => result;
}

class _FakeMediaClient extends ChatClient {
  _FakeMediaClient()
      : super(
          config: const ChatServiceConfig(
            apiBaseUrl: 'https://example.com',
            socketUrl: 'https://example.com',
          ),
        );

  String? lastSendConversationId;
  MessageType? lastSendType;

  @override
  Future<ChatAttachment> uploadFile(
    ChatAuth auth,
    File file, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    onSendProgress?.call(1, 2);
    onSendProgress?.call(2, 2);
    return const ChatAttachment(
      url: 'https://example.com/uploaded/image.png',
      fileName: 'image.png',
      mimeType: 'image/png',
    );
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
    lastSendConversationId = conversationId;
    lastSendType = type;
    return ChatMessage.fromJson({
      'id': 'msg-media-1',
      'conversationId': conversationId,
      'tenantId': 'tenant',
      'senderId': senderId,
      'type': type.apiValue,
      'content': content,
      'attachments': attachments.map((item) => item.toJson()).toList(),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
