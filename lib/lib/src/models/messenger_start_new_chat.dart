import 'package:flutter/widgets.dart';

import 'messenger_group_create_request.dart';
import 'messenger_user.dart';

/// Whether the picker opens for a direct chat or group creation flow.
enum MessengerStartNewChatMode {
  direct,
  group,
}

/// How selected group members appear in the user list during group creation.
enum MessengerGroupSelectionListMode {
  /// Selected users are removed from the main list and shown in a chips section.
  separateSelectedSection,

  /// All users stay in the list; selected rows show a checkmark and toggle on tap.
  inlineCheckmark,
}

/// Data passed to [MessengerStartNewChatUserItemBuilder] for each picker row.
class MessengerUserPickerItemData {
  const MessengerUserPickerItemData({
    required this.user,
    required this.isSelected,
    required this.isSelectable,
    required this.isOpening,
    required this.onTap,
  });

  final MessengerUser user;
  final bool isSelected;
  final bool isSelectable;
  final bool isOpening;
  final VoidCallback onTap;
}

typedef MessengerStartNewChatUserItemBuilder = Widget Function(
  BuildContext context,
  MessengerUserPickerItemData data,
);

typedef MessengerStartNewChatSelectedUsersSectionBuilder = Widget Function(
  BuildContext context,
  List<MessengerUser> selectedUsers,
  void Function(String userId) onRemove,
);

/// Passed to a host [MessengerStartNewChatPresenter] when opening the picker.
///
/// Host presenters that replace [buildPicker] must call [onOpenDirectChat] /
/// [onCreateGroupRequested] (not only their own repository) so mobile shells
/// can push the conversation thread after create/select.
class MessengerStartNewChatOpenRequest {
  const MessengerStartNewChatOpenRequest({
    required this.mode,
    required this.buildPicker,
    required this.onOpenDirectChat,
    this.onCreateGroupRequested,
    this.onCreateGroupSelected,
  });

  final MessengerStartNewChatMode mode;
  final Widget Function() buildPicker;

  /// Opens (or reuses) a direct chat and, on mobile, shows the thread route.
  final Future<void> Function(MessengerUser user) onOpenDirectChat;

  /// Creates a named group and, on mobile, shows the thread route.
  final Future<void> Function(MessengerGroupCreateRequest request)?
      onCreateGroupRequested;

  /// Creates a group from a bare user list and, on mobile, shows the thread.
  final Future<void> Function(List<MessengerUser> selectedUsers)?
      onCreateGroupSelected;
}

typedef MessengerStartNewChatPresenter = Future<void> Function(
  BuildContext context,
  MessengerStartNewChatOpenRequest request,
);
