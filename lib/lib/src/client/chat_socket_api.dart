import 'chat_auth.dart';
import 'chat_repository.dart';
import 'models/chat_message.dart';
import 'socket_client.dart';

class ChatSocketApi {
  ChatSocketApi(this._socketClient);

  final SocketClient _socketClient;

  Stream<ChatSocketEvent> get events async* {
    await for (final socketEvent in _socketClient.events) {
      switch (socketEvent.type) {
        case SocketEventType.connected:
          yield const ChatSocketEvent(type: ChatSocketEventType.connected);
          break;
        case SocketEventType.disconnected:
          yield const ChatSocketEvent(type: ChatSocketEventType.disconnected);
          break;
        case SocketEventType.error:
          final payload = socketEvent.payload;
          final message = payload is Map<String, dynamic>
              ? payload['message']?.toString() ?? 'Socket error'
              : 'Socket error';
          yield ChatSocketEvent(
            type: ChatSocketEventType.error,
            error: message,
          );
          break;
        case SocketEventType.messageReceived:
          yield ChatSocketEvent(
            type: ChatSocketEventType.messageReceived,
            message: ChatMessage.fromJson(_mapPayload(socketEvent.payload)),
          );
          break;
        case SocketEventType.messageReacted:
          yield ChatSocketEvent(
            type: ChatSocketEventType.messageReacted,
            reaction:
                MessageReaction.fromJson(_mapPayload(socketEvent.payload)),
          );
          break;
        case SocketEventType.reactionRemoved:
          yield ChatSocketEvent(
            type: ChatSocketEventType.reactionRemoved,
            removedReaction: RemovedReactionEvent.fromJson(
              _mapPayload(socketEvent.payload),
            ),
          );
          break;
        case SocketEventType.messageDelivered:
          yield ChatSocketEvent(
            type: ChatSocketEventType.messageDelivered,
            delivered:
                DeliveredReceipt.fromJson(_mapPayload(socketEvent.payload)),
          );
          break;
        case SocketEventType.messageRead:
          yield ChatSocketEvent(
            type: ChatSocketEventType.messageRead,
            receipt: ReadReceipt.fromJson(_mapPayload(socketEvent.payload)),
          );
          break;
        case SocketEventType.messageDeleted:
          yield ChatSocketEvent(
            type: ChatSocketEventType.messageDeleted,
            deletedMessage:
                DeletedMessageEvent.fromJson(_mapPayload(socketEvent.payload)),
          );
          break;
        case SocketEventType.messageEdited:
          yield ChatSocketEvent(
            type: ChatSocketEventType.messageEdited,
            editedMessage:
                MessageEditedEvent.fromJson(_mapPayload(socketEvent.payload)),
          );
          break;
        case SocketEventType.conversationCreated:
          yield ChatSocketEvent(
            type: ChatSocketEventType.conversationCreated,
            conversationCreated: ConversationCreatedEvent.fromJson(
              _mapPayload(socketEvent.payload),
            ),
          );
          break;
        case SocketEventType.conversationMessage:
          yield ChatSocketEvent(
            type: ChatSocketEventType.conversationMessage,
            conversationMessage: ConversationMessageEvent.fromJson(
              _mapPayload(socketEvent.payload),
            ),
          );
          break;
        case SocketEventType.unreadCountUpdated:
          yield ChatSocketEvent(
            type: ChatSocketEventType.unreadCountUpdated,
            unreadCountUpdated: UnreadCountUpdatedEvent.fromJson(
              _mapPayload(socketEvent.payload),
            ),
          );
          break;
        case SocketEventType.userBadgeUpdated:
          yield ChatSocketEvent(
            type: ChatSocketEventType.userBadgeUpdated,
            userBadgeUpdated: UserBadgeUpdatedEvent.fromJson(
                _mapPayload(socketEvent.payload)),
          );
          break;
        case SocketEventType.userTyping:
          yield ChatSocketEvent(
            type: ChatSocketEventType.userTyping,
            typing: ChatTypingEvent.fromJson(_mapPayload(socketEvent.payload)),
          );
          break;
        case SocketEventType.userStoppedTyping:
          yield ChatSocketEvent(
            type: ChatSocketEventType.userStoppedTyping,
            typing: ChatTypingEvent.fromJson(_mapPayload(socketEvent.payload)),
          );
          break;
        case SocketEventType.userOnline:
          yield ChatSocketEvent(
            type: ChatSocketEventType.userOnline,
            presence:
                ChatPresenceEvent.fromJson(_mapPayload(socketEvent.payload)),
          );
          break;
        case SocketEventType.userOffline:
          yield ChatSocketEvent(
            type: ChatSocketEventType.userOffline,
            presence:
                ChatPresenceEvent.fromJson(_mapPayload(socketEvent.payload)),
          );
          break;
      }
    }
  }

