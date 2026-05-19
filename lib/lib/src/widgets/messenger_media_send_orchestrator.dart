import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../client/chat_auth.dart';
import '../client/chat_client.dart';
import '../client/chat_exceptions.dart';
import '../client/models/chat_message.dart';
import '../utils/messenger_composer_attachments.dart';

enum MessengerMediaKind { image, voice, video, file, camera }

class MessengerPickedMedia {
  const MessengerPickedMedia({
    required this.file,
    required this.messageType,
    required this.displayName,
    this.fromRecorder = false,
  });

  final File file;
  final MessageType messageType;
  final String displayName;

  /// True when the file came from the in-app mic recorder (UI label only).
  final bool fromRecorder;
}

abstract class MessengerMediaPicker {
  Future<MessengerPickedMedia?> pick(MessengerMediaKind kind);

  /// Multi-select for file-picker backed kinds; camera returns 0–1 items.
  Future<List<MessengerPickedMedia>> pickMany(MessengerMediaKind kind);
}

class MessengerRecordedAudio {
  const MessengerRecordedAudio({
    required this.file,
    required this.displayName,
  });

  final File file;
  final String displayName;
}

abstract class MessengerAudioRecorder {
  bool get isRecording;

  Future<void> start();

  Future<MessengerRecordedAudio?> stop();

  Future<void> cancel();
}

