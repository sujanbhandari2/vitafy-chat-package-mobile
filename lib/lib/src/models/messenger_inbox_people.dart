import 'package:flutter/material.dart';

import 'messenger_conversation.dart';
import 'messenger_user.dart';

/// Row payload for the optional mobile inbox "available people" section.
class MessengerAvailablePersonData {
  const MessengerAvailablePersonData({
    required this.user,
    required this.isOpening,
    required this.onTap,
  });

  final MessengerUser user;
  final bool isOpening;
  final VoidCallback onTap;
}

/// Normalized identity keys for deduplicating [MessengerUser] rows across
/// directories (e.g. chat-user id vs external user id).
///
/// Uses stable ids and email only — not display name — so distinct platform
/// accounts that share a name (e.g. CLIENT vs ADMIN) stay separate.
Set<String> messengerUserIdentityKeys(MessengerUser user) {
  final keys = <String>{};
  for (final rawId in [user.id, user.externalUserId ?? '']) {
    final id = rawId.trim();
    if (id.isNotEmpty && !id.startsWith('__conversation__:')) {
      keys.add('id:$id');
    }
  }

  final email = user.email.trim().toLowerCase();
  if (email.isNotEmpty) {
    keys.add('email:$email');
  }

  return keys;
}

String _normalizedMessengerUserName(String username) {
  final trimmed = username.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part.toLowerCase())
      .join(' ');
}

bool _messengerUsersShareIdentity(
  MessengerUser left,
  MessengerUser right,
) {
  final leftKeys = messengerUserIdentityKeys(left);
  return messengerUserIdentityKeys(right).any(leftKeys.contains);
}

String _inboxNormalizedDisplayName(String username) {
  final trimmed = username.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part.toLowerCase())
      .join(' ');
}

/// Matches a directory row to a conversation row when the API omits
/// [MessengerConversation.peerUsers] on list payloads.
bool messengerDirectoryUserMatchesConversation({
  required MessengerUser user,
  required MessengerConversation conversation,
}) {
  if (conversation.peerUsers.isNotEmpty) {
    return false;
  }
  final username = user.username.trim().toLowerCase();
  if (username.isEmpty) {
    return false;
  }
  final display = _inboxNormalizedDisplayName(user.username);
  final title = conversation.title.trim().toLowerCase();
  final subtitle = conversation.subtitle.trim().toLowerCase();
  return title.contains(username) ||
      (display.isNotEmpty && title.contains(display)) ||
      subtitle.contains(username) ||
      (display.isNotEmpty && subtitle.contains(display));
}

/// Returns tenant users who do not already appear in the conversation inbox
/// section, excluding [currentUserId].
///
/// [visibleConversationUsers] should be the individual user rows currently
/// shown in the Chats section (not synthetic group/conversation rows).
/// [conversations] peer users are also checked with identity matching so a
/// directory row matches a conversation peer even when ids differ.
///
/// Result is sorted online-first, then username (matches start-new-chat order).
List<MessengerUser> messengerAvailablePeopleExcludingConversations({
  required List<MessengerUser> allPeople,
  required List<MessengerConversation> conversations,
  String? currentUserId,
  String? currentPlatformUserId,
  Iterable<MessengerUser> visibleConversationUsers = const [],
}) {
  final excludedUsers = <MessengerUser>[];

  for (final user in visibleConversationUsers) {
    if (user.id.trim().startsWith('__conversation__:')) {
      continue;
    }
    excludedUsers.add(user);
  }

  for (final conversation in conversations) {
    excludedUsers.addAll(conversation.peerUsers);
  }

  final selfId = currentUserId?.trim() ?? '';
  final selfPlatformId = currentPlatformUserId?.trim() ?? '';
  final available = allPeople.where((user) {
    final id = user.id.trim();
    if (id.isEmpty) {
      return false;
    }
    if (selfId.isNotEmpty &&
        (id == selfId || user.externalUserId?.trim() == selfId)) {
      return false;
    }
    if (selfPlatformId.isNotEmpty &&
        (id == selfPlatformId ||
            user.externalUserId?.trim() == selfPlatformId)) {
      return false;
    }
    for (final excluded in excludedUsers) {
      if (_messengerUsersShareIdentity(user, excluded)) {
        return false;
      }
    }
    return true;
  }).toList(growable: false);

  final sorted = [...available]
    ..sort((left, right) {
      if (left.isOnline != right.isOnline) {
        return left.isOnline ? -1 : 1;
      }
      return left.username
          .toLowerCase()
          .compareTo(right.username.toLowerCase());
    });
  return sorted;
}

/// Associated people for the open conversation thread: tenant users who are
/// not already participants in [conversation], excluding the current user.
List<MessengerUser> messengerAssociatedPeopleForThread({
  required List<MessengerUser> allPeople,
  required MessengerConversation? conversation,
  String? currentUserId,
  String? currentPlatformUserId,
}) {
  if (conversation == null) {
    return messengerAvailablePeopleExcludingConversations(
      allPeople: allPeople,
      conversations: const [],
      currentUserId: currentUserId,
      currentPlatformUserId: currentPlatformUserId,
    );
  }

  return messengerAvailablePeopleExcludingConversations(
    allPeople: allPeople,
    conversations: [conversation],
    currentUserId: currentUserId,
    currentPlatformUserId: currentPlatformUserId,
  );
}
