import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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

class DefaultMessengerMediaPicker implements MessengerMediaPicker {
  DefaultMessengerMediaPicker({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<MessengerPickedMedia?> pick(MessengerMediaKind kind) async {
    try {
      switch (kind) {
        case MessengerMediaKind.image:
          return _pickFile(FileType.image, MessageType.image);
        case MessengerMediaKind.voice:
          return _pickFile(FileType.audio, MessageType.voice);
        case MessengerMediaKind.video:
          return _pickFile(FileType.video, MessageType.video);
        case MessengerMediaKind.file:
          return _pickFile(FileType.any, MessageType.file);
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
        throw MessengerMediaPickerUnavailableException(error.message ?? error.code);
      }
      rethrow;
    }
  }

  Future<MessengerPickedMedia?> _pickFile(
    FileType type,
    MessageType messageType,
  ) async {
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
    return MessengerPickedMedia(
      file: File(path),
      messageType: messageType,
      displayName: picked?.name ?? File(path).uri.pathSegments.last,
    );
  }
}

class MessengerMediaSendOrchestrator {
  MessengerMediaSendOrchestrator({
    required ChatClient client,
    required ChatAuth auth,
    required String senderId,
    MessengerMediaPicker? picker,
  })  : _client = client,
        _auth = auth,
        _senderId = senderId,
        _picker = picker ?? DefaultMessengerMediaPicker();

  final ChatClient _client;
  final ChatAuth _auth;
  final String _senderId;
  final MessengerMediaPicker _picker;

  Future<MessengerPickedMedia?> pickMedia(MessengerMediaKind kind) {
    return _picker.pick(kind);
  }

  Future<ChatMessage> uploadAndSend({
    required String conversationId,
    required MessengerPickedMedia media,
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
      attachments: [uploaded],
    );
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
