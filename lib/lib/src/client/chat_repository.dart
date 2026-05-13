import 'dart:io';

import 'package:dio/dio.dart';

import 'chat_auth.dart';
import 'models/chat_message.dart';
import 'models/chat_user_registration_payload.dart';
import 'models/conversation.dart';
import 'models/tenant_user.dart';

abstract class ChatRepository {
  Future<void> connectSocket(ChatAuth auth);
  void disconnectSocket();

  Stream<ChatSocketEvent> get socketEvents;

  Future<ChatTenantScope> getTenantScope(ChatAuth auth);
  Future<TenantUser> registerOrGetUser(
    ChatAuth auth, {
    String? externalTenantId,
    String? externalUserId,
    String? providerId,
    String? providerUserId,
    String? externalUserRole,
    String? email,
    String? name,
    String? profile,
  });

  /// Batch merge users + create DIRECT (two users, no [groupName]) or GROUP.
  Future<Conversation> startConversation(
    ChatAuth auth, {
    required List<ChatUserRegistrationBody> users,
    String? groupName,
  });
  Future<List<Conversation>> getConversations(
    ChatAuth auth, {
    String? forUserId,
  });
  Future<List<TenantUser>> getUsers(
    ChatAuth auth, {
    int? limit,
    int? page,
  });
  Future<ChatMessagesPage> getMessages(
    ChatAuth auth,
    String conversationId, {
    int page,
    int pageSize,
  });

  Future<Conversation> createConversation(
    ChatAuth auth, {
    String type,
    String? title,
    String? creatorUserId,
    List<String>? participantIds,
  });
  Future<Conversation> updateConversation(
    ChatAuth auth, {
    required String conversationId,
    String? title,
    String? actorUserId,
  });
  Future<ConversationParticipant> addParticipant(
    ChatAuth auth, {
    required String conversationId,
    required String userId,
    String? actorUserId,
  });
  Future<List<ChatAttachment>> uploadFiles(
    ChatAuth auth,
    List<File> files, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  });
  Future<ChatMessage> sendRestMessage(
    ChatAuth auth, {
    required String conversationId,
    required String senderId,
    required MessageType type,
    String content,
    List<ChatAttachment> attachments,
    String? replyToMessageId,
  });

  Future<void> joinConversation(String conversationId);
  Future<void> leaveConversation(String conversationId);
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required MessageType type,
    required String content,
    String? replyToMessageId,
  });
  Future<void> startTyping(String conversationId);
  Future<void> stopTyping(String conversationId);
  Future<MessageReaction> reactToMessage({
    required String conversationId,
    required String messageId,
    required String reactionType,
  });
  Future<bool> removeReaction({
    required String conversationId,
    required String messageId,
  });
  Future<DeliveredReceipt> markAsDelivered({
    required String conversationId,
    required String messageId,
  });
  Future<ReadReceipt> markAsRead({
    required String conversationId,
    required String messageId,
  });
  Future<MarkConversationReadResult> markConversationRead({
    required String conversationId,
  });
  Future<DeleteMessageResult> deleteMessage(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
    required String userId,
  });
  Future<void> deleteConversation(
    ChatAuth auth, {
    required String conversationId,
    String? actorUserId,
  });
  Future<ChatMessage> editMessage({
    required String conversationId,
    required String messageId,
    required String content,
  });

  Future<DeliveredReceipt> markAsDeliveredRest(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
  });

  Future<ReadReceipt> markAsReadRest(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
  });
}

class ChatTenantScope {
  const ChatTenantScope({
    required this.tenantId,
  });

  final String tenantId;

  factory ChatTenantScope.fromJson(Map<String, dynamic> json) {
    return ChatTenantScope(
      tenantId: json['tenantId']?.toString() ?? '',
    );
  }
}

class ChatMessagesPage {
  const ChatMessagesPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<ChatMessage> items;
  final int page;
  final int pageSize;
  final int total;
}

enum ChatSocketEventType {
  connected,
  disconnected,
  error,
  messageReceived,
  messageReacted,
  reactionRemoved,
  messageDelivered,
  messageRead,
  messageDeleted,
  messageEdited,
  conversationCreated,
  conversationMessage,
  unreadCountUpdated,
  userBadgeUpdated,
  userTyping,
  userStoppedTyping,
  userOnline,
  userOffline,
}

class ChatSocketEvent {
  const ChatSocketEvent({
    required this.type,
    this.message,
    this.reaction,
    this.removedReaction,
    this.delivered,
    this.receipt,
    this.deletedMessage,
    this.editedMessage,
    this.conversationCreated,
    this.conversationMessage,
    this.unreadCountUpdated,
    this.userBadgeUpdated,
    this.typing,
    this.presence,
    this.error,
  });

  final ChatSocketEventType type;
  final ChatMessage? message;
  final MessageReaction? reaction;
  final RemovedReactionEvent? removedReaction;
  final DeliveredReceipt? delivered;
  final ReadReceipt? receipt;
  final DeletedMessageEvent? deletedMessage;
  final MessageEditedEvent? editedMessage;
  final ConversationCreatedEvent? conversationCreated;
  final ConversationMessageEvent? conversationMessage;
  final UnreadCountUpdatedEvent? unreadCountUpdated;
  final UserBadgeUpdatedEvent? userBadgeUpdated;
  final ChatTypingEvent? typing;
  final ChatPresenceEvent? presence;
  final String? error;
}

class MarkConversationReadResult {
  const MarkConversationReadResult({
    required this.readCount,
    required this.unread,
  });

