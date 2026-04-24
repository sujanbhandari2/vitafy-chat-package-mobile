enum MessageType {
  text,
  image,
  voice,
  video,
  file,
  link,
  other,
}

MessageType parseMessageType(String rawType) {
  switch (rawType.toUpperCase()) {
    case 'IMAGE':
      return MessageType.image;
    case 'VOICE':
      return MessageType.voice;
    case 'VIDEO':
      return MessageType.video;
    case 'FILE':
      return MessageType.file;
    case 'LINK':
      return MessageType.link;
    case 'OTHER':
      return MessageType.other;
    case 'TEXT':
    default:
      return MessageType.text;
  }
}

extension MessageTypeX on MessageType {
  String get apiValue {
    switch (this) {
      case MessageType.text:
        return 'TEXT';
      case MessageType.image:
        return 'IMAGE';
      case MessageType.voice:
        return 'VOICE';
      case MessageType.video:
        return 'VIDEO';
      case MessageType.file:
        return 'FILE';
      case MessageType.link:
        return 'LINK';
      case MessageType.other:
        return 'OTHER';
    }
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.tenantId,
    required this.senderId,
    required this.type,
    required this.content,
    required this.attachments,
    required this.replyToMessageId,
    required this.replyTo,
    required this.translatedMessage,
    required this.transcribedMessage,
    required this.deletedAt,
    required this.createdAt,
    required this.reactions,
    required this.deliveredReceipts,
    required this.readReceipts,
    this.sender,
  });

  final String id;
  final String conversationId;
  final String tenantId;
  final String senderId;
  final MessageType type;
  final String content;
  final List<ChatAttachment> attachments;
  final String? replyToMessageId;
  final ReplyToMessage? replyTo;
  final String? translatedMessage;
  final String? transcribedMessage;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final List<MessageReaction> reactions;
  final List<DeliveredReceipt> deliveredReceipts;
  final List<ReadReceipt> readReceipts;
  final ChatMessageSender? sender;

  bool get isDeleted => deletedAt != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'] as List<dynamic>? ?? <dynamic>[];
    final rawDelivered =
        json['deliveredReceipts'] as List<dynamic>? ?? <dynamic>[];
    final rawReceipts = json['readReceipts'] as List<dynamic>? ?? <dynamic>[];
    final rawAttachments = json['attachments'] as List<dynamic>? ?? <dynamic>[];
    final rawType =
        json['type']?.toString() ?? json['messageType']?.toString() ?? 'TEXT';

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ??
          json['conversation_id']?.toString() ??
          '',
      tenantId:
          json['tenantId']?.toString() ?? json['tenant_id']?.toString() ?? '',
      senderId:
          json['senderId']?.toString() ?? json['sender_id']?.toString() ?? '',
      type: parseMessageType(rawType),
      content: json['content']?.toString() ?? '',
      attachments: rawAttachments
          .map(
            (item) => ChatAttachment.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      replyToMessageId: json['replyToMessageId']?.toString(),
      replyTo: json['replyTo'] is Map
          ? ReplyToMessage.fromJson(
              Map<String, dynamic>.from(json['replyTo'] as Map),
            )
          : null,
      translatedMessage: json['translatedMessage']?.toString(),
      transcribedMessage: json['transcribedMessage']?.toString(),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'].toString()),
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      reactions: rawReactions
          .map(
            (item) => MessageReaction.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      deliveredReceipts: rawDelivered
          .map(
            (item) => DeliveredReceipt.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      readReceipts: rawReceipts
          .map(
            (item) =>
                ReadReceipt.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      sender: json['sender'] is Map
          ? ChatMessageSender.fromJson(
              Map<String, dynamic>.from(json['sender'] as Map),
            )
          : null,
    );
  }

  ChatMessage copyWith({
    String? content,
    List<ChatAttachment>? attachments,
    String? replyToMessageId,
    ReplyToMessage? replyTo,
    String? translatedMessage,
    String? transcribedMessage,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    List<MessageReaction>? reactions,
    List<DeliveredReceipt>? deliveredReceipts,
    List<ReadReceipt>? readReceipts,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      tenantId: tenantId,
      senderId: senderId,
      type: type,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyTo: replyTo ?? this.replyTo,
      translatedMessage: translatedMessage ?? this.translatedMessage,
      transcribedMessage: transcribedMessage ?? this.transcribedMessage,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      createdAt: createdAt,
      reactions: reactions ?? this.reactions,
      deliveredReceipts: deliveredReceipts ?? this.deliveredReceipts,
      readReceipts: readReceipts ?? this.readReceipts,
      sender: sender,
    );
  }
}

class ChatAttachment {
  const ChatAttachment({
    required this.url,
    this.mimeType,
    this.fileName,
    this.byteSize,
    this.kind,
  });

  final String url;
  final String? mimeType;
  final String? fileName;
  final int? byteSize;
  final String? kind;

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    final rawByteSize = json['byteSize'] ?? json['size'];
    return ChatAttachment(
      url: json['url']?.toString() ?? json['fileUrl']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? json['fileType']?.toString(),
      fileName: json['fileName']?.toString(),
      byteSize: rawByteSize is num
          ? rawByteSize.toInt()
          : int.tryParse(rawByteSize?.toString() ?? ''),
      kind: json['kind']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      if (mimeType != null) 'mimeType': mimeType,
      if (fileName != null) 'fileName': fileName,
      if (byteSize != null) 'byteSize': byteSize,
      if (kind != null) 'kind': kind,
    };
  }
}

