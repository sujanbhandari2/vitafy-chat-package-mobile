import 'package:flutter/widgets.dart';

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
class MessengerStartNewChatOpenRequest {
  const MessengerStartNewChatOpenRequest({
    required this.mode,
    required this.buildPicker,
  });

  final MessengerStartNewChatMode mode;
  final Widget Function() buildPicker;
}

typedef MessengerStartNewChatPresenter = Future<void> Function(
  BuildContext context,
  MessengerStartNewChatOpenRequest request,
);