  final int readCount;
  final int unread;

  factory MarkConversationReadResult.fromJson(Map<String, dynamic> json) {
    int parseInt(Object? raw) {
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return MarkConversationReadResult(
      readCount: parseInt(json['readCount']),
      unread: parseInt(json['unread']),
    );
  }
}

class MessageEditedEvent {
  const MessageEditedEvent({
    required this.conversationId,
    required this.message,
  });

  final String conversationId;
  final ChatMessage message;

  factory MessageEditedEvent.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message'];
    return MessageEditedEvent(
      conversationId: json['conversationId']?.toString() ??
          json['conversation_id']?.toString() ??
          '',
      message: ChatMessage.fromJson(
        Map<String, dynamic>.from(rawMessage as Map? ?? const {}),
      ),
    );
  }
}

class ConversationCreatedEvent {
  const ConversationCreatedEvent({
    required this.conversation,
    required this.unreadCount,
  });

  final Conversation conversation;
  final int unreadCount;

  factory ConversationCreatedEvent.fromJson(Map<String, dynamic> json) {
    int parseInt(Object? raw) {
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    final rawConversation = json['conversation'];
    return ConversationCreatedEvent(
      conversation: Conversation.fromJson(
        Map<String, dynamic>.from(rawConversation as Map? ?? const {}),
      ),
      unreadCount: parseInt(json['unreadCount']),
    );
  }
}

class ConversationMessageEvent {
  const ConversationMessageEvent({
    required this.conversationId,
    required this.message,
    this.unreadCount,
    this.unread,
  });

  final String conversationId;
  final ChatMessage message;
  final int? unreadCount;
  final int? unread;

  factory ConversationMessageEvent.fromJson(Map<String, dynamic> json) {
    int? parseNullableInt(Object? raw) {
      if (raw == null) {
        return null;
      }
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      return int.tryParse(raw.toString());
    }

    final rawMessage = json['message'];
    return ConversationMessageEvent(
      conversationId: json['conversationId']?.toString() ??
          json['conversation_id']?.toString() ??
          '',
      message: ChatMessage.fromJson(
        Map<String, dynamic>.from(rawMessage as Map? ?? const {}),
      ),
      unreadCount: parseNullableInt(json['unreadCount']),
      unread: parseNullableInt(json['unread']),
    );
  }
}

class UnreadCountUpdatedEvent {
  const UnreadCountUpdatedEvent({
    required this.conversationId,
    required this.userId,
    required this.unread,
  });

  final String conversationId;
  final String userId;
  final int unread;

  factory UnreadCountUpdatedEvent.fromJson(Map<String, dynamic> json) {
    int parseInt(Object? raw) {
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return UnreadCountUpdatedEvent(
      conversationId: json['conversationId']?.toString() ??
          json['conversation_id']?.toString() ??
          '',
      userId: json['userId']?.toString() ??
          json['chatUserId']?.toString() ??
          json['user_id']?.toString() ??
          '',
      unread: parseInt(json['unread']),
    );
  }
}

class UserBadgeUpdatedEvent {
  const UserBadgeUpdatedEvent({
    required this.usersWithUnreadMessages,
    this.userId,
    this.totalMessagesSent,
    this.totalUnreadMessages,
    this.conversationsWithUnreadMessages,
  });

  final int usersWithUnreadMessages;
  final String? userId;
  final int? totalMessagesSent;
  final int? totalUnreadMessages;
  final int? conversationsWithUnreadMessages;

  factory UserBadgeUpdatedEvent.fromJson(Map<String, dynamic> json) {
    int parseInt(Object? raw) {
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    int? parseNullableInt(Object? raw) {
      if (raw == null) {
        return null;
      }
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      return int.tryParse(raw.toString());
    }

    return UserBadgeUpdatedEvent(
      usersWithUnreadMessages: parseInt(json['usersWithUnreadMessages']),
      userId: json['userId']?.toString(),
      totalMessagesSent: parseNullableInt(json['totalMessagesSent']),
      totalUnreadMessages: parseNullableInt(json['totalUnreadMessages']),
      conversationsWithUnreadMessages:
          parseNullableInt(json['conversationsWithUnreadMessages']),
    );
  }
}

class ChatTypingEvent {
  const ChatTypingEvent({
    required this.conversationId,
    required this.userId,
    this.name,
  });

  final String conversationId;
  final String userId;
  final String? name;

  factory ChatTypingEvent.fromJson(Map<String, dynamic> json) {
    return ChatTypingEvent(
      conversationId: json['conversationId']?.toString() ??
          json['conversation_id']?.toString() ??
          '',
      userId: json['userId']?.toString() ??
          json['user_id']?.toString() ??
          json['chatUserId']?.toString() ??
          '',
      name: json['name']?.toString(),
    );
  }
}

class ChatPresenceEvent {
  const ChatPresenceEvent({
    required this.userId,
    required this.tenantId,
    this.name,
  });

  final String userId;
  final String tenantId;
  final String? name;

  factory ChatPresenceEvent.fromJson(Map<String, dynamic> json) {
    return ChatPresenceEvent(
      userId: json['userId']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      name: json['name']?.toString(),
    );
  }
}

class RemovedReactionEvent {
  const RemovedReactionEvent({
    required this.messageId,
    required this.conversationId,
    required this.userId,
  });

  final String messageId;
  final String conversationId;
  final String userId;

  factory RemovedReactionEvent.fromJson(Map<String, dynamic> json) {
    return RemovedReactionEvent(
      messageId: json['messageId']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
    );
  }
}
