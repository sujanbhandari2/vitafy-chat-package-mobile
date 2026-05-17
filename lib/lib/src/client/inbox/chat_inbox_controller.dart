import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../chat_client.dart';
import '../chat_connection_state.dart';
import '../chat_repository.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'unread_merger.dart';

/// API list index + promotion times for sidebar ordering.
class ConversationOrderSnapshot {
  const ConversationOrderSnapshot({
    required this.apiRank,
    required this.promotedAt,
  });

  final Map<String, int> apiRank;
  final Map<String, DateTime> promotedAt;
}

/// Central inbox policy: unread map, join + mark read, delivered/read emits.
class ChatInboxController {
  ChatInboxController({
    required ChatClient client,
    required String currentUserId,
    Stream<ChatConnectionState>? connectionState,
    int conversationMessageIdCacheSize = 512,
    int receiptDedupeCacheSize = 512,
  })  : _client = client,
        _currentUserId = currentUserId,
        _conversationMessageIds =
            _BoundedStringSet(maxSize: conversationMessageIdCacheSize),
        _deliveredEmitted = _BoundedStringSet(maxSize: receiptDedupeCacheSize),
        _readEmitted = _BoundedStringSet(maxSize: receiptDedupeCacheSize) {
    _eventsSubscription = _client.events.listen(
      _onSocketEvent,
      onError: (_) {},
    );
    _connectionSubscription =
        (connectionState ?? _client.connectionState).listen(
      _onConnectionState,
      onError: (_) {},
    );
  }

  final ChatClient _client;
  final String _currentUserId;

  final _BoundedStringSet _conversationMessageIds;
  final _BoundedStringSet _deliveredEmitted;
  final _BoundedStringSet _readEmitted;

  final ValueNotifier<Map<String, int>> _unreadNotifier =
      ValueNotifier<Map<String, int>>(<String, int>{});

  final ValueNotifier<UserBadgeUpdatedEvent?> _badgeNotifier =
      ValueNotifier<UserBadgeUpdatedEvent?>(null);

  final Map<String, int> _apiRank = <String, int>{};
  final Map<String, DateTime> _promotedAt = <String, DateTime>{};

  final ValueNotifier<ConversationOrderSnapshot> _orderNotifier =
      ValueNotifier<ConversationOrderSnapshot>(
    ConversationOrderSnapshot(
      apiRank: Map<String, int>.unmodifiable(<String, int>{}),
      promotedAt: Map<String, DateTime>.unmodifiable(<String, DateTime>{}),
    ),
  );

  StreamSubscription<ChatSocketEvent>? _eventsSubscription;
  StreamSubscription<ChatConnectionState>? _connectionSubscription;

  String? _activeConversationId;
  bool _threadVisible = false;

  /// Currently focused conversation id, if any.
  String? get activeConversationId => _activeConversationId;

  /// Whether the message thread UI is on screen for [activeConversationId].
  bool get threadVisible => _threadVisible;

  /// Host/shell should call when the thread pane opens or closes.
  ///
  /// Read receipts and [markConversationRead] run only while visible so list-only
  /// or background selection does not mark messages seen.
  Future<void> setThreadVisible(bool visible) async {
    if (_threadVisible == visible) {
      return;
    }
    _threadVisible = visible;
    if (visible) {
      await _markActiveConversationRead();
    }
  }

  ValueListenable<Map<String, int>> get unreadByConversation => _unreadNotifier;

  ValueListenable<UserBadgeUpdatedEvent?> get userBadge => _badgeNotifier;

  ValueListenable<ConversationOrderSnapshot> get conversationOrder =>
      _orderNotifier;

  void _emitOrder() {
    _orderNotifier.value = ConversationOrderSnapshot(
      apiRank: Map<String, int>.unmodifiable(Map<String, int>.from(_apiRank)),
      promotedAt: Map<String, DateTime>.unmodifiable(
        Map<String, DateTime>.from(_promotedAt),
      ),
    );
  }

