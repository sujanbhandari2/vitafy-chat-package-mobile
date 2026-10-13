import 'package:flutter/foundation.dart';

import '../chat_repository.dart';

/// Stores remote users' online/offline status based on socket presence events.
///
/// This is "other users' presence" (directory presence), not "own presence"
/// which is controlled by [PresenceController] state machine.
class RemotePresenceStore {
  RemotePresenceStore({required String currentUserId})
      : _currentUserId = currentUserId.trim();

  final String _currentUserId;

  final ValueNotifier<Map<String, bool>> _onlineByUserId =
      ValueNotifier<Map<String, bool>>(<String, bool>{});

  /// Immutable view of [userId] → `isOnline`.
  ValueListenable<Map<String, bool>> get onlineByUserId =>
      _onlineByUserId;

  void dispose() {
    _onlineByUserId.dispose();
  }

  void applyUserOnline(ChatPresenceEvent presence) {
    if (presence.userId.trim() == _currentUserId) {
      return;
    }
    _update(presence.userId, true);
  }

  void applyUserOffline(ChatPresenceEvent presence) {
    if (presence.userId.trim() == _currentUserId) {
      return;
    }
    _update(presence.userId, false);
  }

  void applyPresenceStateMap(Map<String, bool> map) {
    // Replace whole map for atomic updates.
    final cleaned = <String, bool>{};
    for (final entry in map.entries) {
      final userId = entry.key.trim();
      if (userId.isEmpty) {
        continue;
      }
      if (userId == _currentUserId) {
        continue;
      }
      cleaned[userId] = entry.value;
    }
    _onlineByUserId.value = Map<String, bool>.unmodifiable(cleaned);
  }

  void _update(String userId, bool isOnline) {
    final uid = userId.trim();
    if (uid.isEmpty || uid == _currentUserId) {
      return;
    }

    final previous = _onlineByUserId.value;
    final current = previous[uid];
    if (current == isOnline) {
      return;
    }
    final next = Map<String, bool>.from(previous);
    next[uid] = isOnline;
    _onlineByUserId.value = Map<String, bool>.unmodifiable(next);
  }
}

