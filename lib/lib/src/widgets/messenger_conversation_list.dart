import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messenger_conversation.dart';
import '../models/messenger_group_create_request.dart';
import '../models/messenger_search_visibility.dart';
import '../models/messenger_start_new_chat.dart';
import '../models/messenger_user.dart';
import '../models/messenger_user_directory.dart';
import '../theme/messenger_theme.dart';
import 'messenger_default_inline_loading.dart';
import 'messenger_conversation_list_item.dart';
import 'messenger_list_search_field.dart';
import 'messenger_start_new_chat_picker.dart';

export 'messenger_conversation_list_item.dart'
    show
        MessengerConversationListItem,
        MessengerConversationListRoleChip,
        MessengerUserListItemData,
        MessengerUserListItemStyle,
        conversationListItemDisplayName,
        conversationListItemInitials,
        conversationListItemSubtitle;

/// Avoid treating every row as "opening" when both ids are empty (`'' == ''`).
bool _isDirectOpenBusyForUser(String openingDirectUserId, String userId) {
  final open = openingDirectUserId.trim();
  return open.isNotEmpty && open == userId.trim();
}

class MessengerConversationList extends StatefulWidget {
  const MessengerConversationList({
    super.key,
    this.currentUserId,
    required this.currentUserName,
    required this.conversations,
    required this.users,
    required this.selectedConversationId,
    required this.openingDirectUserId,
    required this.onRefresh,
    this.enablePullToRefresh = true,
    this.isConversationListLoading = false,
    this.conversationListLoadingBuilder,
    required this.onLogout,
    required this.onOpenDirectChat,
    this.onCreateGroupSelected,
    this.onCreateGroupRequested,
    this.isCreatingGroup = false,
    required this.onSelectConversation,
    this.searchVisibility = MessengerSearchVisibility.auto,
    this.conversationSearchController,
    this.searchThreshold = 10,
    this.searchHintText = 'Search',
    this.emptyUsersMessage = 'No users available right now.',
    this.emptyConversationsMessage = 'No conversations available yet.',
    this.conversationSearchNoResultsMessage = '"{query}" not found.',
    this.emptyUsersBuilder,
    this.emptyConversationsBuilder,
    this.conversationSearchNoResultsBuilder,
    this.showStartChatFab = true,
    this.isMobile = false,
    this.showHeaderEditButton = true,
    this.showHeaderTitle = true,
    this.showHeaderComposeButton = true,
    this.startNewChatEmptyBuilder,
    this.startNewChatUsersLoading = false,
    this.fabBackgroundColor,
    this.fabForegroundColor,
    this.fabIcon,
    this.fabHeroTag,
    this.userListPadding,
    this.userListItemSpacing = 6,
    this.userListItemStyle = const MessengerUserListItemStyle(),
    this.userListItemBuilder,
    this.searchInputTextStyle,
    this.searchHintTextStyle,
    this.searchFieldBackgroundColor,
    this.searchFieldContentPadding,
    this.searchIconColor,
    this.searchFieldBorderRadius,
    this.groupNameInputBehavior = MessengerGroupNameInputBehavior.hidden,
    this.groupNameFieldLabelText = 'Group name',
    this.groupNameFieldHintText = 'Enter a group name',
    this.groupNameRequiredErrorText = 'Enter a group name to continue.',
    this.defaultGroupNameWhenEmpty = 'Group',
    this.groupMinSelectionCount = 1,
    this.startNewChatUsers,
    this.startNewChatDirectory,
    this.startNewChatPresenter,
    this.groupSelectionListMode =
        MessengerGroupSelectionListMode.separateSelectedSection,
    this.startNewChatUserItemBuilder,
    this.selectedUsersSectionBuilder,
  }) : assert(
          groupMinSelectionCount > 0,
          'groupMinSelectionCount must be greater than zero.',
        );

