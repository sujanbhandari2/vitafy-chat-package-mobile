import 'dart:io';

import 'package:dio/dio.dart';

import 'chat_auth.dart';
import 'chat_config.dart';
import 'chat_connection_state.dart';
import 'chat_exceptions.dart';
import 'chat_repository.dart';
import 'chat_service.dart';
import '../push/push_models.dart';
import 'models/chat_message.dart';
import 'models/conversation.dart';
import 'models/tenant_user.dart';

/// High-level SDK wrapper for the chat service.
class ChatClient {
  ChatClient({
    required ChatServiceConfig config,
    Dio? dio,
    ChatRepository? repository,
  }) : _service = ChatService(config: config, dio: dio, repository: repository);

  final ChatService _service;

  ChatRepository get repository => _service.repository;
  ChatServiceConfig get config => _service.config;
  Stream<ChatSocketEvent> get events => repository.socketEvents;
  Stream<ChatConnectionState> get connectionState => _service.connectionState;

  Future<void> connect(ChatAuth auth) => repository.connectSocket(auth);

  void disconnect() => repository.disconnectSocket();

  Future<ChatTenantScope> getTenantScope(ChatAuth auth) {
    return repository.getTenantScope(auth);
  }

  Future<TenantUser> registerOrGetUser(
    ChatAuth auth, {
    required String providerId,
    required String providerUserId,
    required String email,
    String? name,
  }) {
    return repository.registerOrGetUser(
      auth,
      providerId: providerId,
      providerUserId: providerUserId,
      email: email,
      name: name,
    );
  }

  Future<List<Conversation>> getConversations(
    ChatAuth auth, {
    String? forUserId,
  }) {
    return repository.getConversations(auth, forUserId: forUserId);
  }

  Future<List<TenantUser>> getUsers(ChatAuth auth) {
    return repository.getUsers(auth);
  }

  Future<ChatMessagesPage> getMessages(
    ChatAuth auth,
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  }) {
    return repository.getMessages(
      auth,
      conversationId,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Conversation> createConversation(
    ChatAuth auth, {
    String type = 'DIRECT',
    String? creatorUserId,
    List<String>? participantIds,
  }) {
    return repository.createConversation(
      auth,
      type: type,
      creatorUserId: creatorUserId,
      participantIds: participantIds,
    );
  }

  Future<ConversationParticipant> addParticipant(
    ChatAuth auth, {
    required String conversationId,
    required String userId,
    String? actorUserId,
  }) {
    return repository.addParticipant(
      auth,
      conversationId: conversationId,
      userId: userId,
      actorUserId: actorUserId,
    );
  }

  Future<List<ChatAttachment>> uploadFiles(
    ChatAuth auth,
    List<File> files, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) {
    return repository.uploadFiles(
      auth,
      files,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
  }

  Future<ChatAttachment> uploadFile(
    ChatAuth auth,
    File file, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final attachments = await repository.uploadFiles(
      auth,
      [file],
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    if (attachments.isEmpty) {
      throw const ChatUnexpectedResponseException(
        message: 'Upload returned no attachments',
      );
    }
    return attachments.first;
  }

  Future<ChatMessage> sendRestMessage(
    ChatAuth auth, {
    required String conversationId,
    required String senderId,
    required MessageType type,
    String content = '',
    List<ChatAttachment> attachments = const [],
    String? replyToMessageId,
  }) {
    return repository.sendRestMessage(
      auth,
      conversationId: conversationId,
      senderId: senderId,
      type: type,
      content: content,
      attachments: attachments,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<void> joinConversation(String conversationId) {
    return repository.joinConversation(conversationId);
  }

  Future<void> leaveConversation(String conversationId) {
    return repository.leaveConversation(conversationId);
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required MessageType type,
    required String content,
    String? replyToMessageId,
  }) {
    return repository.sendMessage(
      conversationId: conversationId,
      type: type,
      content: content,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<void> startTyping(String conversationId) {
    return repository.startTyping(conversationId);
  }

  Future<void> stopTyping(String conversationId) {
    return repository.stopTyping(conversationId);
  }

  Future<MessageReaction> reactToMessage({
    required String conversationId,
    required String messageId,
    required String reactionType,
  }) {
    return repository.reactToMessage(
      conversationId: conversationId,
      messageId: messageId,
      reactionType: reactionType,
    );
  }

  Future<bool> removeReaction({
    required String conversationId,
    required String messageId,
  }) {
    return repository.removeReaction(
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  Future<DeliveredReceipt> markAsDelivered({
    required String conversationId,
    required String messageId,
  }) {
    return repository.markAsDelivered(
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  Future<ReadReceipt> markAsRead({
    required String conversationId,
    required String messageId,
  }) {
    return repository.markAsRead(
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  Future<MarkConversationReadResult> markConversationRead({
    required String conversationId,
  }) {
    return repository.markConversationRead(
      conversationId: conversationId,
    );
  }

  Future<DeleteMessageResult> deleteMessage(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
    required String userId,
  }) {
    return repository.deleteMessage(
      auth,
      conversationId: conversationId,
      messageId: messageId,
      userId: userId,
    );
  }

  Future<ChatMessage> editMessage({
    required String conversationId,
    required String messageId,
    required String content,
  }) {
    return repository.editMessage(
      conversationId: conversationId,
      messageId: messageId,
      content: content,
    );
  }

  Future<DeliveredReceipt> markAsDeliveredRest(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
  }) {
    return repository.markAsDeliveredRest(
      auth,
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  Future<ReadReceipt> markAsReadRest(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
  }) {
    return repository.markAsReadRest(
      auth,
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  /// Delivered receipt: REST first (when [preference] requests it), then socket fallback.
  Future<DeliveredReceipt> markAsDeliveredPrefer(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
    MessengerDeliveredAckPreference preference =
        MessengerDeliveredAckPreference.restThenSocket,
  }) async {
    if (preference == MessengerDeliveredAckPreference.socketOnly) {
      return repository.markAsDelivered(
        conversationId: conversationId,
        messageId: messageId,
      );
    }
    try {
      return await repository.markAsDeliveredRest(
        auth,
        conversationId: conversationId,
        messageId: messageId,
      );
    } on Object {
      return repository.markAsDelivered(
        conversationId: conversationId,
        messageId: messageId,
      );
    }
  }

  Future<void> dispose() => _service.dispose();
}
