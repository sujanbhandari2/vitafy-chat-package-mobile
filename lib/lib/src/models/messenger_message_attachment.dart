import '../client/models/chat_message.dart';
import '../utils/messenger_media_url.dart';
import 'messenger_message.dart';

/// UI attachment payload for a chat message bubble.
class MessengerMessageAttachment {
  const MessengerMessageAttachment({
    required this.url,
    this.fileName,
    this.mimeType,
    required this.kind,
  });

  final String url;
  final String? fileName;
  final String? mimeType;
  final MessengerMessageAttachmentKind kind;
}

enum MessengerMessageAttachmentKind { image, video, voice, file }

MessengerMessageAttachmentKind messengerAttachmentKindFromMessageType(
  MessengerMessageType type,
) {
  switch (type) {
    case MessengerMessageType.image:
      return MessengerMessageAttachmentKind.image;
    case MessengerMessageType.video:
      return MessengerMessageAttachmentKind.video;
    case MessengerMessageType.voice:
      return MessengerMessageAttachmentKind.voice;
    case MessengerMessageType.file:
      return MessengerMessageAttachmentKind.file;
    case MessengerMessageType.text:
      return MessengerMessageAttachmentKind.file;
  }
}

MessengerMessageAttachmentKind messengerAttachmentKindFromMimeAndName({
  String? mimeType,
  String? fileName,
  MessengerMessageType? fallbackType,
}) {
  final mime = (mimeType ?? '').trim().toLowerCase();
  if (mime.startsWith('image/')) {
    return MessengerMessageAttachmentKind.image;
  }
  if (mime.startsWith('video/')) {
    return MessengerMessageAttachmentKind.video;
  }
  if (mime.startsWith('audio/')) {
    return MessengerMessageAttachmentKind.voice;
  }
  final lowerName = (fileName ?? '').trim().toLowerCase();
  if (RegExp(r'\.(jpe?g|png|gif|webp|bmp|heic|heif|avif)$')
      .hasMatch(lowerName)) {
    return MessengerMessageAttachmentKind.image;
  }
  if (RegExp(r'\.(mp4|mov|mkv|avi|webm|m4v)$').hasMatch(lowerName)) {
    return MessengerMessageAttachmentKind.video;
  }
  if (RegExp(r'\.(mp3|wav|ogg|aac|m4a|amr)$').hasMatch(lowerName)) {
    return MessengerMessageAttachmentKind.voice;
  }
  if (fallbackType != null) {
    return messengerAttachmentKindFromMessageType(fallbackType);
  }
  return MessengerMessageAttachmentKind.file;
}

/// Maps all server attachments on a [ChatMessage] for bubble rendering.
List<MessengerMessageAttachment> messengerAttachmentsFromChatMessage(
  ChatMessage message, {
  required MessengerMessageType fallbackType,
  String? mediaBaseOrigin,
}) {
  return message.attachments
      .map((att) {
        final url = messengerAbsoluteMediaUrl(
          att.url,
          baseOrigin: mediaBaseOrigin,
        );
        if (url.isEmpty) {
          return null;
        }
        return MessengerMessageAttachment(
          url: url,
          fileName: att.fileName,
          mimeType: att.mimeType,
          kind: messengerAttachmentKindFromMimeAndName(
            mimeType: att.mimeType,
            fileName: att.fileName,
            fallbackType: fallbackType,
          ),
        );
      })
      .whereType<MessengerMessageAttachment>()
      .toList(growable: false);
}
