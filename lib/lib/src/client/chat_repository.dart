import 'dart:io';

import 'package:dio/dio.dart';

import 'chat_auth.dart';
import 'models/chat_message.dart';
import 'models/conversation.dart';
import 'models/tenant_user.dart';

abstract class ChatRepository {
  Future<void> connectSocket(ChatAuth auth);
  void disconnectSocket();

  Stream<ChatSocketEvent> get socketEvents;

  Future<ChatTenantScope> getTenantScope(ChatAuth auth);
  Future<TenantUser> registerOrGetUser(
    ChatAuth auth, {
    required String providerId,
    required String providerUserId,
    required String email,
    String? name,
  });
  Future<List<Conversation>> getConversations(
    ChatAuth auth, {
    String? forUserId,
  });
  Future<List<TenantUser>> getUsers(ChatAuth auth);
  Future<ChatMessagesPage> getMessages(
    ChatAuth auth,
    String conversationId, {
    int page,
    int pageSize,
  });

  Future<Conversation> createConversation(
    ChatAuth auth, {
    String type,
    String? creatorUserId,
    List<String>? participantIds,
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
  final ChatTypingEvent? typing;
  final ChatPresenceEvent? presence;
  final String? error;
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