class DefaultMessengerMediaPicker implements MessengerMediaPicker {
  DefaultMessengerMediaPicker({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<MessengerPickedMedia?> pick(MessengerMediaKind kind) async {
    final many = await pickMany(kind);
    return many.isEmpty ? null : many.first;
  }

  @override
  Future<List<MessengerPickedMedia>> pickMany(MessengerMediaKind kind) async {
    try {
      switch (kind) {
        case MessengerMediaKind.image:
          return _pickFiles(FileType.image, defaultType: MessageType.image);
        case MessengerMediaKind.voice:
          return _pickFiles(FileType.audio, defaultType: MessageType.voice);
        case MessengerMediaKind.video:
          return _pickFiles(FileType.video, defaultType: MessageType.video);
        case MessengerMediaKind.file:
          return _pickFiles(FileType.any, defaultType: MessageType.file);
        case MessengerMediaKind.camera:
          final picked =
              await _imagePicker.pickImage(source: ImageSource.camera);
          if (picked == null) {
            return const [];
          }
          return [
            MessengerPickedMedia(
              file: File(picked.path),
              messageType: MessageType.image,
              displayName: picked.name,
            ),
          ];
      }
    } on MissingPluginException catch (error) {
      throw MessengerMediaPickerUnavailableException(error.toString());
    } on PlatformException catch (error) {
      if (_isPluginChannelError(error)) {
        throw MessengerMediaPickerUnavailableException(
            error.message ?? error.code);
      }
      rethrow;
    }
  }

  Future<List<MessengerPickedMedia>> _pickFiles(
    FileType type, {
    required MessageType defaultType,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return const [];
    }
    final out = <MessengerPickedMedia>[];
    for (final picked in result.files) {
      final path = picked.path;
      if (path == null || path.trim().isEmpty) {
        continue;
      }
      final fileName = picked.name.isNotEmpty
          ? picked.name
          : File(path).uri.pathSegments.last;
      final inferredType = inferUploadMessageType(
        mimeType: picked.extension != null ? null : null,
        fileName: fileName,
      );
      out.add(
        MessengerPickedMedia(
          file: File(path),
          messageType: inferredType ?? defaultType,
          displayName: fileName,
        ),
      );
    }
    return out;
  }
}

class MessengerMediaSendOrchestrator {
  MessengerMediaSendOrchestrator({
    required ChatClient client,
    required ChatAuth auth,
    required String senderId,
    MessengerMediaPicker? picker,
    MessengerAudioRecorder? recorder,
  })  : _client = client,
        _auth = auth,
        _senderId = senderId,
        _picker = picker ?? DefaultMessengerMediaPicker(),
        _recorder = recorder ?? DefaultMessengerAudioRecorder();

  final ChatClient _client;
  final ChatAuth _auth;
  final String _senderId;
  final MessengerMediaPicker _picker;
  final MessengerAudioRecorder _recorder;

  Future<MessengerPickedMedia?> pickMedia(MessengerMediaKind kind) {
    return _picker.pick(kind);
  }

  Future<List<MessengerPickedMedia>> pickMediaMany(MessengerMediaKind kind) {
    return _picker.pickMany(kind);
  }

  bool get isRecording => _recorder.isRecording;

  Future<void> startVoiceRecording() {
    return _recorder.start();
  }

  Future<MessengerPickedMedia?> finishVoiceRecording() async {
    final recorded = await _recorder.stop();
    if (recorded == null) {
      return null;
    }
    return MessengerPickedMedia(
      file: recorded.file,
      messageType: MessageType.voice,
      displayName: recorded.displayName,
      fromRecorder: true,
    );
  }

  Future<void> cancelVoiceRecording() {
    return _recorder.cancel();
  }

  Future<ChatMessage> uploadAndSend({
    required String conversationId,
    required MessengerPickedMedia media,
    String content = '',
    String? replyToMessageId,
    void Function(double progress)? onUploadProgress,
  }) async {
    final uploaded = await _client.uploadFile(
      _auth,
      media.file,
      onSendProgress: (sent, total) {
        if (total <= 0) {
          onUploadProgress?.call(0);
          return;
        }
        onUploadProgress?.call((sent / total).clamp(0.0, 1.0));
      },
    );
    return _client.sendRestMessage(
      _auth,
      conversationId: conversationId,
      senderId: _senderId,
      type: media.messageType,
      content: content,
      attachments: [uploaded],
      replyToMessageId: replyToMessageId,
    );
  }

  /// Upload and POST pending attachments using web-aligned batching.
  Future<MessengerSendPendingAttachmentsResult> sendPendingAttachments({
    required String conversationId,
    required List<MessengerPickedMedia> pending,
    String caption = '',
    String? replyToMessageId,
    void Function(int sentPendingCount, double progress)? onUploadProgress,
  }) async {
    final batches = buildAttachmentSendBatches(pending, caption);
    final captionText = caption.trim();
    final totalPending = pending.length;
    ChatMessage? lastSentMessage;
    var sentPendingCount = 0;

    for (final batch in batches) {
      final files =
          batch.pendingIndices.map((i) => pending[i].file).toList(growable: false);
      try {
        final uploaded = files.length == 1
            ? [
                await _client.uploadFile(
                  _auth,
                  files.first,
                  onSendProgress: (sent, total) {
                    if (total <= 0) {
                      onUploadProgress?.call(sentPendingCount, 0);
                      return;
                    }
                    onUploadProgress?.call(
                      sentPendingCount,
                      (sent / total).clamp(0.0, 1.0),
                    );
                  },
                ),
              ]
            : await _client.uploadFiles(
                _auth,
                files,
                onSendProgress: (sent, total) {
                  if (total <= 0) {
                    onUploadProgress?.call(sentPendingCount, 0);
                    return;
                  }
                  onUploadProgress?.call(
                    sentPendingCount,
                    (sent / total).clamp(0.0, 1.0),
                  );
                },
              );
        if (uploaded.isEmpty) {
          throw const ChatUnexpectedResponseException(
            message: 'Upload returned no attachments',
          );
        }
        final message = await _client.sendRestMessage(
          _auth,
          conversationId: conversationId,
          senderId: _senderId,
          type: batch.messageType,
          content: batch.includeCaption && captionText.isNotEmpty
              ? captionText
              : '',
          attachments: uploaded,
          replyToMessageId: replyToMessageId,
        );
        lastSentMessage = message;
        sentPendingCount += batch.pendingIndices.length;
        onUploadProgress?.call(sentPendingCount, 1.0);
      } catch (err) {
        final detail = err is Exception ? err.toString() : 'Send failed';
        if (sentPendingCount == 0) {
          return MessengerSendPendingAttachmentsResult.failure(
            sentPendingCount: 0,
            error: detail,
          );
        }
        return MessengerSendPendingAttachmentsResult.failure(
          sentPendingCount: sentPendingCount,
          lastMessage: lastSentMessage,
          error:
              'Sent $sentPendingCount of $totalPending attachments. $detail Try again for the rest.',
        );
      }
    }

    if (lastSentMessage == null) {
      return MessengerSendPendingAttachmentsResult.failure(
        sentPendingCount: 0,
        error: 'No attachments to send',
      );
    }
    return MessengerSendPendingAttachmentsResult.success(
      lastMessage: lastSentMessage,
      sentPendingCount: sentPendingCount,
    );
  }
}

class DefaultMessengerAudioRecorder implements MessengerAudioRecorder {
  DefaultMessengerAudioRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _activePath;
  bool _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start() async {
    if (_recording) {
      return;
    }
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw const MessengerAudioRecordingException(
        'Microphone permission is required to record voice messages.',
      );
    }
    final fileName = 'voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = '${Directory.systemTemp.path}/$fileName';
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _activePath = path;
      _recording = true;
    } catch (error) {
      _activePath = null;
      _recording = false;
      throw MessengerAudioRecordingException(
        'Unable to start recording: $error',
      );
    }
  }

