import 'messenger_message_attachment.dart';

enum MessengerMessageType { text, image, voice, video, file }

enum MessengerDeliveryStatus { none, sent, delivered, seen }

/// Server-provided snippet for the parent message when this bubble is a reply.
class MessengerQuotedMessage {
  const MessengerQuotedMessage({
    required this.messageId,
    required this.senderLabel,
    required this.preview,
    required this.messageType,
  });

  final String messageId;
  final String senderLabel;
  final String preview;
  final MessengerMessageType messageType;
}

/// Local “replying to …” target before the outgoing message is sent.
class MessengerComposerReplyDraft {
  const MessengerComposerReplyDraft({
    required this.targetMessageId,
    required this.senderLabel,
    required this.preview,
  });

  final String targetMessageId;
  final String senderLabel;
  final String preview;

  factory MessengerComposerReplyDraft.fromMessage(MessengerChatMessage message) {
    return MessengerComposerReplyDraft(
      targetMessageId: message.id,
      senderLabel: message.senderLabel,
      preview: messengerReplyPreviewSnippet(message),
    );
  }
}

/// Short label for media rows in reply chips and conversation previews.
String messengerMediaPreviewLabel(MessengerMessageType type) {
  switch (type) {
    case MessengerMessageType.image:
      return 'Photo';
    case MessengerMessageType.video:
      return 'Video';
    case MessengerMessageType.voice:
      return 'Voice message';
    case MessengerMessageType.file:
      return 'File';
    case MessengerMessageType.text:
      return 'Message';
  }
}

String messengerReplyPreviewSnippet(MessengerChatMessage message) {
  if (message.isDeleted) {
    return 'Message deleted';
  }
  if (message.isUploading) {
    return 'Sending…';
  }
  final caption = message.caption?.trim() ?? '';
  if (caption.isNotEmpty) {
    return messengerTruncatePreview(caption);
  }
  final text = message.content.trim();
  if (message.type == MessengerMessageType.text && text.isNotEmpty) {
    return messengerTruncatePreview(text);
  }
  return messengerMediaPreviewLabel(message.type);
}

String messengerTruncatePreview(String raw, [int max = 80]) {
  final t = raw.trim();
  if (t.length <= max) {
    return t;
  }
  return '${t.substring(0, max > 1 ? max - 1 : 1)}…';
}

class MessengerMessageReaction {
  const MessengerMessageReaction({
    required this.userId,
    required this.reactionType,
  });

  final String userId;
  final String reactionType;
}

class MessengerChatMessage {
  const MessengerChatMessage({
    required this.id,
    required this.senderId,
    required this.senderLabel,
    required this.type,
    required this.content,
    required this.createdAt,
    this.caption,
    this.attachments = const [],
    this.isDeleted = false,
    this.deliveryStatus = MessengerDeliveryStatus.none,
    this.reactions = const [],
    this.isUploading = false,
    this.uploadProgress,
    this.senderAvatarUrl,
    this.quotedReply,
  });

  final String id;
  final String senderId;
  final String senderLabel;
  final MessengerMessageType type;
  final String content;
  /// Optional text shown beneath image, video, file, or voice payloads.
  final String? caption;
  /// When non-empty, drives multi-attachment bubble rendering.
  final List<MessengerMessageAttachment> attachments;
  final DateTime createdAt;
  final bool isDeleted;
  final MessengerDeliveryStatus deliveryStatus;
  final List<MessengerMessageReaction> reactions;
  final bool isUploading;
  final double? uploadProgress;
  final String? senderAvatarUrl;
  final MessengerQuotedMessage? quotedReply;
}