  final String? currentUserId;
  final String currentUserName;
  final List<MessengerConversation> conversations;
  final List<MessengerUser> users;
  final String? selectedConversationId;
  final String openingDirectUserId;

  /// Reloads remote data (conversations, users, etc.). Awaited by pull-to-
  /// refresh and fire-and-forgotten from the header Edit action.
  final Future<void> Function() onRefresh;

  /// When true (default), the peer list body is wrapped in [RefreshIndicator].
  final bool enablePullToRefresh;

  /// When true, replaces the peer scroll body with a centered loading indicator
  /// (see [conversationListLoadingBuilder]).
  final bool isConversationListLoading;

  /// Custom loading widget for [isConversationListLoading]. Defaults to
  /// [MessengerDefaultInlineLoading].
  final WidgetBuilder? conversationListLoadingBuilder;

  final VoidCallback onLogout;
  final FutureOr<void> Function(MessengerUser user) onOpenDirectChat;
  final FutureOr<void> Function(List<MessengerUser> selectedUsers)?
      onCreateGroupSelected;
  final FutureOr<void> Function(MessengerGroupCreateRequest request)?
      onCreateGroupRequested;
  final bool isCreatingGroup;
  final FutureOr<void> Function(String conversationId) onSelectConversation;
  final MessengerSearchVisibility searchVisibility;

  /// When set, drives peer-list filtering and hides the built-in search field
  /// so the host can render search in its own chrome (e.g. sticky tab header).
  final TextEditingController? conversationSearchController;

  final int searchThreshold;
  final String searchHintText;
  final String emptyUsersMessage;
  final String emptyConversationsMessage;

  /// Shown when the conversation list search has no matches. `{query}` is
  /// replaced with the trimmed search text.
  final String conversationSearchNoResultsMessage;

  final WidgetBuilder? emptyUsersBuilder;
  final WidgetBuilder? emptyConversationsBuilder;

  /// Overrides [conversationSearchNoResultsMessage] when the search field is
  /// non-empty and filters out every conversation.
  final Widget Function(BuildContext context, String query)?
      conversationSearchNoResultsBuilder;
  final bool showStartChatFab;
  final bool isMobile;
  final bool showHeaderEditButton;
  final bool showHeaderTitle;
  final bool showHeaderComposeButton;
  final WidgetBuilder? startNewChatEmptyBuilder;

  /// Passed to the Start New Chat sheet: when true and [users] is empty, the
  /// sheet shows an inline loader instead of the empty-user copy.
  final bool startNewChatUsersLoading;

  final Color? fabBackgroundColor;
  final Color? fabForegroundColor;
  final IconData? fabIcon;
  final Object? fabHeroTag;
  final EdgeInsetsGeometry? userListPadding;
  final double userListItemSpacing;
  final MessengerUserListItemStyle userListItemStyle;
  final Widget Function(BuildContext context, MessengerUserListItemData data)?
      userListItemBuilder;
  final TextStyle? searchInputTextStyle;
  final TextStyle? searchHintTextStyle;
  final Color? searchFieldBackgroundColor;
  final EdgeInsetsGeometry? searchFieldContentPadding;
  final Color? searchIconColor;
  final double? searchFieldBorderRadius;
  final MessengerGroupNameInputBehavior groupNameInputBehavior;
  final String groupNameFieldLabelText;
  final String groupNameFieldHintText;
  final String groupNameRequiredErrorText;
  final String defaultGroupNameWhenEmpty;
  final int groupMinSelectionCount;

  /// Optional directory rows for the **Start New Chat** sheet only.
  ///
  /// When null, the sheet uses [users] (existing behavior).
  final List<MessengerUser>? startNewChatUsers;

  /// Debounced server search and/or pagination for the Start New Chat sheet.
  final MessengerStartNewChatDirectory? startNewChatDirectory;

  /// When set, all start-new-chat entry points (FAB, header, controller) use
  /// this presenter instead of the package default bottom sheet.
  final MessengerStartNewChatPresenter? startNewChatPresenter;

