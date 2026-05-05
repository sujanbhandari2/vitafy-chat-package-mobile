import '../chat_repository.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Pure merge rules for per-conversation unread counts (inbox badges).
class UnreadMerger {
  const UnreadMerger._();

  /// Merges [Conversation.unreadCount] from a REST list into [previous].
  /// `0` or missing count for an item removes that conversation key when present.
  static Map<String, int> mergeFromConversations(
    Map<String, int> previous,
    List<Conversation> list,
  ) {
    final next = Map<String, int>.from(previous);
    for (final c in list) {
      final u = c.unreadCount;
      if (u == null) {
        continue;
      }
      if (u <= 0) {
        next.remove(c.id);
      } else {
        next[c.id] = u;
      }
    }
    return next;
  }

  /// Applies authoritative unread from a `conversation_message` list event.
  static Map<String, int> applyConversationMessage(
    Map<String, int> previous,
    ConversationMessageEvent event, {
    required String currentUserId,
  }) {
    final next = Map<String, int>.from(previous);
    final unread = event.unreadCount ?? event.unread;
    if (unread != null) {
      if (unread <= 0) {
        next.remove(event.conversationId);
      } else {
        next[event.conversationId] = unread;
      }
      return next;
    }
    // No server count: never bump unread locally for your own messages.
    if (event.message.senderId == currentUserId) {
      return next;
    }
    return next;
  }

  static Map<String, int> applyUnreadCountUpdated(
    Map<String, int> previous,
    UnreadCountUpdatedEvent event, {
    required String currentUserId,
  }) {
    if (event.userId != currentUserId) {
      return previous;
    }
    final next = Map<String, int>.from(previous);
    if (event.unread <= 0) {
      next.remove(event.conversationId);
    } else {
      next[event.conversationId] = event.unread;
    }
    return next;
  }

  static Map<String, int> applyConversationCreated(
    Map<String, int> previous,
    ConversationCreatedEvent event,
  ) {
    final next = Map<String, int>.from(previous);
    final id = event.conversation.id;
    if (event.unreadCount <= 0) {
      next.remove(id);
    } else {
      next[id] = event.unreadCount;
    }
    return next;
  }

  /// When the server only broadcasts `message` / `message_received`, bump unread
  /// if the message is from someone else, the thread is not open, and we did not
  /// already account for this id via `conversation_message`.
  static Map<String, int> incrementForBroadcastFallback(
    Map<String, int> previous,
    ChatMessage message, {
    required String currentUserId,
    String? activeConversationId,
    required bool conversationMessageSeen,
  }) {
    if (message.senderId == currentUserId) {
      return previous;
    }
    if (message.isDeleted) {
      return previous;
    }
    if (message.conversationId == activeConversationId) {
      return previous;
    }
    if (conversationMessageSeen) {
      return previous;
    }
    final next = Map<String, int>.from(previous);
    final id = message.conversationId;
    next[id] = (next[id] ?? 0) + 1;
    return next;
  }

  /// Clears local unread when you send while the thread is open (web parity).
  static Map<String, int> applyOwnMessageInActiveThread(
    Map<String, int> previous,
    ChatMessage message, {
    required String currentUserId,
    String? activeConversationId,
  }) {
    if (message.senderId != currentUserId) {
      return previous;
    }
    if (message.conversationId != activeConversationId) {
      return previous;
    }
    final next = Map<String, int>.from(previous);
    next.remove(message.conversationId);
    return next;
  }

  static Map<String, int> setUnreadForConversation(
    Map<String, int> previous,
    String conversationId,
    int unread,
  ) {
    final next = Map<String, int>.from(previous);
    if (unread <= 0) {
      next.remove(conversationId);
    } else {
      next[conversationId] = unread;
    }
    return next;
  }
}