  Future<void> connect(ChatAuth auth) => _socketClient.connect(auth);

  void disconnect() => _socketClient.disconnect();

  Future<void> joinConversation(String conversationId) {
    return _socketClient.emitWithAck<void>(
      'join_conversation',
      {'conversationId': conversationId},
      (_) {},
    );
  }

  Future<void> leaveConversation(String conversationId) {
    return _socketClient.emitWithAck<void>(
      'leave_conversation',
      {'conversationId': conversationId},
      (_) {},
    );
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required MessageType type,
    required String content,
    String? replyToMessageId,
  }) {
    return _socketClient.emitWithAck<ChatMessage>(
      'send_message',
      {
        'conversationId': conversationId,
        'type': type.apiValue,
        'content': content,
        if (replyToMessageId != null && replyToMessageId.trim().isNotEmpty)
          'replyToMessageId': replyToMessageId,
      },
      (data) => ChatMessage.fromJson(_mapPayload(data)),
    );
  }

  Future<void> startTyping(String conversationId) {
    return _socketClient.emitWithAck<void>(
      'typing_start',
      {'conversationId': conversationId},
      (_) {},
    );
  }

  Future<void> stopTyping(String conversationId) {
    return _socketClient.emitWithAck<void>(
      'typing_stop',
      {'conversationId': conversationId},
      (_) {},
    );
  }

  Future<MessageReaction> reactToMessage({
    required String conversationId,
    required String messageId,
    required String reactionType,
  }) {
    return _socketClient.emitWithAck<MessageReaction>(
      'react_message',
      {
        'conversationId': conversationId,
        'messageId': messageId,
        'reactionType': reactionType,
      },
      (data) => MessageReaction.fromJson(_mapPayload(data)),
    );
  }

  Future<bool> removeReaction({
    required String conversationId,
    required String messageId,
  }) {
    return _socketClient.emitWithAck<bool>(
      'remove_reaction',
      {
        'conversationId': conversationId,
        'messageId': messageId,
      },
      (data) {
        final payload = _mapPayload(data);
        return payload['removed'] == true;
      },
    );
  }

  Future<DeliveredReceipt> markAsDelivered({
    required String conversationId,
    required String messageId,
  }) {
    return _socketClient.emitWithAck<DeliveredReceipt>(
      'message_delivered',
      {
        'conversationId': conversationId,
        'messageId': messageId,
      },
      (data) => DeliveredReceipt.fromJson(_mapPayload(data)),
    );
  }

  Future<ReadReceipt> markAsRead({
    required String conversationId,
    required String messageId,
  }) {
    return _socketClient.emitWithAck<ReadReceipt>(
      'message_read',
      {
        'conversationId': conversationId,
        'messageId': messageId,
      },
      (data) => ReadReceipt.fromJson(_mapPayload(data)),
    );
  }

  Future<MarkConversationReadResult> markConversationRead({
    required String conversationId,
  }) {
    return _socketClient.emitWithAck<MarkConversationReadResult>(
      'mark_conversation_read',
      {'conversationId': conversationId},
      (data) => MarkConversationReadResult.fromJson(_mapPayload(data)),
    );
  }

  Future<DeletedMessageEvent> deleteMessage({
    required String conversationId,
    required String messageId,
  }) {
    return _socketClient.emitWithAck<DeletedMessageEvent>(
      'delete_message',
      {
        'conversationId': conversationId,
        'messageId': messageId,
      },
      (data) => DeletedMessageEvent.fromJson(_mapPayload(data)),
    );
  }

  Future<ChatMessage> editMessage({
    required String conversationId,
    required String messageId,
    required String content,
  }) {
    return _socketClient.emitWithAck<ChatMessage>(
      'edit_message',
      {
        'conversationId': conversationId,
        'messageId': messageId,
        'content': content,
      },
      (data) => ChatMessage.fromJson(_mapPayload(data)),
    );
  }

  Map<String, dynamic> _mapPayload(dynamic payload) {
    return Map<String, dynamic>.from(payload as Map);
  }
}
