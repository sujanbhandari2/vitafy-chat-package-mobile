import '../models/messenger_conversation.dart';
import '../widgets/messenger_conversation_list_item.dart';

/// Avatar initials for the conversation thread header (first + last name).
String messengerThreadHeaderAvatarLabel(MessengerConversation? conversation) {
  if (conversation == null) {
    return 'CH';
  }

  final title = conversation.title.trim();
  if (title.isNotEmpty) {
    return conversationListItemInitials(title);
  }

  final label = conversation.avatarLabel.trim();
  return label.isNotEmpty ? label : 'CH';
}

/// Profile image for the conversation thread header when available.
String? messengerThreadHeaderAvatarUrl(MessengerConversation? conversation) {
  if (conversation == null) {
    return null;
  }

  final url = conversation.avatarUrl?.trim();
  if (url != null && url.isNotEmpty) {
    return url;
  }

  if (conversation.isGroup) {
    return null;
  }

  for (final peer in conversation.peerUsers) {
    final peerUrl = peer.avatarUrl?.trim();
    if (peerUrl != null && peerUrl.isNotEmpty) {
      return peerUrl;
    }
  }

  return null;
}
