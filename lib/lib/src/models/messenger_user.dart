class MessengerUser {
  const MessengerUser({
    required this.id,
    required this.username,
    this.roleLabel = '',
    this.isOnline = false,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String roleLabel;
  final bool isOnline;
  final String? avatarUrl;
}
