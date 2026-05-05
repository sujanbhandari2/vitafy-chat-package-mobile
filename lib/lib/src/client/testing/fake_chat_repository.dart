import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../chat_auth.dart';
import '../chat_repository.dart';
import '../models/app_role.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/tenant_user.dart';

/// In-memory [ChatRepository] for widget tests and host app doubles.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    ChatTenantScope tenantScope =
        const ChatTenantScope(tenantId: 'test-tenant'),
    TenantUser? registeredUser,
  })  : _tenantScope = tenantScope,
        _user = registeredUser ??
            TenantUser(
              id: 'user-1',
              tenantId: tenantScope.tenantId,
              name: 'Test User',
              email: 'test@example.com',
              role: AppRole.client,
              isOnline: false,
              createdAt: DateTime.utc(2026),
              accessToken: 'fake-access-token',
              tokenType: 'Bearer',
            );

  final ChatTenantScope _tenantScope;
  final TenantUser _user;

  final _socketEvents = StreamController<ChatSocketEvent>.broadcast();
  int connectSocketCalls = 0;
  int disconnectSocketCalls = 0;
  final List<String> joinConversationLog = <String>[];
  final List<String> leaveConversationLog = <String>[];
  final List<String> markConversationReadLog = <String>[];
  final List<String> markAsDeliveredLog = <String>[];
  final List<String> markAsReadLog = <String>[];

  @override
  Stream<ChatSocketEvent> get socketEvents => _socketEvents.stream;

  void emitSocket(ChatSocketEvent event) {
    if (!_socketEvents.isClosed) {
      _socketEvents.add(event);
    }
  }

  Future<void> close() async {
    await _socketEvents.close();
  }

  @override
  Future<void> connectSocket(ChatAuth auth) async {
    connectSocketCalls++;
  }

  @override
  void disconnectSocket() {
    disconnectSocketCalls++;
  }

  @override
  Future<ChatTenantScope> getTenantScope(ChatAuth auth) async {
    return _tenantScope;
  }

  @override
  Future<TenantUser> registerOrGetUser(
    ChatAuth auth, {
    required String providerId,
    required String providerUserId,
    required String email,
    String? name,
  }) async {
    return _user;
  }

  @override
  Future<List<Conversation>> getConversations(
    ChatAuth auth, {
    String? forUserId,
  }) async {
    return const [];
  }

  @override
  Future<List<TenantUser>> getUsers(ChatAuth auth) async {
    return const [];
  }

  @override
  Future<ChatMessagesPage> getMessages(
    ChatAuth auth,
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    return const ChatMessagesPage(
      items: [],
      page: 1,
      pageSize: 50,
      total: 0,
    );
  }

  @override
  Future<Conversation> createConversation(
    ChatAuth auth, {
    String type = 'DIRECT',
    String? creatorUserId,
    List<String>? participantIds,
  }) async {
    return Conversation.fromJson({
      'id': 'conv-1',
      'type': type,
      'tenantId': _tenantScope.tenantId,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'participants': <dynamic>[],
    });
  }

  @override
  Future<ConversationParticipant> addParticipant(
    ChatAuth auth, {
    required String conversationId,
    required String userId,
    String? actorUserId,
  }) async {
    return ConversationParticipant.fromJson({
      'id': 'part-1',
      'conversationId': conversationId,
      'userId': userId,
      'chatUser': {
        'id': userId,
        'username': 'user',
        'role': 'CLIENT',
        'email': 'user@example.com',
      },
    });
  }

  @override
  Future<List<ChatAttachment>> uploadFiles(
    ChatAuth auth,
    List<File> files, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    onSendProgress?.call(1, 1);
    return const [];
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
    return ChatMessage.fromJson({
      'id': 'msg-rest',
      'conversationId': conversationId,
      'tenantId': _tenantScope.tenantId,
      'senderId': senderId,
      'type': type.apiValue,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> joinConversation(String conversationId) async {
    joinConversationLog.add(conversationId);
  }

  @override
  Future<void> leaveConversation(String conversationId) async {
    leaveConversationLog.add(conversationId);
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required MessageType type,
    required String content,
    String? replyToMessageId,
  }) async {
    return ChatMessage.fromJson({
      'id': 'msg-socket',
      'conversationId': conversationId,
      'tenantId': _tenantScope.tenantId,
      'senderId': _user.id,
      'type': type.apiValue,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> startTyping(String conversationId) async {}

  @override
  Future<void> stopTyping(String conversationId) async {}

  @override
  Future<MessageReaction> reactToMessage({
    required String conversationId,
    required String messageId,
    required String reactionType,
  }) async {
    return MessageReaction.fromJson({
      'id': 'rx-1',
      'messageId': messageId,
      'userId': _user.id,
      'reactionType': reactionType,
      'conversationId': conversationId,
    });
  }

  @override
  Future<bool> removeReaction({
    required String conversationId,
    required String messageId,
  }) async {
    return true;
  }

  @override
  Future<DeliveredReceipt> markAsDelivered({
    required String conversationId,
    required String messageId,
  }) async {
    markAsDeliveredLog.add('$conversationId:$messageId');
    return DeliveredReceipt.fromJson({
      'id': 'd-1',
      'messageId': messageId,
      'userId': _user.id,
      'deliveredAt': DateTime.now().toIso8601String(),
      'conversationId': conversationId,
    });
  }

  @override
  Future<ReadReceipt> markAsRead({
    required String conversationId,
    required String messageId,
  }) async {
    markAsReadLog.add('$conversationId:$messageId');
    return ReadReceipt.fromJson({
      'id': 'r-1',
      'messageId': messageId,
      'userId': _user.id,
      'readAt': DateTime.now().toIso8601String(),
      'conversationId': conversationId,
    });
  }

  @override
  Future<MarkConversationReadResult> markConversationRead({
    required String conversationId,
  }) async {
    markConversationReadLog.add(conversationId);
    return const MarkConversationReadResult(
      readCount: 0,
      unread: 0,
    );
  }

  @override
  Future<DeletedMessageEvent> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    return DeletedMessageEvent.fromJson({
      'messageId': messageId,
      'conversationId': conversationId,
      'deletedAt': DateTime.now().toIso8601String(),
      'userId': _user.id,
    });
  }

  @override
  Future<ChatMessage> editMessage({
    required String conversationId,
    required String messageId,
    required String content,
  }) async {
    return ChatMessage.fromJson({
      'id': messageId,
      'conversationId': conversationId,
      'tenantId': _tenantScope.tenantId,
      'senderId': _user.id,
      'type': MessageType.text.apiValue,
      'content': content,
      'editedAt': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<DeliveredReceipt> markAsDeliveredRest(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
  }) {
    return markAsDelivered(
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  @override
  Future<ReadReceipt> markAsReadRest(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
  }) {
    return markAsRead(
      conversationId: conversationId,
      messageId: messageId,
    );
  }
}