  /// How selected users appear in the group-creation user list.
  final MessengerGroupSelectionListMode groupSelectionListMode;

  /// Custom row builder for the Start New Chat picker.
  final MessengerStartNewChatUserItemBuilder? startNewChatUserItemBuilder;

  /// Custom selected-users section for group mode (chips card).
  final MessengerStartNewChatSelectedUsersSectionBuilder?
      selectedUsersSectionBuilder;

  @override
  State<MessengerConversationList> createState() =>
      MessengerConversationListState();
}

class _PeerListEntry {
  const _PeerListEntry({
    required this.user,
    required this.messagePreview,
    required this.hasUnread,
    required this.isInSelectedConversation,
    this.isConversationRow = false,
    this.useGroupAvatar = false,
    this.groupAvatarUsers = const [],
    this.conversationId,
  });

  final MessengerUser user;
  final String messagePreview;
  final bool hasUnread;
  final bool isInSelectedConversation;
  final bool isConversationRow;
  final bool useGroupAvatar;
  final List<MessengerUser> groupAvatarUsers;

  /// When known (peer came from a conversation row), open via [MessengerConversationList.onSelectConversation].
  final String? conversationId;
}

class MessengerConversationListState extends State<MessengerConversationList> {
  late final TextEditingController _searchController;
  late final bool _ownsSearchController;
  String _query = '';

  ValueNotifier<MessengerStartNewChatSheetLiveData>? _startNewChatSheetLive;

  List<MessengerUser> _sortedUsersForStartNewChatSheet() {
    final source = widget.startNewChatUsers ?? widget.users;
    final sorted = [...source]..sort((a, b) {
        if (a.isOnline == b.isOnline) {
          return a.username.toLowerCase().compareTo(b.username.toLowerCase());
        }
        return a.isOnline ? -1 : 1;
      });
    return sorted;
  }

  MessengerStartNewChatSheetLiveData _buildStartNewChatSheetLiveData() {
    final d = widget.startNewChatDirectory;
    return MessengerStartNewChatSheetLiveData(
      sortedUsers: _sortedUsersForStartNewChatSheet(),
      isUsersLoading: widget.startNewChatUsersLoading,
      openingDirectUserId: widget.openingDirectUserId,
      isCreatingGroup: widget.isCreatingGroup,
      directoryHasMore: d?.hasMore ?? false,
      directoryLoadingMore: d?.isLoadingMore ?? false,
    );
  }

