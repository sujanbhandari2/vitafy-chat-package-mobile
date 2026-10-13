import '../utils/messenger_composer_attachments.dart';
import '../widgets/messenger_media_send_orchestrator.dart';
import 'chat_auth.dart';
import 'chat_client.dart';
import 'chat_exceptions.dart';
import 'models/chat_message.dart';
import 'models/conversation.dart';

/// Host-callable workflows for **custom UI** integrations.
///
/// Forwards to [ChatClient] and optionally [MessengerMediaSendOrchestrator].
/// Does not render UI and does not change the default shell/thread path —
/// existing hosts that use `MessengerChatShell` callbacks continue unchanged.
class MessengerHostActions {
  MessengerHostActions({
    required ChatClient client,
    MessengerMediaSendOrchestrator? media,
  })  : _client = client,
        _media = media;

  final ChatClient _client;
  final MessengerMediaSendOrchestrator? _media;

  /// Deletes a conversation (1:1 or group).
  Future<void> deleteConversation(
    ChatAuth auth, {
    required String conversationId,
    String? actorUserId,
  }) {
    return _client.deleteConversation(
      auth,
      conversationId: conversationId,
      actorUserId: actorUserId,
    );
  }

  /// Lists current members for [conversationId] by refreshing conversations.
  ///
  /// Uses [ChatClient.getConversations] and returns the matched conversation's
  /// [Conversation.participants]. Throws [ChatUnexpectedResponseException] when
  /// the conversation is not in the returned list.
  Future<List<ConversationParticipant>> listGroupMembers(
    ChatAuth auth, {
    required String conversationId,
    String? forUserId,
  }) async {
    final conversations = await _client.getConversations(
      auth,
      forUserId: forUserId,
    );
    Conversation? match;
    for (final conversation in conversations) {
      if (conversation.id == conversationId) {
        match = conversation;
        break;
      }
    }
    if (match == null) {
      throw ChatUnexpectedResponseException(
        message: 'Conversation not found: $conversationId',
      );
    }
    return List<ConversationParticipant>.from(match.participants);
  }

  /// Adds a member to a group conversation.
  Future<ConversationParticipant> addGroupMember(
    ChatAuth auth, {
    required String conversationId,
    required String userId,
    String? actorUserId,
  }) {
    return _client.addParticipant(
      auth,
      conversationId: conversationId,
      userId: userId,
      actorUserId: actorUserId,
    );
  }

  /// Removes a member from a group conversation.
  Future<void> removeGroupMember(
    ChatAuth auth, {
    required String conversationId,
    required String userId,
    String? actorUserId,
  }) {
    return _client.removeParticipant(
      auth,
      conversationId: conversationId,
      userId: userId,
      actorUserId: actorUserId,
    );
  }

  /// Edits an already-sent message (socket).
  Future<ChatMessage> editMessage({
    required String conversationId,
    required String messageId,
    required String content,
  }) {
    return _client.editMessage(
      conversationId: conversationId,
      messageId: messageId,
      content: content,
    );
  }

  /// Deletes an already-sent message (REST).
  Future<DeleteMessageResult> deleteMessage(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
    required String userId,
  }) {
    return _client.deleteMessage(
      auth,
      conversationId: conversationId,
      messageId: messageId,
      userId: userId,
    );
  }

  /// Opens the platform picker for [kind] (image, voice, video, file, camera).
  ///
  /// Requires a [MessengerMediaSendOrchestrator] passed to the constructor.
  Future<List<MessengerPickedMedia>> pickAttachments(MessengerMediaKind kind) {
    return _requireMedia().pickMediaMany(kind);
  }

  /// Uploads and sends previously picked attachments for a conversation.
  ///
  /// Requires a [MessengerMediaSendOrchestrator] passed to the constructor.
  Future<MessengerSendPendingAttachmentsResult> sendAttachments({
    required String conversationId,
    required List<MessengerPickedMedia> pending,
    String caption = '',
    String? replyToMessageId,
    void Function(int sentPendingCount, double progress)? onUploadProgress,
  }) {
    return _requireMedia().sendPendingAttachments(
      conversationId: conversationId,
      pending: pending,
      caption: caption,
      replyToMessageId: replyToMessageId,
      onUploadProgress: onUploadProgress,
    );
  }

  MessengerMediaSendOrchestrator _requireMedia() {
    final media = _media;
    if (media == null) {
      throw StateError(
        'MessengerHostActions requires a MessengerMediaSendOrchestrator '
        'for attachment pick/send. Pass media: when constructing.',
      );
    }
    return media;
  }
}