class ReplyToMessage {
  const ReplyToMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.content,
    required this.createdAt,
    this.sender,
  });

  final String id;
  final String senderId;
  final MessageType type;
  final String content;
  final DateTime createdAt;
  final ChatMessageSender? sender;

  factory ReplyToMessage.fromJson(Map<String, dynamic> json) {
    return ReplyToMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      type: parseMessageType(json['type']?.toString() ?? 'TEXT'),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      sender: json['sender'] is Map
          ? ChatMessageSender.fromJson(
              Map<String, dynamic>.from(json['sender'] as Map),
            )
          : null,
    );
  }
}

class ChatMessageSender {
  const ChatMessageSender({
    required this.id,
    required this.name,
  });

  final String id;
  final String? name;

  factory ChatMessageSender.fromJson(Map<String, dynamic> json) {
    return ChatMessageSender(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
    );
  }
}

class DeliveredReceipt {
  const DeliveredReceipt({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.deliveredAt,
    this.conversationId,
  });

  final String id;
  final String messageId;
  final String userId;
  final DateTime deliveredAt;
  final String? conversationId;

  factory DeliveredReceipt.fromJson(Map<String, dynamic> json) {
    return DeliveredReceipt(
      id: json['id']?.toString() ?? '',
      messageId:
          json['messageId']?.toString() ?? json['message_id']?.toString() ?? '',
      userId: json['userId']?.toString() ??
          json['chatUserId']?.toString() ??
          json['user_id']?.toString() ??
          '',
      deliveredAt: DateTime.parse(
        json['deliveredAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      conversationId: json['conversationId']?.toString() ??
          json['conversation_id']?.toString(),
    );
  }
}

class MessageReaction {
  const MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.reactionType,
    this.conversationId,
  });

  final String id;
  final String messageId;
  final String userId;
  final String reactionType;
  final String? conversationId;

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    final rawReaction =
        json['reactionType']?.toString() ?? json['emoji']?.toString() ?? '👍';
    return MessageReaction(
      id: json['id']?.toString() ?? '',
      messageId:
          json['messageId']?.toString() ?? json['message_id']?.toString() ?? '',
      userId: json['userId']?.toString() ??
          json['chatUserId']?.toString() ??
          json['user_id']?.toString() ??
          '',
      reactionType: rawReaction,
      conversationId: json['conversationId']?.toString() ??
          json['conversation_id']?.toString(),
    );
  }

  MessageReaction copyWith({String? conversationId}) {
    return MessageReaction(
      id: id,
      messageId: messageId,
      userId: userId,
      reactionType: reactionType,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}

class ReadReceipt {
  const ReadReceipt({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.readAt,
    this.conversationId,
  });

  final String id;
  final String messageId;
  final String userId;
  final DateTime readAt;
  final String? conversationId;

  factory ReadReceipt.fromJson(Map<String, dynamic> json) {
    return ReadReceipt(
      id: json['id']?.toString() ?? '',
      messageId:
          json['messageId']?.toString() ?? json['message_id']?.toString() ?? '',
      userId: json['userId']?.toString() ??
          json['chatUserId']?.toString() ??
          json['user_id']?.toString() ??
          '',
      readAt: DateTime.parse(
        json['readAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      conversationId: json['conversationId']?.toString() ??
          json['conversation_id']?.toString(),
    );
  }
}

class DeletedMessageEvent {
  const DeletedMessageEvent({
    required this.messageId,
    required this.conversationId,
    required this.deletedAt,
  });

  final String messageId;
  final String conversationId;
  final DateTime deletedAt;

  factory DeletedMessageEvent.fromJson(Map<String, dynamic> json) {
    return DeletedMessageEvent(
      messageId:
          json['messageId']?.toString() ?? json['message_id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ??
          json['conversation_id']?.toString() ??
          '',
      deletedAt: DateTime.parse(
        json['deletedAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
