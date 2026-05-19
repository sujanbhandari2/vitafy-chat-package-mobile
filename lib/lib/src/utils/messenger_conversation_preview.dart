import '../client/models/chat_message.dart';
import '../models/messenger_message.dart';
import '../models/messenger_message_attachment.dart';
import 'messenger_media_url.dart';

/// Inbox / conversation-list last-message preview for a server [ChatMessage].
///
/// Uses the same media labels as [messengerReplyPreviewSnippet] (Photo, Voice
/// message, File, …) and `Message deleted` for deleted rows.
String messengerConversationPreview(
  ChatMessage message, {
  String? mediaBaseOrigin,
}) {
  if (message.isDeleted || message.content.trim() == '[deleted]') {
    return 'Message deleted';
  }

  final content = message.content.trim();
  if (content.isNotEmpty &&
      !_contentMatchesAttachmentUrl(message, content, mediaBaseOrigin)) {
    return messengerTruncatePreview(content);
  }

  if (message.attachments.isNotEmpty || _isMediaMessageType(message.type)) {
    return messengerMediaPreviewLabel(_previewTypeForMessage(message));
  }

  return messengerMediaPreviewLabel(MessengerMessageType.text);
}

bool _isMediaMessageType(MessageType type) {
  switch (type) {
    case MessageType.image:
    case MessageType.voice:
    case MessageType.video:
    case MessageType.file:
      return true;
    case MessageType.text:
    case MessageType.link:
    case MessageType.other:
      return false;
  }
}

bool _contentMatchesAttachmentUrl(
  ChatMessage message,
  String content,
  String? mediaBaseOrigin,
) {
  for (final attachment in message.attachments) {
    final raw = attachment.url.trim();
    if (raw.isEmpty) {
      continue;
    }
    if (content == raw) {
      return true;
    }
    final absolute = messengerAbsoluteMediaUrl(
      raw,
      baseOrigin: mediaBaseOrigin,
    );
    if (absolute.isNotEmpty && content == absolute) {
      return true;
    }
  }
  return false;
}

MessengerMessageType _previewTypeForMessage(ChatMessage message) {
  switch (message.type) {
    case MessageType.image:
      return MessengerMessageType.image;
    case MessageType.voice:
      return MessengerMessageType.voice;
    case MessageType.video:
      return MessengerMessageType.video;
    case MessageType.file:
      return MessengerMessageType.file;
    case MessageType.text:
    case MessageType.link:
    case MessageType.other:
      break;
  }

  if (message.attachments.isNotEmpty) {
    final attachment = message.attachments.first;
    switch (messengerAttachmentKindFromMimeAndName(
      mimeType: attachment.mimeType,
      fileName: attachment.fileName,
    )) {
      case MessengerMessageAttachmentKind.image:
        return MessengerMessageType.image;
      case MessengerMessageAttachmentKind.video:
        return MessengerMessageType.video;
      case MessengerMessageAttachmentKind.voice:
        return MessengerMessageType.voice;
      case MessengerMessageAttachmentKind.file:
        return MessengerMessageType.file;
    }
  }

  return MessengerMessageType.text;
}