  @override
  Future<MessengerRecordedAudio?> stop() async {
    if (!_recording) {
      return null;
    }
    try {
      final stoppedPath = await _recorder.stop();
      final path = (stoppedPath ?? _activePath ?? '').trim();
      _recording = false;
      _activePath = null;
      if (path.isEmpty) {
        return null;
      }
      return MessengerRecordedAudio(
        file: File(path),
        displayName: path.split(Platform.pathSeparator).last,
      );
    } catch (error) {
      _recording = false;
      _activePath = null;
      throw MessengerAudioRecordingException(
        'Unable to finish recording: $error',
      );
    }
  }

  @override
  Future<void> cancel() async {
    if (!_recording) {
      return;
    }
    final path = _activePath;
    try {
      await _recorder.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (error) {
      throw MessengerAudioRecordingException(
        'Unable to cancel recording: $error',
      );
    } finally {
      _recording = false;
      _activePath = null;
    }
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

bool _isPluginChannelError(PlatformException error) {
  final code = error.code.toLowerCase();
  final message = (error.message ?? '').toLowerCase();
  return code.contains('channel-error') ||
      message.contains('unable to establish connection on channel') ||
      message.contains('missingpluginexception');
}

class MessengerMediaPickerUnavailableException implements Exception {
  const MessengerMediaPickerUnavailableException(this.message);

  final String message;

  @override
  String toString() {
    return 'MessengerMediaPickerUnavailableException($message). '
        'Run a full app restart after plugin changes (not hot reload).';
  }
}

class MessengerAudioRecordingException implements Exception {
  const MessengerAudioRecordingException(this.message);

  final String message;

  @override
  String toString() => 'MessengerAudioRecordingException($message)';
}

MessageType? inferUploadMessageType({
  String? mimeType,
  String? fileName,
}) {
  final mime = (mimeType ?? '').trim().toLowerCase();
  if (mime.startsWith('image/')) {
    return MessageType.image;
  }
  if (mime.startsWith('video/')) {
    return MessageType.video;
  }
  if (mime.startsWith('audio/')) {
    return MessageType.voice;
  }

  final lowerName = (fileName ?? '').trim().toLowerCase();
  if (lowerName.isEmpty) {
    return null;
  }
  if (_matchesAnySuffix(lowerName, const [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif'
  ])) {
    return MessageType.image;
  }
  if (_matchesAnySuffix(
      lowerName, const ['.mp4', '.mov', '.mkv', '.avi', '.webm', '.m4v'])) {
    return MessageType.video;
  }
  if (_matchesAnySuffix(lowerName,
      const ['.mp3', '.wav', '.ogg', '.aac', '.m4a', '.webm', '.amr'])) {
    return MessageType.voice;
  }
  return MessageType.file;
}

bool _matchesAnySuffix(String value, List<String> suffixes) {
  for (final suffix in suffixes) {
    if (value.endsWith(suffix)) {
      return true;
    }
  }
  return false;
}
