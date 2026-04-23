import 'dart:io';

import 'models/chat_message.dart';
import 'models/conversation.dart';
import 'models/tenant_user.dart';

abstract class ChatRepository {
  Future<void> connectSocket(String token);
  void disconnectSocket();

  Stream<ChatSocketEvent> get socketEvents;

  Future<List<Conversation>> getConversations(String token);
  Future<List<TenantUser>> getUsers(String token);
  Future<List<ChatMessage>> getMessages(
    String token,
    String conversationId, {
    int page,
    int pageSize,
  });

  Future<Conversation> createConversation(
    String token,
    List<String> participantIds,
  );
  Future<String> uploadFile(String token, File file);

  Future<void> joinConversation(String conversationId);
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required MessageType type,
    required String content,
  });
  Future<MessageReaction> reactToMessage({
    required String messageId,
    required String reactionType,
  });
  Future<MessageReaction> removeReaction({
    required String messageId,
    required String reactionType,
  });
  Future<DeletedMessageEvent> deleteMessage(String messageId);
  Future<DeliveredReceipt> markAsDelivered(String messageId);
  Future<ReadReceipt> markAsRead(String messageId);
}

enum ChatSocketEventType {
  connected,
  disconnected,
  error,
  conversationJoined,
  messageReceived,
  messageReacted,
  messageDeleted,
  messageDelivered,
  messageRead,
}

class ChatSocketEvent {
  const ChatSocketEvent({
    required this.type,
    this.conversation,
    this.message,
    this.reaction,
    this.reactions,
    this.deleted,
    this.delivered,
    this.receipt,
    this.error,
  });

  final ChatSocketEventType type;
  final Conversation? conversation;
  final ChatMessage? message;
  final MessageReaction? reaction;
  final List<MessageReaction>? reactions;
  final DeletedMessageEvent? deleted;
  final DeliveredReceipt? delivered;
  final ReadReceipt? receipt;
  final String? error;
}
