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
}
