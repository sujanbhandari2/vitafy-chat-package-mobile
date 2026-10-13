import 'package:flutter/widgets.dart';

import '../models/messenger_user_directory.dart';

/// Supplies [MessengerChatShell.suggestedDirectory] to descendants such as
/// [MessengerSuggestedPeoplePanel] without changing [suggestedPeopleBuilder]'s
/// callback shape.
class MessengerSuggestedDirectoryScope extends InheritedWidget {
  const MessengerSuggestedDirectoryScope({
    super.key,
    this.directory,
    required super.child,
  });

  final MessengerSuggestedPeopleDirectory? directory;

  static MessengerSuggestedPeopleDirectory? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MessengerSuggestedDirectoryScope>()
        ?.directory;
  }

  @override
  bool updateShouldNotify(covariant MessengerSuggestedDirectoryScope oldWidget) {
    final a = directory;
    final b = oldWidget.directory;
    if (a == null && b == null) {
      return false;
    }
    if (a == null || b == null) {
      return true;
    }
    return a.hasMore != b.hasMore ||
        a.isLoadingMore != b.isLoadingMore ||
        a.searchDebounce != b.searchDebounce;
  }
}
