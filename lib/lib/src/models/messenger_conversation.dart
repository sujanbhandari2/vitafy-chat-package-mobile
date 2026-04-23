class MessengerConversation {
  const MessengerConversation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.avatarLabel,
    required this.createdAt,
    this.isGlobal = false,
    this.unreadCount = 0,
    this.avatarUrl,
    this.isOnline,
  });

  final String id;
  final String title;
  final String subtitle;
  final String avatarLabel;
  final DateTime createdAt;
  final bool isGlobal;
  final int unreadCount;
  final String? avatarUrl;
  final bool? isOnline;
}
