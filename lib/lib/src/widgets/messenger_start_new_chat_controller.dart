import 'package:flutter/widgets.dart';

import '../models/messenger_start_new_chat.dart';

typedef MessengerStartNewChatOpener = Future<void> Function(
  BuildContext context, {
  required MessengerStartNewChatMode mode,
});

/// Programmatic entry point for opening the start-new-chat picker from a host app.
///
/// Attach to [MessengerChatShell.startNewChatController]; the shell registers
/// open handlers while mounted.
class MessengerStartNewChatController {
  MessengerStartNewChatOpener? _open;

  /// Whether the controller is bound to a mounted [MessengerChatShell].
  bool get isAttached => _open != null;

  /// Opens the picker for starting a direct (1:1) chat.
  Future<void> openDirectChatPicker(BuildContext context) {
    final open = _open;
    if (open == null) {
      return Future<void>.value();
    }
    return open(context, mode: MessengerStartNewChatMode.direct);
  }

  /// Opens the picker in group-creation mode (skips the "+ New group" step).
  Future<void> openGroupChatPicker(BuildContext context) {
    final open = _open;
    if (open == null) {
      return Future<void>.value();
    }
    return open(context, mode: MessengerStartNewChatMode.group);
  }

  void attachHandler(MessengerStartNewChatOpener opener) {
    _open = opener;
  }

  void detachHandler(MessengerStartNewChatOpener opener) {
    if (identical(_open, opener)) {
      _open = null;
    }
  }
}