  @override
  void initState() {
    super.initState();
    final external = widget.conversationSearchController;
    if (external != null) {
      _searchController = external;
      _ownsSearchController = false;
    } else {
      _searchController = TextEditingController();
      _ownsSearchController = true;
    }
    _query = _searchController.text.trim();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void didUpdateWidget(covariant MessengerConversationList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationSearchController !=
        widget.conversationSearchController) {
      _searchController.removeListener(_handleSearchChange);
      if (_ownsSearchController) {
        _searchController.dispose();
      }
      final external = widget.conversationSearchController;
      if (external != null) {
        _searchController = external;
        _ownsSearchController = false;
      } else {
        _searchController = TextEditingController();
        _ownsSearchController = true;
      }
      _query = _searchController.text.trim();
      _searchController.addListener(_handleSearchChange);
    }
    final live = _startNewChatSheetLive;
    if (live != null) {
      final next = _buildStartNewChatSheetLiveData();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _startNewChatSheetLive != live) {
          return;
        }
        live.value = next;
      });
    }
  }

  @override
  void dispose() {
    _startNewChatSheetLive = null;
    _searchController.removeListener(_handleSearchChange);
    if (_ownsSearchController) {
      _searchController.dispose();
    }
    super.dispose();
  }

  void _handleSearchChange() {
    if (!mounted) {
      return;
    }
    setState(() => _query = _searchController.text.trim());
  }

  MessengerConversation? _conversationForId(String? id) {
    if (id == null) {
      return null;
    }
    for (final c in widget.conversations) {
      if (c.id == id) {
        return c;
      }
    }
    return null;
  }

  bool _peerEntryShowsOnlinePresence(_PeerListEntry entry) {
    if (!entry.isConversationRow) {
      return true;
    }
    final conversation = _conversationForId(entry.conversationId);
    return conversation != null && !conversation.isGroup;
  }

  bool get _hasPeerUsers => widget.conversations
      .any((conversation) => conversation.peerUsers.isNotEmpty);

  int _uniquePeerCount() {
    if (!_hasPeerUsers) {
      return widget.users.length;
    }
    final ids = <String>{};
    for (final c in widget.conversations) {
      for (final u in c.peerUsers) {
        ids.add(u.id);
      }
    }
    return ids.length;
  }

  DateTime _activityAt(MessengerConversation conversation) {
    return conversation.effectiveActivityAt;
  }

  /// Promoted rows first (newer [MessengerConversation.promotedAt] first);
  /// otherwise newest activity wins, with [MessengerConversation.apiRank] only
  /// used as a stable tie-breaker.
  int _compareConversationsByOrder(
    MessengerConversation left,
    MessengerConversation right,
  ) {
    final leftHot = left.promotedAt != null;
    final rightHot = right.promotedAt != null;
    if (leftHot != rightHot) {
      return leftHot ? -1 : 1;
    }
    if (leftHot && rightHot) {
      final t = right.promotedAt!.compareTo(left.promotedAt!);
      if (t != 0) {
        return t;
      }
      return left.id.compareTo(right.id);
    }
    final activityCompare = _activityAt(right).compareTo(_activityAt(left));
    if (activityCompare != 0) {
      return activityCompare;
    }
    final ar = left.apiRank;
    final br = right.apiRank;
    if (ar != null && br != null && ar != br) {
      return ar.compareTo(br);
    }
    if (ar != null && br == null) {
      return -1;
    }
    if (ar == null && br != null) {
      return 1;
    }
    return left.id.compareTo(right.id);
  }

  List<MessengerConversation> _conversationsByActivity() {
    final ordered = [...widget.conversations];
    ordered.sort(_compareConversationsByOrder);
    return ordered;
  }

  List<_PeerListEntry> _orderedPeerEntries() {
    if (!_hasPeerUsers) {
      return _legacyUserEntries();
    }

    final orderedConversations = _conversationsByActivity();
    final selected = _conversationForId(widget.selectedConversationId);
    final entries = <_PeerListEntry>[];
    final seen = <String>{};
    void addPeers(MessengerConversation c, Iterable<MessengerUser> peers) {
      final preview = _previewForConversation(c);
      for (final u in peers) {
        final uid = u.id.trim();
        if (uid.isEmpty || !seen.add(uid)) {
          continue;
        }
        entries.add(
          _PeerListEntry(
            user: u,
            messagePreview: preview,
            hasUnread: c.unreadCount > 0,
            isInSelectedConversation:
                selected != null && selected.peerUsers.any((p) => p.id == u.id),
            conversationId: c.id.trim(),
          ),
        );
      }
    }

    for (final c in orderedConversations) {
      final preview = _previewForConversation(c);
      if (_shouldRenderAsConversationRow(c)) {
        entries.add(
          _PeerListEntry(
            user: _conversationRowUser(c),
            messagePreview: preview,
            hasUnread: c.unreadCount > 0,
            isInSelectedConversation: selected?.id == c.id,
            isConversationRow: true,
            useGroupAvatar: c.isGroup,
            groupAvatarUsers: c.isGroup ? c.peerUsers : const [],
            conversationId: c.id.trim(),
          ),
        );
      } else {
        addPeers(c, c.peerUsers);
      }
    }
    return entries;
  }

  bool _shouldRenderAsConversationRow(MessengerConversation conversation) {
    if (conversation.isGlobal || conversation.isGroup) {
      return true;
    }
    return conversation.peerUsers.length > 1;
  }

  String _previewForConversation(MessengerConversation conversation) {
    return conversation.previewSubtitle(currentUserId: widget.currentUserId);
  }

  MessengerUser _conversationRowUser(MessengerConversation conversation) {
    final title = conversation.title.trim().isEmpty
        ? conversation.avatarLabel.trim()
        : conversation.title.trim();
    return MessengerUser(
      id: '__conversation__:${conversation.id}',
      username: title.isEmpty ? 'Conversation' : title,
      roleLabel: conversation.isGlobal ? 'Support' : '',
      isOnline: false,
      avatarUrl: conversation.avatarUrl,
    );
  }

  List<_PeerListEntry> _legacyUserEntries() {
    final users = [...widget.users];
    final selected = _conversationForId(widget.selectedConversationId);
    final orderedConversations = _conversationsByActivity();
    final matchedConversationByUser = <String, MessengerConversation?>{};

    MessengerConversation? matchForUser(MessengerUser user) {
      return matchedConversationByUser.putIfAbsent(
        user.id,
        () => _legacyConversationForUser(user, orderedConversations),
      );
    }

    users.sort((left, right) {
      final leftConversation = matchForUser(left);
      final rightConversation = matchForUser(right);
      if (leftConversation != null && rightConversation != null) {
        final compare =
            _compareConversationsByOrder(leftConversation, rightConversation);
        if (compare != 0) {
          return compare;
        }
      } else if (leftConversation != null || rightConversation != null) {
        return leftConversation != null ? -1 : 1;
      }

      if (left.isOnline != right.isOnline) {
        return left.isOnline ? -1 : 1;
      }
      return left.username
          .toLowerCase()
          .compareTo(right.username.toLowerCase());
    });

    return users
        .map(
          (user) => _PeerListEntry(
            user: user,
            messagePreview: _legacyPreviewForUser(user),
            hasUnread: _legacyHasUnreadForUser(user),
            isInSelectedConversation: selected != null &&
                _legacyConversationMatchesUser(selected, user),
            conversationId: matchForUser(user)?.id,
          ),
        )
        .toList(growable: false);
  }

  bool _legacyConversationMatchesUser(
    MessengerConversation conversation,
    MessengerUser user,
  ) {
    final username = user.username.toLowerCase();
    final title = conversation.title.toLowerCase();
    final subtitle = _previewForConversation(conversation).toLowerCase();
    final display = conversationListItemDisplayName(user.username).toLowerCase();
    return title.contains(username) ||
        title.contains(display) ||
        subtitle.contains(username) ||
        subtitle.contains(display);
  }

  MessengerConversation? _legacyConversationForUser(
    MessengerUser user,
    List<MessengerConversation> orderedConversations,
  ) {
    for (final conversation in orderedConversations) {
      if (_legacyConversationMatchesUser(conversation, user)) {
        return conversation;
      }
    }
    return null;
  }

  String _legacyPreviewForUser(MessengerUser user) {
    for (final conversation in _conversationsByActivity()) {
      if (_legacyConversationMatchesUser(conversation, user)) {
        return _previewForConversation(conversation);
      }
    }
    return '';
  }

  bool _legacyHasUnreadForUser(MessengerUser user) {
    for (final conversation in _conversationsByActivity()) {
      if (conversation.unreadCount == 0) {
        continue;
      }
      if (_legacyConversationMatchesUser(conversation, user)) {
        return true;
      }
    }
    return false;
  }

  List<_PeerListEntry> _filterPeerEntries(List<_PeerListEntry> entries) {
    if (_query.isEmpty) {
      return entries;
    }
    final queryLower = _query.toLowerCase();
    return entries
        .where(
          (e) =>
              e.user.username.toLowerCase().contains(queryLower) ||
              e.user.roleLabel.toLowerCase().contains(queryLower) ||
              e.user.id.toLowerCase().contains(queryLower) ||
              e.messagePreview.toLowerCase().contains(queryLower),
        )
        .toList(growable: false);
  }

  Future<void> _onPeerListEntryTap(_PeerListEntry entry) async {
    final convId = entry.conversationId;
    if (convId != null && convId.trim().isNotEmpty) {
      await widget.onSelectConversation(convId);
      return;
    }
    await widget.onOpenDirectChat(entry.user);
  }

  Widget _buildMainUserListItem(BuildContext context, _PeerListEntry entry) {
    final showOnlinePresence = _peerEntryShowsOnlinePresence(entry);
    final messagePreview =
        entry.messagePreview.isEmpty ? null : entry.messagePreview;
    final data = MessengerUserListItemData(
      user: entry.user,
      isSelected: entry.isInSelectedConversation,
      hasUnread: entry.hasUnread,
      isOpening: _isDirectOpenBusyForUser(
        widget.openingDirectUserId,
        entry.user.id,
      ),
      messagePreview: messagePreview,
      onTap: () {
        unawaited(_onPeerListEntryTap(entry));
      },
      conversationId: entry.conversationId,
      isConversationRow: entry.isConversationRow,
      useGroupAvatar: entry.useGroupAvatar,
      groupAvatarUsers: entry.groupAvatarUsers,
      showOnlinePresence: showOnlinePresence,
      displayTitle: conversationListItemDisplayName(entry.user.username),
      subtitle: conversationListItemSubtitle(
        user: entry.user,
        messagePreview: messagePreview,
        showOnlinePresence: showOnlinePresence,
      ),
      roleLabel: entry.user.roleLabel.trim(),
    );

    final builder = widget.userListItemBuilder;
    if (builder != null) {
      return builder(context, data);
    }

    return MessengerConversationListItem(
      data: data,
      style: widget.userListItemStyle,
    );
  }

  Widget? _buildHeaderRow(BuildContext context) {
    final showAny = widget.showHeaderEditButton ||
        widget.showHeaderTitle ||
        widget.showHeaderComposeButton;
    if (!showAny) {
      return null;
    }
    final theme = MessengerTheme.of(context);
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: widget.showHeaderEditButton
                ? TextButton(
                    onPressed: () => unawaited(widget.onRefresh()),
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        color: theme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        if (widget.showHeaderTitle)
          const Expanded(
            flex: 2,
            child: Text(
              'Chats',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          )
        else
          const Spacer(flex: 2),
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerRight,
            child: widget.showHeaderComposeButton
                ? IconButton(
                    onPressed: () => _openDirectPicker(context),
                    icon: Icon(Icons.edit_square, color: theme.primary),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final searchBg =
        widget.searchFieldBackgroundColor ?? const Color(0xFFF3F4F6);
    final searchIconColor = widget.searchIconColor ?? theme.mutedText;
    final searchHintStyle =
        widget.searchHintTextStyle ?? TextStyle(color: theme.mutedText);
    final searchContentPadding = widget.searchFieldContentPadding;
    final searchRadius = widget.searchFieldBorderRadius ?? 12;
    final showSearch = _shouldShowSearch();
    final ordered = _orderedPeerEntries();
    final filteredEntries = _filterPeerEntries(ordered);
    final headerRow = _buildHeaderRow(context);

    final listContent = Column(
      children: [
        const SizedBox(height: 2),
        if (headerRow != null) ...[
          headerRow,
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 10),
        if (showSearch) ...[
          MessengerListSearchField(
            controller: _searchController,
            hintText: widget.searchHintText,
            hintStyle: searchHintStyle,
            inputTextStyle: widget.searchInputTextStyle,
            backgroundColor: searchBg,
            iconColor: searchIconColor,
            borderRadius: searchRadius,
            contentPadding: searchContentPadding,
            onClear: () => _searchController.clear(),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: widget.isConversationListLoading
              ? KeyedSubtree(
                  key: const ValueKey('conversationListLoading'),
                  child: widget.conversationListLoadingBuilder?.call(context) ??
                      const MessengerDefaultInlineLoading(),
                )
              : _buildPeerScrollBody(context, filteredEntries),
        ),
      ],
    );

    final content = widget.isMobile
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: listContent,
          )
        : Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: listContent,
          );

    if (!widget.showStartChatFab) {
      return content;
    }

    final fabBg = widget.fabBackgroundColor ?? theme.primary;
    final fabFg = widget.fabForegroundColor ?? Colors.white;
    final fabIcon = widget.fabIcon ?? Icons.add_rounded;
    final heroTag = widget.fabHeroTag ??
        (widget.isMobile ? 'startChatMobile' : 'startChatDesktop');

    return Stack(
      children: [
        content,
        Positioned(
          right: widget.isMobile ? 16 : 20,
          bottom: widget.isMobile ? 24 : 18,
          child: FloatingActionButton(
            heroTag: heroTag,
            onPressed: () => _openDirectPicker(context),
            backgroundColor: fabBg,
            child: Icon(fabIcon, color: fabFg),
          ),
        ),
      ],
    );
  }

  Future<void> _onPullRefresh() => widget.onRefresh();

  Widget _buildPeerScrollBody(
    BuildContext context,
    List<_PeerListEntry> filteredEntries,
  ) {
    final Widget scrollable;
    if (filteredEntries.isEmpty) {
      final emptyBody = _query.isNotEmpty
          ? _buildSearchNoResultsPeerList(context)
          : _buildEmptyPeerList(context);
      scrollable = LayoutBuilder(
        builder: (ctx, constraints) => SingleChildScrollView(
          physics: widget.enablePullToRefresh
              ? const AlwaysScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: emptyBody,
          ),
        ),
      );
    } else {
      final listPadding = _effectiveUserListPadding(context);
      scrollable = ListView.separated(
        primary: false,
        physics: widget.enablePullToRefresh
            ? const AlwaysScrollableScrollPhysics()
            : null,
        padding: listPadding,
        itemCount: filteredEntries.length,
        separatorBuilder: (_, __) =>
            SizedBox(height: widget.userListItemSpacing),
        itemBuilder: (context, index) {
          final entry = filteredEntries[index];
          return _buildMainUserListItem(context, entry);
        },
      );
    }

    if (!widget.enablePullToRefresh) {
      return scrollable;
    }
    return RefreshIndicator(
      onRefresh: _onPullRefresh,
      child: scrollable,
    );
  }

  EdgeInsetsGeometry _effectiveUserListPadding(BuildContext context) {
    final basePadding = widget.userListPadding ?? EdgeInsets.zero;
    if (!widget.showStartChatFab) {
      return basePadding;
    }
    return basePadding.add(
      EdgeInsets.only(bottom: _fabScrollClearance(context)),
    );
  }

  double _fabScrollClearance(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final fabBottomOffset = widget.isMobile ? 24.0 : 18.0;
    const fabDiameter = 56.0;
    const visualGap = 12.0;
    return safeBottom + fabBottomOffset + fabDiameter + visualGap;
  }

  Future<void> _openDirectPicker(BuildContext context) {
    return presentStartNewChat(
      context,
      mode: MessengerStartNewChatMode.direct,
    );
  }

  /// Opens the start-new-chat picker programmatically (direct or group mode).
  Future<void> presentStartNewChat(
    BuildContext context, {
    MessengerStartNewChatMode mode = MessengerStartNewChatMode.direct,
  }) async {
    final theme = MessengerTheme.of(context);
    final searchBg =
        widget.searchFieldBackgroundColor ?? const Color(0xFFF3F4F6);
    final searchIconColor = widget.searchIconColor ?? theme.mutedText;
    final searchHintStyle =
        widget.searchHintTextStyle ?? TextStyle(color: theme.mutedText);
    final searchContentPadding = widget.searchFieldContentPadding;
    final searchRadius = widget.searchFieldBorderRadius ?? 12;
    final topSafeInset =
        MediaQueryData.fromView(View.of(context)).padding.top;

    widget.startNewChatDirectory?.onSearchQueryDebounced?.call('');

    _startNewChatSheetLive?.dispose();
    final sheetLive = ValueNotifier(_buildStartNewChatSheetLiveData());
    _startNewChatSheetLive = sheetLive;

    Widget buildPicker() {
      return MessengerStartNewChatPicker(
        sheetLive: sheetLive,
        topSafeInset: topSafeInset,
        searchBackgroundColor: searchBg,
        searchIconColor: searchIconColor,
        searchHintStyle: searchHintStyle,
        searchContentPadding: searchContentPadding,
        searchBorderRadius: searchRadius,
        searchInputTextStyle: widget.searchInputTextStyle,
        searchHintText: widget.searchHintText,
        emptyUsersBuilder: widget.emptyUsersBuilder,
        emptyUsersMessage: widget.emptyUsersMessage,
        onOpenDirectChat: widget.onOpenDirectChat,
        onCreateGroupSelected: widget.onCreateGroupSelected,
        onCreateGroupRequested: widget.onCreateGroupRequested,
        groupNameInputBehavior: widget.groupNameInputBehavior,
        groupNameFieldLabelText: widget.groupNameFieldLabelText,
        groupNameFieldHintText: widget.groupNameFieldHintText,
        groupNameRequiredErrorText: widget.groupNameRequiredErrorText,
        defaultGroupNameWhenEmpty: widget.defaultGroupNameWhenEmpty,
        groupMinSelectionCount: widget.groupMinSelectionCount,
        startNewChatDirectory: widget.startNewChatDirectory,
        initialMode: mode,
        groupSelectionListMode: widget.groupSelectionListMode,
        userItemBuilder: widget.startNewChatUserItemBuilder,
        selectedUsersSectionBuilder: widget.selectedUsersSectionBuilder,
      );
    }

    try {
      await presentMessengerStartNewChat(
        context: context,
        mode: mode,
        buildPicker: buildPicker,
        presenter: widget.startNewChatPresenter,
        topSafeInset: topSafeInset,
      );
    } finally {
      widget.startNewChatDirectory?.onSearchQueryDebounced?.call('');
      if (identical(_startNewChatSheetLive, sheetLive)) {
        _startNewChatSheetLive = null;
      }
    }
  }

  bool _shouldShowSearch() {
    if (widget.conversationSearchController != null) {
      return false;
    }
    switch (widget.searchVisibility) {
      case MessengerSearchVisibility.always:
        return true;
      case MessengerSearchVisibility.never:
        return false;
      case MessengerSearchVisibility.auto:
        return _uniquePeerCount() > widget.searchThreshold;
    }
  }

  Widget _buildEmptyPeerList(BuildContext context) {
    if (widget.startNewChatEmptyBuilder != null) {
      return widget.startNewChatEmptyBuilder!(context);
    }
    if (widget.emptyConversationsBuilder != null) {
      return widget.emptyConversationsBuilder!(context);
    }
    final theme = MessengerTheme.of(context);
    return Semantics(
      container: true,
      label: 'Start new chat',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.emptyConversationsMessage,
                style: TextStyle(
                  color: theme.subtleText,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Tap + to start a new chat.',
                style: TextStyle(
                  color: theme.mutedText,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _conversationSearchNoResultsText() {
    return widget.conversationSearchNoResultsMessage.replaceAll(
      '{query}',
      _query,
    );
  }

  Widget _buildSearchNoResultsPeerList(BuildContext context) {
    final builder = widget.conversationSearchNoResultsBuilder;
    if (builder != null) {
      return Center(child: builder(context, _query));
    }
    final theme = MessengerTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          _conversationSearchNoResultsText(),
          style: TextStyle(
            color: theme.subtleText,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
