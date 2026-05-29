import 'messenger_user.dart';

class MessengerConversationLatestReaction {
  const MessengerConversationLatestReaction({
    required this.chatUserId,
    required this.reactionType,
    required this.createdAt,
    this.userName,
  });

  final String chatUserId;
  final String reactionType;
  final DateTime createdAt;
  final String? userName;

  String label({String? currentUserId}) {
    final isMine = currentUserId != null &&
        currentUserId.trim().isNotEmpty &&
        chatUserId.trim() == currentUserId.trim();
    final name = isMine
        ? 'you'
        : ((userName ?? '').trim().isEmpty ? 'Someone' : userName!.trim());
    final reaction = reactionType.trim().isEmpty ? '👍' : reactionType.trim();
    return '$name reacted $reaction';
  }
}

class MessengerConversation {
  const MessengerConversation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.avatarLabel,
    required this.createdAt,
    this.lastActivityAt,
    this.isGlobal = false,
    this.isGroup = false,
    this.unreadCount = 0,
    this.avatarUrl,
    this.isOnline,
    this.peerUsers = const [],
    this.apiRank,
    this.promotedAt,
    this.latestReaction,
  });

  final String id;
  final String title;
  final String subtitle;
  final String avatarLabel;
  final DateTime createdAt;
  final DateTime? lastActivityAt;
  final bool isGlobal;
  final bool isGroup;
  final int unreadCount;
  final String? avatarUrl;
  final bool? isOnline;
  final List<MessengerUser> peerUsers;

  /// Index from the last REST `getConversations` response (0 = first from API).
  final int? apiRank;

  /// When non-null, this row is sorted above cold rows; newer [promotedAt] first.
  final DateTime? promotedAt;

  /// When supplied, the list preview can show "you reacted 😂" or
  /// "Sujan Bhandari reacted 😂" instead of the last message subtitle.
  final MessengerConversationLatestReaction? latestReaction;

  DateTime get effectiveActivityAt => lastActivityAt ?? createdAt;

  String previewSubtitle({String? currentUserId}) {
    final reaction = latestReaction;
    if (reaction != null) {
      return reaction.label(currentUserId: currentUserId);
    }
    return subtitle;
  }
}
