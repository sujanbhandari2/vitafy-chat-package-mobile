import 'messenger_user.dart';

enum MessengerGroupNameInputBehavior {
  hidden,
  optional,
  required,
}

class MessengerGroupCreateRequest {
  const MessengerGroupCreateRequest({
    required this.selectedUsers,
    this.groupName = '',
  });

  final List<MessengerUser> selectedUsers;
  final String groupName;

  /// Name to send on `POST …/users/start-conversation`.
  ///
  /// Vitafy creates **DIRECT** when [groupName] is empty and only two users are
  /// sent; a non-empty value creates **GROUP**. Use this helper so group flows
  /// from the UI (including one selected peer) do not accidentally open a DM.
  String startConversationGroupName({String fallback = 'Group'}) {
    final trimmed = groupName.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return fallback.trim().isEmpty ? 'Group' : fallback.trim();
  }
}
