import 'dart:io';

import 'package:dio/dio.dart';

import 'chat_config.dart';
import 'chat_service.dart';
import 'chat_repository.dart';
import 'models/chat_message.dart';
import 'models/conversation.dart';
import 'models/tenant_user.dart';

/// High-level SDK-style wrapper for the chat service.
class ChatClient {
  ChatClient({
    required ChatServiceConfig config,
    Dio? dio,
  }) : _service = ChatService(config: config, dio: dio);

  final ChatService _service;

  ChatRepository get repository => _service.repository;
  ChatServiceConfig get config => _service.config;
  Stream<ChatSocketEvent> get events => repository.socketEvents;

  Future<void> connect(String token) => repository.connectSocket(token);

  void disconnect() => repository.disconnectSocket();

  Future<List<Conversation>> getConversations(String token) {
    return repository.getConversations(token);
  }

  Future<List<TenantUser>> getUsers(String token) {
    return repository.getUsers(token);
  }

  Future<List<ChatMessage>> getMessages(
    String token,
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  }) {
    return repository.getMessages(
      token,
      conversationId,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Conversation> createConversation(
    String token,
    List<String> participantIds,
  ) {
    return repository.createConversation(token, participantIds);
  }

  Future<String> uploadFile(String token, File file) {
    return repository.uploadFile(token, file);
  }

  Future<void> joinConversation(String conversationId) {
    return repository.joinConversation(conversationId);
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required MessageType type,
    required String content,
  }) {
    return repository.sendMessage(
      conversationId: conversationId,
      type: type,
      content: content,
    );
  }

  Future<MessageReaction> reactToMessage({
    required String messageId,
    required String reactionType,
  }) {
    return repository.reactToMessage(
      messageId: messageId,
      reactionType: reactionType,
    );
  }

  Future<MessageReaction> removeReaction({
    required String messageId,
    required String reactionType,
  }) {
    return repository.removeReaction(
      messageId: messageId,
      reactionType: reactionType,
    );
  }

  Future<DeletedMessageEvent> deleteMessage(String messageId) {
    return repository.deleteMessage(messageId);
  }

  Future<DeliveredReceipt> markAsDelivered(String messageId) {
    return repository.markAsDelivered(messageId);
  }

  Future<ReadReceipt> markAsRead(String messageId) {
    return repository.markAsRead(messageId);
  }

  Future<void> dispose() => _service.dispose();
}
