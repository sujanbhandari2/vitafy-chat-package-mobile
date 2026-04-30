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
    this.unreadCount = 0,
    this.avatarUrl,
    this.isOnline,
    this.peerUsers = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final String avatarLabel;
  final DateTime createdAt;
  final DateTime? lastActivityAt;
  final bool isGlobal;
  final int unreadCount;
  final String? avatarUrl;
  final bool? isOnline;
  final List<MessengerUser> peerUsers;

  DateTime get effectiveActivityAt => lastActivityAt ?? createdAt;
}
