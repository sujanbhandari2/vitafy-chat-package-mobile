import 'dart:io';

import 'package:dio/dio.dart';

import 'chat_api.dart';
import 'chat_auth.dart';
import 'chat_repository.dart';
import 'chat_socket_api.dart';
import 'models/chat_message.dart';
import 'models/conversation.dart';
import 'models/tenant_user.dart';

/// Backend + Socket.IO chat repository for the Vitafy-style API contract.
class BackendChatRepositoryImpl implements ChatRepository {
  BackendChatRepositoryImpl(this._chatApi, this._socketApi);

  final ChatApi _chatApi;
  final ChatSocketApi _socketApi;

  @override
  Stream<ChatSocketEvent> get socketEvents => _socketApi.events;

  @override
  Future<void> connectSocket(ChatAuth auth) => _socketApi.connect(auth);

  @override
  void disconnectSocket() => _socketApi.disconnect();

  @override
  Future<ChatTenantScope> getTenantScope(ChatAuth auth) async {
    final payload = await _chatApi.getTenantScope(auth);
    return ChatTenantScope.fromJson(payload);
  }

  @override
  Future<TenantUser> registerOrGetUser(
    ChatAuth auth, {
    required String providerId,
    required String providerUserId,
    required String email,
    String? name,
  }) async {
    final payload = await _chatApi.registerOrGetUser(
      auth,
      providerId: providerId,
      providerUserId: providerUserId,
      email: email,
      name: name,
    );
    return TenantUser.fromJson(payload);
  }

  @override
  Future<List<Conversation>> getConversations(
    ChatAuth auth, {
    String? forUserId,
  }) async {
    final payload = await _chatApi.getConversations(auth, forUserId: forUserId);
    return payload.map(Conversation.fromJson).toList();
  }

  @override
  Future<List<TenantUser>> getUsers(ChatAuth auth) async {
    final payload = await _chatApi.getUsers(auth);
    return payload.map(TenantUser.fromJson).toList();
  }

  @override
  Future<ChatMessagesPage> getMessages(
    ChatAuth auth,
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final payload = await _chatApi.getMessagesPage(
      auth,
      conversationId,
      page: page,
      pageSize: pageSize,
    );

    final rawItems = payload['items'] as List<dynamic>? ?? <dynamic>[];
    return ChatMessagesPage(
      items: rawItems
          .map(
            (item) => ChatMessage.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      page: payload['page'] as int? ?? page,
      pageSize: payload['pageSize'] as int? ?? pageSize,
      total: payload['total'] as int? ?? rawItems.length,
    );
  }

  @override
  Future<Conversation> createConversation(
    ChatAuth auth, {
    String type = 'DIRECT',
    String? creatorUserId,
    List<String>? participantIds,
  }) async {
    final payload = await _chatApi.createConversation(
      auth,
      type: type,
      creatorUserId: creatorUserId,
      participantIds: participantIds,
    );
    return Conversation.fromJson(payload);
  }

  @override
  Future<ConversationParticipant> addParticipant(
    ChatAuth auth, {
    required String conversationId,
    required String userId,
    String? actorUserId,
  }) async {
    final payload = await _chatApi.addParticipant(
      auth,
      conversationId: conversationId,
      userId: userId,
      actorUserId: actorUserId,
    );
    return ConversationParticipant.fromJson(payload);
  }

  @override
  Future<List<ChatAttachment>> uploadFiles(
    ChatAuth auth,
    List<File> files, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) {
    return _chatApi.uploadFiles(
      auth,
      files,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<ChatMessage> sendRestMessage(
    ChatAuth auth, {
    required String conversationId,
    required String senderId,
    required MessageType type,
    String content = '',
    List<ChatAttachment> attachments = const [],
    String? replyToMessageId,
  }) async {
    final payload = await _chatApi.postMessage(
      auth,
      conversationId: conversationId,
      senderId: senderId,
      type: type,
      content: content,
      attachments: attachments,
      replyToMessageId: replyToMessageId,
    );
    return ChatMessage.fromJson(payload);
  }

  @override
  Future<void> joinConversation(String conversationId) {
    return _socketApi.joinConversation(conversationId);
  }

  @override
  Future<void> leaveConversation(String conversationId) {
    return _socketApi.leaveConversation(conversationId);
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required MessageType type,
    required String content,
    String? replyToMessageId,
  }) {
    return _socketApi.sendMessage(
      conversationId: conversationId,
      type: type,
      content: content,
      replyToMessageId: replyToMessageId,
    );
  }

  @override
  Future<void> startTyping(String conversationId) {
    return _socketApi.startTyping(conversationId);
  }

  @override
  Future<void> stopTyping(String conversationId) {
    return _socketApi.stopTyping(conversationId);
  }

  @override
  Future<MessageReaction> reactToMessage({
    required String conversationId,
    required String messageId,
    required String reactionType,
  }) {
    return _socketApi.reactToMessage(
      conversationId: conversationId,
      messageId: messageId,
      reactionType: reactionType,
    );
  }

  @override
  Future<bool> removeReaction({
    required String conversationId,
    required String messageId,
  }) {
    return _socketApi.removeReaction(
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  @override
  Future<DeliveredReceipt> markAsDelivered({
    required String conversationId,
    required String messageId,
  }) {
    return _socketApi.markAsDelivered(
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  @override
  Future<ReadReceipt> markAsRead({
    required String conversationId,
    required String messageId,
  }) {
    return _socketApi.markAsRead(
      conversationId: conversationId,
      messageId: messageId,
    );
  }
}
