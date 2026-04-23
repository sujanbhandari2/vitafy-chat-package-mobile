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
          final payload = Map<String, dynamic>.from(socketEvent.payload as Map);
          yield ChatSocketEvent(
            type: ChatSocketEventType.messageReceived,
            message: ChatMessage.fromJson(payload),
          );
          break;
        case SocketEventType.messageReacted:
          final payload = Map<String, dynamic>.from(socketEvent.payload as Map);
          if (payload['reactions'] is List) {
            final reactions = (payload['reactions'] as List)
                .map(
                  (item) =>
                      MessageReaction.fromJson(
                        Map<String, dynamic>.from(item as Map),
                      ).copyWith(
                        conversationId: payload['conversationId']?.toString(),
                      ),
                )
                .toList();
            yield ChatSocketEvent(
              type: ChatSocketEventType.messageReacted,
              reactions: reactions,
            );
          } else {
            yield ChatSocketEvent(
              type: ChatSocketEventType.messageReacted,
              reaction: MessageReaction.fromJson(payload),
            );
          }
          break;
        case SocketEventType.messageDeleted:
          final payload = Map<String, dynamic>.from(socketEvent.payload as Map);
          yield ChatSocketEvent(
            type: ChatSocketEventType.messageDeleted,
            deleted: DeletedMessageEvent.fromJson(payload),
          );
          break;
        case SocketEventType.messageDelivered:
          final payload = Map<String, dynamic>.from(socketEvent.payload as Map);
          yield ChatSocketEvent(
            type: ChatSocketEventType.messageDelivered,
            delivered: DeliveredReceipt.fromJson(payload),
          );
          break;
        case SocketEventType.messageRead:
          final payload = Map<String, dynamic>.from(socketEvent.payload as Map);
          yield ChatSocketEvent(
            type: ChatSocketEventType.messageRead,
            receipt: ReadReceipt.fromJson(payload),
          );
          break;
      }
    }
  }

  Future<void> connect(String token) => _socketClient.connect(token);

  void disconnect() => _socketClient.disconnect();

  Future<void> joinConversation(String conversationId) {
    return _socketClient.emitWithAck<void>('join_conversation', {
      'conversationId': conversationId,
    }, (_) {});
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required MessageType type,
    required String content,
  }) {
    return _socketClient.emitWithAck<ChatMessage>(
      'send_message',
      {
        'conversationId': conversationId,
        'type': type.apiValue,
        'content': content,
      },
      (data) => ChatMessage.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<MessageReaction> reactToMessage({
    required String messageId,
    required String reactionType,
  }) {
    return addReaction(messageId: messageId, emoji: reactionType);
  }

  Future<MessageReaction> addReaction({
    required String messageId,
    required String emoji,
  }) {
    return _socketClient.emitWithAck<MessageReaction>(
      'add_reaction',
      {'messageId': messageId, 'emoji': emoji},
      (data) => _mapReactionAckData(data, messageId, emoji),
    );
  }

  Future<MessageReaction> removeReaction({
    required String messageId,
    required String emoji,
  }) {
    return _socketClient.emitWithAck<MessageReaction>(
      'remove_reaction',
      {'messageId': messageId, 'emoji': emoji},
      (data) => _mapReactionAckData(data, messageId, emoji),
    );
  }

  MessageReaction _mapReactionAckData(
    dynamic data,
    String messageId,
    String emoji,
  ) {
    final payload = Map<String, dynamic>.from(data as Map);
    if (payload['reactions'] is List) {
      final list = payload['reactions'] as List;
      if (list.isNotEmpty) {
        return MessageReaction.fromJson(
          Map<String, dynamic>.from(list.first as Map),
        ).copyWith(conversationId: payload['conversationId']?.toString());
      }
    }
    if (payload['reactionType'] != null || payload['emoji'] != null) {
      return MessageReaction.fromJson(payload);
    }
    return MessageReaction(
      id: '',
      messageId: payload['messageId']?.toString() ?? messageId,
      userId: '',
      reactionType: emoji,
      conversationId: payload['conversationId']?.toString(),
    );
  }

  Future<DeletedMessageEvent> deleteMessage(String messageId) {
    return _socketClient.emitWithAck<DeletedMessageEvent>(
      'delete_message',
      {'messageId': messageId},
      (data) =>
          DeletedMessageEvent.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<DeliveredReceipt> markAsDelivered(String messageId) {
    return _socketClient.emitWithAck<DeliveredReceipt>(
      'mark_as_delivered',
      {'messageId': messageId},
      (data) =>
          DeliveredReceipt.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<ReadReceipt> markAsRead(String messageId) {
    return _socketClient.emitWithAck<ReadReceipt>(
      'mark_as_read',
      {'messageId': messageId},
      (data) => ReadReceipt.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }
}
