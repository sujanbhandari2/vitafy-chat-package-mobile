import 'package:flutter/foundation.dart';

/// Host-driven hooks for the **suggested people** user list (pagination and
/// optional debounced server search).
///
/// Pass this from [MessengerChatShell.suggestedDirectory] into
/// [MessengerSuggestedPeoplePanel.directory] (or wire the same fields manually).
///
/// **Search:** When [onSearchQueryDebounced] is non-null, the panel treats
/// [MessengerSuggestedPeoplePanel.users] as the host-provided result set and
/// skips local substring filtering. On each new query the host should replace
/// the list and reset pagination cursors. Use [onSearchQueryChanged] on the panel
/// for immediate per-keystroke updates (e.g. controlled [searchQuery]) if needed.
///
/// **Pagination:** [onNearEndOfList] fires when the user scrolls near the bottom.
/// The package only invokes it when [hasMore] is true and [isLoadingMore] is false.
/// Host handlers should be idempotent (ignore duplicate calls while a fetch is in flight).
///
/// **Group mode:** [MessengerSuggestedPeoplePanel] and the Start New Chat sheet
/// cache selected [MessengerUser] objects while [onSearchQueryDebounced] is set,
/// so chips and create-group callbacks stay stable when the host replaces
/// [users] per search or pagination. Hosts may still need their own backend
/// model cache (e.g. associated-user rows) for create APIs.
class MessengerSuggestedPeopleDirectory {
  const MessengerSuggestedPeopleDirectory({
    this.searchDebounce = Duration.zero,
    this.onSearchQueryDebounced,
    this.onNearEndOfList,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  /// Delay before [onSearchQueryDebounced] runs after the last keystroke.
  /// [Duration.zero] invokes [onSearchQueryDebounced] synchronously on each change
  /// when that callback is non-null.
  final Duration searchDebounce;

  /// Debounced trimmed search text for server-backed directory queries.
  final ValueChanged<String>? onSearchQueryDebounced;

  /// Near-end scroll signal for loading the next page (append on the host).
  final VoidCallback? onNearEndOfList;

  /// When false, [onNearEndOfList] is not called.
  final bool hasMore;

  /// While true, near-end requests are suppressed (show footer spinner via panel).
  final bool isLoadingMore;

  /// Bridges [MessengerStartNewChatDirectory] into a panel when unifying the
  /// Start New Chat sheet with [MessengerSuggestedPeoplePanel].
  factory MessengerSuggestedPeopleDirectory.fromStartNewChat(
    MessengerStartNewChatDirectory source,
  ) {
    return MessengerSuggestedPeopleDirectory(
      searchDebounce: source.searchDebounce,
      onSearchQueryDebounced: source.onSearchQueryDebounced,
      onNearEndOfList: source.onNearEndOfList,
      hasMore: source.hasMore,
      isLoadingMore: source.isLoadingMore,
    );
  }
}

/// Host-driven hooks for the **Start New Chat** sheet user list.
///
/// Same semantics as [MessengerSuggestedPeopleDirectory], applied inside
/// [MessengerConversationList] when [MessengerChatShell.startNewChatDirectory]
/// is provided.
///
/// See [MessengerSuggestedPeopleDirectory] for pagination and server-search notes.
class MessengerStartNewChatDirectory {
  const MessengerStartNewChatDirectory({
    this.searchDebounce = Duration.zero,
    this.onSearchQueryDebounced,
    this.onNearEndOfList,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final Duration searchDebounce;

  final ValueChanged<String>? onSearchQueryDebounced;

  final VoidCallback? onNearEndOfList;

  final bool hasMore;

  final bool isLoadingMore;
}
