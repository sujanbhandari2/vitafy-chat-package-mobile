enum MessengerMessageType { text, image, voice, video, file }

enum MessengerDeliveryStatus { none, sent, delivered, seen }

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
    this.isDeleted = false,
    this.deliveryStatus = MessengerDeliveryStatus.none,
    this.reactions = const [],
    this.isUploading = false,
    this.uploadProgress,
    this.senderAvatarUrl,
  });

  final String id;
  final String senderId;
  final String senderLabel;
  final MessengerMessageType type;
  final String content;
  final DateTime createdAt;
  final bool isDeleted;
  final MessengerDeliveryStatus deliveryStatus;
  final List<MessengerMessageReaction> reactions;
  final bool isUploading;
  final double? uploadProgress;
  final String? senderAvatarUrl;
}
