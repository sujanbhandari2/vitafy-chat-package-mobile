class MessengerUser {
  const MessengerUser({
    required this.id,
    required this.username,
    this.roleLabel = '',
    this.email = '',
    this.isOnline = false,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String roleLabel;
  final String email;
  final bool isOnline;
  final String? avatarUrl;
}
