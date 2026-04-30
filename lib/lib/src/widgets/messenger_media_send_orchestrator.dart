import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../client/chat_auth.dart';
import '../client/chat_client.dart';
import '../client/models/chat_message.dart';

enum MessengerMediaKind { image, voice, video, file, camera }

class MessengerPickedMedia {
  const MessengerPickedMedia({
    required this.file,
    required this.messageType,
    required this.displayName,
  });

  final File file;
  final MessageType messageType;
  final String displayName;
}

abstract class MessengerMediaPicker {
  Future<MessengerPickedMedia?> pick(MessengerMediaKind kind);
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
    try {
      switch (kind) {
        case MessengerMediaKind.image:
          return _pickFile(FileType.image, defaultType: MessageType.image);
        case MessengerMediaKind.voice:
          return _pickFile(FileType.audio, defaultType: MessageType.voice);
        case MessengerMediaKind.video:
          return _pickFile(FileType.video, defaultType: MessageType.video);
        case MessengerMediaKind.file:
          return _pickFile(FileType.any, defaultType: MessageType.file);
        case MessengerMediaKind.camera:
          final picked =
              await _imagePicker.pickImage(source: ImageSource.camera);
          if (picked == null) {
            return null;
          }
          return MessengerPickedMedia(
            file: File(picked.path),
            messageType: MessageType.image,
            displayName: picked.name,
          );
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

  Future<MessengerPickedMedia?> _pickFile(
    FileType type, {
    required MessageType defaultType,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowMultiple: false,
      withData: false,
    );
    final picked = result?.files.firstOrNull;
    final path = picked?.path;
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    final fileName = picked?.name ?? File(path).uri.pathSegments.last;
    final inferredType = inferUploadMessageType(
      fileName: fileName,
    );
    return MessengerPickedMedia(
      file: File(path),
      messageType: inferredType ?? defaultType,
      displayName: fileName,
    );
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
