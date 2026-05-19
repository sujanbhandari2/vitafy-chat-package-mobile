import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/chat_auth.dart';
import 'package:health_messenger_ui/lib/src/client/chat_client.dart';
import 'package:health_messenger_ui/lib/src/client/chat_config.dart';
import 'package:health_messenger_ui/lib/src/client/models/chat_message.dart';
import 'package:health_messenger_ui/lib/src/utils/messenger_composer_attachments.dart';
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
    final recorder = _FakeAudioRecorder(
      MessengerRecordedAudio(file: mediaFile, displayName: 'voice.m4a'),
    );
    final client = _FakeMediaClient();
    final orchestrator = MessengerMediaSendOrchestrator(
      client: client,
      auth: const ChatAuth(apiKey: 'key'),
      senderId: 'me',
      picker: picker,
      recorder: recorder,
    );

    final picked = await orchestrator.pickMedia(MessengerMediaKind.image);
    expect(picked, isNotNull);
    final progress = <double>[];
    final sent = await orchestrator.uploadAndSend(
      conversationId: 'c1',
      media: picked!,
      content: 'caption',
      replyToMessageId: 'reply-1',
      onUploadProgress: progress.add,
    );

    expect(sent.id, 'msg-media-1');
    expect(sent.type, MessageType.image);
    expect(client.lastSendConversationId, 'c1');
    expect(client.lastSendType, MessageType.image);
    expect(client.lastSendContent, 'caption');
    expect(client.lastSendReplyToMessageId, 'reply-1');
    expect(progress, containsAllInOrder([0.5, 1.0]));
  });

  test('orchestrator returns null when picker cancels', () async {
    final orchestrator = MessengerMediaSendOrchestrator(
      client: _FakeMediaClient(),
      auth: const ChatAuth(apiKey: 'key'),
      senderId: 'me',
      picker: const _FakeMediaPicker(null),
      recorder: _FakeAudioRecorder(null),
    );

    final picked = await orchestrator.pickMedia(MessengerMediaKind.file);
    expect(picked, isNull);
  });

  test('orchestrator maps recorded audio to voice picked media', () async {
    final tempDir = await Directory.systemTemp.createTemp('media-recording');
    final recordedFile = File('${tempDir.path}/voice.m4a');
    await recordedFile.writeAsBytes(const <int>[10, 20, 30]);
    addTearDown(() async {
      await tempDir.delete(recursive: true);
    });

    final recorder = _FakeAudioRecorder(
      MessengerRecordedAudio(
        file: recordedFile,
        displayName: 'voice.m4a',
      ),
    );
    final orchestrator = MessengerMediaSendOrchestrator(
      client: _FakeMediaClient(),
      auth: const ChatAuth(apiKey: 'key'),
      senderId: 'me',
      picker: const _FakeMediaPicker(null),
      recorder: recorder,
    );

    await orchestrator.startVoiceRecording();
    expect(orchestrator.isRecording, isTrue);

    final recorded = await orchestrator.finishVoiceRecording();
    expect(recorded, isNotNull);
    expect(recorded!.messageType, MessageType.voice);
    expect(recorded.displayName, 'voice.m4a');
    expect(orchestrator.isRecording, isFalse);
  });

  test('inferUploadMessageType uses mime type first', () {
    expect(
      inferUploadMessageType(mimeType: 'image/png', fileName: 'voice.m4a'),
      MessageType.image,
    );
    expect(
      inferUploadMessageType(mimeType: 'video/mp4', fileName: 'photo.jpg'),
      MessageType.video,
    );
    expect(
      inferUploadMessageType(mimeType: 'audio/mpeg', fileName: 'video.mp4'),
      MessageType.voice,
    );
  });

  test('buildAttachmentSendBatches groups consecutive images', () {
    final pending = [
      MessengerPickedMedia(
        file: File('a.jpg'),
        messageType: MessageType.image,
        displayName: 'a.jpg',
      ),
      MessengerPickedMedia(
        file: File('b.jpg'),
        messageType: MessageType.image,
        displayName: 'b.jpg',
      ),
      MessengerPickedMedia(
        file: File('doc.pdf'),
        messageType: MessageType.file,
        displayName: 'doc.pdf',
      ),
    ];
    final batches = buildAttachmentSendBatches(pending, 'hello');
    expect(batches.length, 2);
    expect(batches[0].pendingIndices, [0, 1]);
    expect(batches[0].messageType, MessageType.image);
    expect(batches[0].includeCaption, isFalse);
    expect(batches[1].pendingIndices, [2]);
    expect(batches[1].messageType, MessageType.file);
    expect(batches[1].includeCaption, isTrue);
  });

  test('sendPendingAttachments uploads image run in one message', () async {
    final tempDir = await Directory.systemTemp.createTemp('media-batch');
    final imageA = File('${tempDir.path}/a.png');
    final imageB = File('${tempDir.path}/b.png');
    await imageA.writeAsBytes(const <int>[1]);
    await imageB.writeAsBytes(const <int>[2]);
    addTearDown(() async {
      await tempDir.delete(recursive: true);
    });

    final client = _FakeMediaClient();
    final orchestrator = MessengerMediaSendOrchestrator(
      client: client,
      auth: const ChatAuth(apiKey: 'key'),
      senderId: 'me',
      picker: const _FakeMediaPicker(null),
      recorder: _FakeAudioRecorder(null),
    );

    final result = await orchestrator.sendPendingAttachments(
      conversationId: 'c1',
      pending: [
        MessengerPickedMedia(
          file: imageA,
          messageType: MessageType.image,
          displayName: 'a.png',
        ),
        MessengerPickedMedia(
          file: imageB,
          messageType: MessageType.image,
          displayName: 'b.png',
        ),
      ],
      caption: 'two photos',
    );

    expect(result.ok, isTrue);
    expect(client.uploadFilesCallCount, 1);
    expect(client.sendCallCount, 1);
    expect(client.lastSendType, MessageType.image);
    expect(client.lastSendContent, 'two photos');
    expect(client.lastSendAttachments.length, 2);
  });

  test('sendPendingAttachments retains progress on partial failure', () async {
    final tempDir = await Directory.systemTemp.createTemp('media-partial');
    final image = File('${tempDir.path}/a.png');
    final doc = File('${tempDir.path}/b.pdf');
    await image.writeAsBytes(const <int>[1]);
    await doc.writeAsBytes(const <int>[2]);
    addTearDown(() async {
      await tempDir.delete(recursive: true);
    });

    final client = _PartialFailureMediaClient(failAfterSendCount: 1);
    final orchestrator = MessengerMediaSendOrchestrator(
      client: client,
      auth: const ChatAuth(apiKey: 'key'),
      senderId: 'me',
      picker: const _FakeMediaPicker(null),
      recorder: _FakeAudioRecorder(null),
    );

    final result = await orchestrator.sendPendingAttachments(
      conversationId: 'c1',
      pending: [
        MessengerPickedMedia(
          file: image,
          messageType: MessageType.image,
          displayName: 'a.png',
        ),
        MessengerPickedMedia(
          file: doc,
          messageType: MessageType.file,
          displayName: 'b.pdf',
        ),
      ],
      caption: 'caption',
    );

    expect(result.ok, isFalse);
    expect(result.sentPendingCount, 1);
    expect(result.error, contains('Sent 1 of 2'));
    expect(client.sendCallCount, 2);
  });

  test('inferUploadMessageType falls back to extension', () {
    expect(
      inferUploadMessageType(fileName: 'photo.JPG'),
      MessageType.image,
    );
    expect(
      inferUploadMessageType(fileName: 'clip.webm'),
      MessageType.video,
    );
    expect(
      inferUploadMessageType(fileName: 'recording.m4a'),
      MessageType.voice,
    );
    expect(
      inferUploadMessageType(fileName: 'report.pdf'),
      MessageType.file,
    );
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
  String? lastSendContent;
  String? lastSendReplyToMessageId;
  List<ChatAttachment> lastSendAttachments = const [];
  int uploadFilesCallCount = 0;
  int sendCallCount = 0;

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
  Future<List<ChatAttachment>> uploadFiles(
    ChatAuth auth,
    List<File> files, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    uploadFilesCallCount++;
    return [
      for (var i = 0; i < files.length; i++)
        ChatAttachment(
          url: 'https://example.com/uploaded/${files[i].uri.pathSegments.last}',
          fileName: files[i].uri.pathSegments.last,
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
    lastSendConversationId = conversationId;
    lastSendType = type;
    lastSendContent = content;
    lastSendReplyToMessageId = replyToMessageId;
    lastSendAttachments = attachments;
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

class _PartialFailureMediaClient extends _FakeMediaClient {
  _PartialFailureMediaClient({required this.failAfterSendCount});

  final int failAfterSendCount;

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
    final attempt = sendCallCount + 1;
    if (attempt > failAfterSendCount) {
      sendCallCount = attempt;
      throw Exception('send failed');
    }
    return super.sendRestMessage(
      auth,
      conversationId: conversationId,
      senderId: senderId,
      type: type,
      content: content,
      attachments: attachments,
      replyToMessageId: replyToMessageId,
    );
  }
}

class _FakeAudioRecorder implements MessengerAudioRecorder {
  _FakeAudioRecorder(this.result);

  final MessengerRecordedAudio? result;
  bool _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Future<void> cancel() async {
    _recording = false;
  }

  @override
  Future<void> start() async {
    _recording = true;
  }

  @override
  Future<MessengerRecordedAudio?> stop() async {
    _recording = false;
    return result;
  }
}
