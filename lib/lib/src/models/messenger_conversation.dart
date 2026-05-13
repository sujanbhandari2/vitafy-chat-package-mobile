import 'messenger_user.dart';

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

  DateTime get effectiveActivityAt => lastActivityAt ?? createdAt;
}
