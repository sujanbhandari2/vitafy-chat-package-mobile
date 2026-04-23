import 'dart:io';

import 'chat_api.dart';
import 'chat_repository.dart';
import 'chat_socket_api.dart';
import 'models/chat_message.dart';
import 'models/conversation.dart';
import 'models/tenant_user.dart';

/// Backend + Socket.IO chat repository (no Supabase).
class BackendChatRepositoryImpl implements ChatRepository {
  BackendChatRepositoryImpl(this._chatApi, this._socketApi);

  final ChatApi _chatApi;
  final ChatSocketApi _socketApi;

  @override
  Stream<ChatSocketEvent> get socketEvents => _socketApi.events;

  @override
  Future<void> connectSocket(String token) => _socketApi.connect(token);

  @override
  void disconnectSocket() => _socketApi.disconnect();

  @override
  Future<List<Conversation>> getConversations(String token) async {
    final payload = await _chatApi.getConversations(token);
    return payload.map(_mapConversation).toList();
  }

  @override
  Future<List<TenantUser>> getUsers(String token) async {
    final payload = await _chatApi.getUsers(token);
    return payload.map(TenantUser.fromJson).toList();
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String token,
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final payload = await _chatApi.getMessages(
      token,
      conversationId,
      page: page,
      pageSize: pageSize,
    );
    return payload.map(ChatMessage.fromJson).toList();
  }

  @override
  Future<Conversation> createConversation(
    String token,
    List<String> participantIds,
  ) async {
    if (participantIds.length == 1) {
      final payload = await _chatApi.createDirectConversation(
        token,
        participantIds.first,
      );
      return _mapConversation(payload);
    }

    final payload = await _chatApi.createConversation(token, participantIds);
    return _mapConversation(payload);
  }

  @override
  Future<String> uploadFile(String token, File file) {
    return _chatApi.uploadFile(token, file);
  }

  @override
  Future<void> joinConversation(String conversationId) {
    return _socketApi.joinConversation(conversationId);
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required MessageType type,
    required String content,
  }) {
    return _socketApi.sendMessage(
      conversationId: conversationId,
      type: type,
      content: content,
    );
  }

  @override
  Future<MessageReaction> reactToMessage({
    required String messageId,
    required String reactionType,
  }) {
    return _socketApi.addReaction(messageId: messageId, emoji: reactionType);
  }

  @override
  Future<MessageReaction> removeReaction({
    required String messageId,
    required String reactionType,
  }) {
    return _socketApi.removeReaction(messageId: messageId, emoji: reactionType);
  }

  @override
  Future<DeletedMessageEvent> deleteMessage(String messageId) {
    return _socketApi.deleteMessage(messageId);
  }

  @override
  Future<DeliveredReceipt> markAsDelivered(String messageId) {
    return _socketApi.markAsDelivered(messageId);
  }

  @override
  Future<ReadReceipt> markAsRead(String messageId) {
    return _socketApi.markAsRead(messageId);
  }

  Conversation _mapConversation(Map<String, dynamic> json) {
    final rawParticipants =
        json['participants'] as List<dynamic>? ?? <dynamic>[];

    final participants = rawParticipants
        .map(
          (item) => ConversationParticipant(
            id: (item as Map)['id']?.toString() ?? '',
            userId: item['userId']?.toString() ?? '',
            user: ConversationParticipantUser.fromJson(
              Map<String, dynamic>.from(
                item['user'] as Map? ?? const <String, dynamic>{},
              ),
            ),
          ),
        )
        .toList();

    return Conversation(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      isGlobal: json['type']?.toString() == 'GLOBAL',
      createdAt: DateTime.parse(json['createdAt'] as String),
      participants: participants,
    );
  }
}