  /// Bumps [conversationId] to the hot tier (most recent [promotedAt] sorts first).
  void bumpConversation(String conversationId, {DateTime? at}) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    _promotedAt[id] = at ?? DateTime.now();
    _emitOrder();
  }

  void seedFromConversations(List<Conversation> list) {
    _unreadNotifier.value = UnreadMerger.mergeFromConversations(
      _unreadNotifier.value,
      list,
      currentUserId: _currentUserId,
      activeConversationId: _activeConversationId,
    );
    final liveIds = list.map((item) => item.id.trim()).toSet();
    _promotedAt.removeWhere((key, _) => !liveIds.contains(key));
    _apiRank
      ..clear()
      ..addEntries(
        list.asMap().entries.map(
              (e) => MapEntry(e.value.id, e.key),
            ),
      );
    _emitOrder();
  }

  /// Clears the local badge for [conversationId] without touching the server.
  void clearLocalUnread(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    _unreadNotifier.value =
        UnreadMerger.setUnreadForConversation(_unreadNotifier.value, id, 0);
  }

  /// Leave the previous room (if any), join [conversationId], then
  /// [markConversationRead]. Pass `null` to leave the active thread only.
  Future<void> setActiveConversation(String? conversationId) async {
    var next = conversationId?.trim();
    if (next != null && next.isEmpty) {
      next = null;
    }

    final previous = _activeConversationId;
    if (previous != null && previous != next) {
      try {
        await _client.leaveConversation(previous);
      } catch (_) {}
    }

    _activeConversationId = next;

    if (next == null) {
      _threadVisible = false;
      return;
    }

    if (previous == next) {
      await _joinActiveRoom(next);
      if (_threadVisible) {
        await _markActiveConversationRead();
      }
      return;
    }

    // Optimistic clear only when switching threads (matches web selectConversation).
    clearLocalUnread(next);
    await _joinActiveRoom(next);
    if (_threadVisible) {
      await _markActiveConversationRead();
    }
  }

  Future<void> _joinActiveRoom(String conversationId) async {
    try {
      await _client.joinConversation(conversationId);
    } catch (_) {}
  }

  Future<void> _markActiveConversationRead() async {
    final conversationId = _activeConversationId?.trim();
    if (conversationId == null || conversationId.isEmpty) {
      return;
    }
    try {
      final result = await _client.markConversationRead(
        conversationId: conversationId,
      );
      _unreadNotifier.value = UnreadMerger.setUnreadForConversation(
        _unreadNotifier.value,
        conversationId,
        result.unread,
      );
    } catch (_) {}
  }

  void _onConnectionState(ChatConnectionState state) {
    if (state == ChatConnectionState.connected) {
      final active = _activeConversationId;
      if (active != null) {
        unawaited(() async {
          await _joinActiveRoom(active);
          if (_threadVisible) {
            await _markActiveConversationRead();
          }
        }());
      }
    }
  }

  void _onSocketEvent(ChatSocketEvent event) {
    switch (event.type) {
      case ChatSocketEventType.messageReceived:
        final message = event.message;
        if (message != null) {
          _onInboundMessage(message, fromConversationMessage: false);
        }
        break;
      case ChatSocketEventType.conversationMessage:
        final cm = event.conversationMessage;
        if (cm != null) {
          _conversationMessageIds.add(cm.message.id);
          _unreadNotifier.value = UnreadMerger.applyConversationMessage(
            _unreadNotifier.value,
            cm,
            currentUserId: _currentUserId,
          );
          _onInboundMessage(cm.message, fromConversationMessage: true);
        }
        break;
      case ChatSocketEventType.unreadCountUpdated:
        final u = event.unreadCountUpdated;
        if (u != null) {
          _unreadNotifier.value = UnreadMerger.applyUnreadCountUpdated(
            _unreadNotifier.value,
            u,
            currentUserId: _currentUserId,
          );
        }
        break;
      case ChatSocketEventType.conversationCreated:
        final c = event.conversationCreated;
        if (c != null) {
          final id = c.conversation.id.trim();
          if (id.isNotEmpty && !_apiRank.containsKey(id)) {
            final maxR = _apiRank.isEmpty
                ? -1
                : _apiRank.values.reduce((a, b) => a > b ? a : b);
            _apiRank[id] = maxR + 1;
          }
          if (id.isNotEmpty) {
            bumpConversation(id);
          }
          _unreadNotifier.value = UnreadMerger.applyConversationCreated(
            _unreadNotifier.value,
            c,
          );
        }
        break;
      case ChatSocketEventType.userBadgeUpdated:
        final b = event.userBadgeUpdated;
        if (b != null) {
          _badgeNotifier.value = b;
        }
        break;
      default:
        break;
    }
  }

  void _onInboundMessage(
    ChatMessage message, {
    required bool fromConversationMessage,
  }) {
    final cid = message.conversationId.trim();
    if (!message.isDeleted && cid.isNotEmpty) {
      bumpConversation(cid);
    }

    if (message.senderId == _currentUserId) {
      _unreadNotifier.value = UnreadMerger.applyOwnMessageInActiveThread(
        _unreadNotifier.value,
        message,
        currentUserId: _currentUserId,
        activeConversationId: _activeConversationId,
      );
      return;
    }

    if (!fromConversationMessage) {
      final seen = _conversationMessageIds.contains(message.id);
      _unreadNotifier.value = UnreadMerger.incrementForBroadcastFallback(
        _unreadNotifier.value,
        message,
        currentUserId: _currentUserId,
        activeConversationId: _activeConversationId,
        conversationMessageSeen: seen,
      );
    }

    if (message.isDeleted) {
      return;
    }

    unawaited(_emitDeliveredAndRead(message));
  }

  Future<void> _emitDeliveredAndRead(ChatMessage message) async {
    final convId = message.conversationId;
    final msgId = message.id;
    if (convId.isEmpty || msgId.isEmpty) {
      return;
    }

    if (!_deliveredEmitted.contains(msgId)) {
      _deliveredEmitted.add(msgId);
      try {
        await _client.markAsDelivered(
          conversationId: convId,
          messageId: msgId,
        );
      } catch (_) {
        _deliveredEmitted.remove(msgId);
      }
    }

    if (_threadVisible && message.conversationId == _activeConversationId) {
      if (!_readEmitted.contains(msgId)) {
        _readEmitted.add(msgId);
        try {
          await _client.markAsRead(
            conversationId: convId,
            messageId: msgId,
          );
        } catch (_) {
          _readEmitted.remove(msgId);
        }
      }
    }
  }

  Future<void> dispose() async {
    await _eventsSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _eventsSubscription = null;
    _connectionSubscription = null;
    _unreadNotifier.dispose();
    _badgeNotifier.dispose();
    _orderNotifier.dispose();
  }
}

class _BoundedStringSet {
  _BoundedStringSet({required this.maxSize});

  final int maxSize;
  final Queue<String> _order = Queue<String>();
  final Set<String> _set = <String>{};

  void add(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty || _set.contains(trimmed)) {
      return;
    }
    _set.add(trimmed);
    _order.addLast(trimmed);
    while (_order.length > maxSize) {
      final old = _order.removeFirst();
      _set.remove(old);
    }
  }

  void remove(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _set.remove(trimmed);
    _order.removeWhere((e) => e == trimmed);
  }

  bool contains(String id) => _set.contains(id.trim());
}
