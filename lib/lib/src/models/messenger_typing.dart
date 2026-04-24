/// A remote user shown in the typing indicator row.
class MessengerTypingUser {
  const MessengerTypingUser({
    required this.userId,
    required this.displayLabel,
  });

  final String userId;
  final String displayLabel;
}
