import '../chat_repository.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Pure merge rules for per-conversation unread counts (inbox badges).
class UnreadMerger {
  const UnreadMerger._();

  /// Merges per-conversation unread from a REST list into [previous].
  ///
  /// Resolution order per row:
  ///   1. Explicit numeric `unreadCount` / `unread` from the server wins (back-compat).
  ///      A value of `0` or less clears the entry.
  ///   2. Otherwise, when `latestMessageId` and the current user's message status
  ///      are present, derive unread from `lastReadMessageId` vs `latestMessageId`.
  ///      Unread sets the entry to `max(previous, 1)` so any prior socket-derived
  ///      count is preserved while a fresh seed still shows bold as `1`.
  ///   3. Rows with neither signal are left untouched.
  ///
  /// When [activeConversationId] is set, that conversation is force-cleared so
  /// the open thread stays at zero on refresh (matches join+markRead semantics).
  static Map<String, int> mergeFromConversations(
    Map<String, int> previous,
    List<Conversation> list, {
    required String currentUserId,
    String? activeConversationId,
  }) {
    final next = Map<String, int>.from(previous);
    final active = activeConversationId?.trim();
    for (final c in list) {
      final id = c.id;
      final u = c.unreadCount;
      if (u != null) {
        if (u <= 0) {
          next.remove(id);
        } else {
          next[id] = u;
        }
      } else if (c.latestMessageId != null &&
          c.messageStatusByUserId.isNotEmpty) {
        if (c.isUnreadFor(currentUserId)) {
          final prev = next[id] ?? 0;
          next[id] = prev > 1 ? prev : 1;
        } else {
          next.remove(id);
        }
      }
      if (active != null && active.isNotEmpty && id == active) {
        next.remove(id);
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
