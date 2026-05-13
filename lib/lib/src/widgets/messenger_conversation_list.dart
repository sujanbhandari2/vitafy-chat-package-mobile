import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messenger_conversation.dart';
import '../models/messenger_group_create_request.dart';
import '../models/messenger_search_visibility.dart';
import '../models/messenger_user.dart';
import '../theme/messenger_theme.dart';
import 'messenger_avatar.dart';
import 'messenger_default_inline_loading.dart';
import 'messenger_group_name_text_field.dart';
import 'messenger_list_search_field.dart';

/// Avoid treating every row as "opening" when both ids are empty (`'' == ''`).
bool _isDirectOpenBusyForUser(String openingDirectUserId, String userId) {
  final open = openingDirectUserId.trim();
  return open.isNotEmpty && open == userId.trim();
}

class MessengerUserListItemStyle {
  const MessengerUserListItemStyle({
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    this.backgroundColor,
    this.selectedBackgroundColor,
    this.border,
    this.selectedBorder,
    this.borderRadius = 12,
    this.boxShadow,
    this.titleStyle,
    this.subtitleStyle,
    this.trailingIconColor,
    this.unreadDotColor,
  });

  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? selectedBackgroundColor;
  final BorderSide? border;
  final BorderSide? selectedBorder;
  final double borderRadius;
  final List<BoxShadow>? boxShadow;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color? trailingIconColor;
  final Color? unreadDotColor;
}

class MessengerUserListItemData {
  const MessengerUserListItemData({
    required this.user,
    required this.isSelected,
    required this.hasUnread,
    required this.isOpening,
    required this.messagePreview,
    required this.onTap,
  });

  final MessengerUser user;
  final bool isSelected;
  final bool hasUnread;
  final bool isOpening;
  final String? messagePreview;
  final VoidCallback onTap;
}

class MessengerConversationList extends StatefulWidget {
  const MessengerConversationList({
    super.key,
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
    this.searchThreshold = 10,
    this.searchHintText = 'Search',
    this.emptyUsersMessage = 'No users available right now.',
    this.emptyConversationsMessage = 'No conversations available yet.',
    this.emptyUsersBuilder,
    this.emptyConversationsBuilder,
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
  });

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
  final int searchThreshold;
  final String searchHintText;
  final String emptyUsersMessage;
  final String emptyConversationsMessage;
  final WidgetBuilder? emptyUsersBuilder;
  final WidgetBuilder? emptyConversationsBuilder;
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

  @override
  State<MessengerConversationList> createState() =>
      _MessengerConversationListState();
}

class _PeerListEntry {
  const _PeerListEntry({
    required this.user,
    required this.messagePreview,
    required this.hasUnread,
    required this.isInSelectedConversation,
    this.isConversationRow = false,
    this.conversationId,
  });

  final MessengerUser user;
  final String messagePreview;
  final bool hasUnread;
  final bool isInSelectedConversation;
  final bool isConversationRow;

  /// When known (peer came from a conversation row), open via [MessengerConversationList.onSelectConversation].
  final String? conversationId;
}

/// Live snapshot for the Start New Chat modal while it is open — updated from
/// [MessengerConversationList.didUpdateWidget] so hosts can finish loading
/// users after the sheet is shown.
class _StartNewChatSheetLiveData {
  const _StartNewChatSheetLiveData({
    required this.sortedUsers,
    required this.isUsersLoading,
    required this.openingDirectUserId,
    required this.isCreatingGroup,
  });

  final List<MessengerUser> sortedUsers;
  final bool isUsersLoading;
  final String openingDirectUserId;
  final bool isCreatingGroup;
}

class _MessengerConversationListState extends State<MessengerConversationList> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  ValueNotifier<_StartNewChatSheetLiveData>? _startNewChatSheetLive;

  List<MessengerUser> _sortedUsersForStartNewChatSheet() {
    final sorted = [...widget.users]..sort((a, b) {
        if (a.isOnline == b.isOnline) {
          return a.username.toLowerCase().compareTo(b.username.toLowerCase());
        }
        return a.isOnline ? -1 : 1;
      });
    return sorted;
  }

  _StartNewChatSheetLiveData _buildStartNewChatSheetLiveData() {
    return _StartNewChatSheetLiveData(
      sortedUsers: _sortedUsersForStartNewChatSheet(),
      isUsersLoading: widget.startNewChatUsersLoading,
      openingDirectUserId: widget.openingDirectUserId,
      isCreatingGroup: widget.isCreatingGroup,
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void didUpdateWidget(covariant MessengerConversationList oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _startNewChatSheetLive?.dispose();
    _startNewChatSheetLive = null;
    _searchController.removeListener(_handleSearchChange);
    _searchController.dispose();
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
      for (final u in peers) {
        final uid = u.id.trim();
        if (uid.isEmpty || !seen.add(uid)) {
          continue;
        }
        entries.add(
          _PeerListEntry(
            user: u,
            messagePreview: c.subtitle,
            hasUnread: c.unreadCount > 0,
            isInSelectedConversation:
                selected != null && selected.peerUsers.any((p) => p.id == u.id),
            conversationId: c.id.trim(),
          ),
        );
      }
    }

    for (final c in orderedConversations) {
      if (_shouldRenderAsConversationRow(c)) {
        entries.add(
          _PeerListEntry(
            user: _conversationRowUser(c),
            messagePreview: c.subtitle,
            hasUnread: c.unreadCount > 0,
            isInSelectedConversation: selected?.id == c.id,
            isConversationRow: true,
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
    final subtitle = conversation.subtitle.toLowerCase();
    final display = _displayName(user.username).toLowerCase();
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
        return conversation.subtitle;
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
    final data = MessengerUserListItemData(
      user: entry.user,
      isSelected: entry.isInSelectedConversation,
      hasUnread: entry.hasUnread,
      isOpening: _isDirectOpenBusyForUser(
        widget.openingDirectUserId,
        entry.user.id,
      ),
      messagePreview:
          entry.messagePreview.isEmpty ? null : entry.messagePreview,
      onTap: () {
        unawaited(_onPeerListEntryTap(entry));
      },
    );

    final builder = widget.userListItemBuilder;
    if (builder != null) {
      return builder(context, data);
    }

    return _DirectUserTile(
      user: data.user,
      isOpening: data.isOpening,
      onTap: data.onTap,
      showChatButton: false,
      isSelected: data.isSelected,
      messagePreview: data.messagePreview,
      hasUnread: data.hasUnread,
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
        widget.searchFieldBackgroundColor ?? theme.searchBackground;
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
      scrollable = LayoutBuilder(
        builder: (ctx, constraints) => SingleChildScrollView(
          physics: widget.enablePullToRefresh
              ? const AlwaysScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: _buildEmptyPeerList(context),
          ),
        ),
      );
    } else {
      scrollable = ListView.separated(
        primary: false,
        physics: widget.enablePullToRefresh
            ? const AlwaysScrollableScrollPhysics()
            : null,
        padding: widget.userListPadding,
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

  Future<void> _openDirectPicker(BuildContext context) async {
    final theme = MessengerTheme.of(context);
    final searchBg =
        widget.searchFieldBackgroundColor ?? theme.searchBackground;
    final searchIconColor = widget.searchIconColor ?? theme.mutedText;
    final searchHintStyle =
        widget.searchHintTextStyle ?? TextStyle(color: theme.mutedText);
    final searchContentPadding = widget.searchFieldContentPadding;
    final searchRadius = widget.searchFieldBorderRadius ?? 12;

    _startNewChatSheetLive?.dispose();
    _startNewChatSheetLive = ValueNotifier(_buildStartNewChatSheetLiveData());

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => _StartNewChatBottomSheet(
          sheetLive: _startNewChatSheetLive!,
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
        ),
      );
    } finally {
      _startNewChatSheetLive?.dispose();
      _startNewChatSheetLive = null;
    }
  }

  bool _shouldShowSearch() {
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
}

class _StartNewChatBottomSheet extends StatefulWidget {
  const _StartNewChatBottomSheet({
    required this.sheetLive,
    required this.searchBackgroundColor,
    required this.searchIconColor,
    required this.searchHintStyle,
    required this.searchContentPadding,
    required this.searchBorderRadius,
    required this.searchInputTextStyle,
    required this.searchHintText,
    required this.emptyUsersBuilder,
    required this.emptyUsersMessage,
    required this.onOpenDirectChat,
    this.onCreateGroupSelected,
    this.onCreateGroupRequested,
    this.groupNameInputBehavior = MessengerGroupNameInputBehavior.hidden,
    this.groupNameFieldLabelText = 'Group name',
    this.groupNameFieldHintText = 'Enter a group name',
    this.groupNameRequiredErrorText = 'Enter a group name to continue.',
  });

  final ValueNotifier<_StartNewChatSheetLiveData> sheetLive;
  final Color searchBackgroundColor;
  final Color searchIconColor;
  final TextStyle searchHintStyle;
  final EdgeInsetsGeometry? searchContentPadding;
  final double searchBorderRadius;
  final TextStyle? searchInputTextStyle;
  final String searchHintText;
  final WidgetBuilder? emptyUsersBuilder;
  final String emptyUsersMessage;
  final FutureOr<void> Function(MessengerUser user) onOpenDirectChat;
  final FutureOr<void> Function(List<MessengerUser> selectedUsers)?
      onCreateGroupSelected;
  final FutureOr<void> Function(MessengerGroupCreateRequest request)?
      onCreateGroupRequested;
  final MessengerGroupNameInputBehavior groupNameInputBehavior;
  final String groupNameFieldLabelText;
  final String groupNameFieldHintText;
  final String groupNameRequiredErrorText;

  @override
  State<_StartNewChatBottomSheet> createState() =>
      _StartNewChatBottomSheetState();
}

class _StartNewChatBottomSheetState extends State<_StartNewChatBottomSheet> {
  late final TextEditingController _searchController;
  late final TextEditingController _groupNameController;
  String _query = '';
  bool _isGroupSelectionMode = false;
  List<String> _selectedUserIds = const <String>[];
  String? _groupNameErrorText;

  bool get _canCreateGroup =>
      widget.onCreateGroupSelected != null ||
      widget.onCreateGroupRequested != null;
  bool get _showGroupNameField =>
      widget.groupNameInputBehavior != MessengerGroupNameInputBehavior.hidden;
  bool get _groupNameIsRequired =>
      widget.groupNameInputBehavior == MessengerGroupNameInputBehavior.required;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _groupNameController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_StartNewChatSheetLiveData>(
      valueListenable: widget.sheetLive,
      builder: (context, data, _) => _buildSheet(context, data),
    );
  }

  Widget _buildSheet(BuildContext context, _StartNewChatSheetLiveData data) {
    final q = _query.toLowerCase();
    final filteredUsers = _query.isEmpty
        ? data.sortedUsers
        : data.sortedUsers
            .where(
              (user) =>
                  user.username.toLowerCase().contains(q) ||
                  user.roleLabel.toLowerCase().contains(q) ||
                  user.id.toLowerCase().contains(q),
            )
            .toList(growable: false);
    final selectedUsers = _selectedUsersFrom(data.sortedUsers);
    final visibleUsers = _isGroupSelectionMode
        ? filteredUsers
            .where((user) => !_selectedUserIds.contains(user.id.trim()))
            .toList(growable: false)
        : filteredUsers;

    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenH = MediaQuery.sizeOf(context).height;
    final maxSheetHeight = screenH * 0.88;
    final theme = MessengerTheme.of(context);
    final groupBusy = data.isCreatingGroup;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Start New Chat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_canCreateGroup)
                      TextButton(
                        onPressed: groupBusy ? null : _toggleGroupMode,
                        style: TextButton.styleFrom(
                          foregroundColor: _isGroupSelectionMode
                              ? Colors.white
                              : theme.primary,
                          backgroundColor: _isGroupSelectionMode
                              ? theme.primary
                              : theme.primary.withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          _isGroupSelectionMode ? 'Group mode' : 'New group',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_isGroupSelectionMode) ...[
                  if (_showGroupNameField) ...[
                    const SizedBox(height: 12),
                    MessengerGroupNameTextField(
                      controller: _groupNameController,
                      enabled: !groupBusy,
                      labelText: widget.groupNameFieldLabelText,
                      hintText: widget.groupNameFieldHintText,
                      backgroundColor: widget.searchBackgroundColor,
                      borderRadius: widget.searchBorderRadius,
                      contentPadding: widget.searchContentPadding,
                      iconColor: widget.searchIconColor,
                      hintStyle: widget.searchHintStyle,
                      inputTextStyle: widget.searchInputTextStyle,
                      errorText: _groupNameErrorText,
                      onChanged: (_) {
                        if (_groupNameErrorText == null || !mounted) {
                          return;
                        }
                        setState(() => _groupNameErrorText = null);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildSelectedUsersCard(theme, selectedUsers, groupBusy),
                ],
                const SizedBox(height: 10),
                MessengerListSearchField(
                  controller: _searchController,
                  hintText: widget.searchHintText,
                  hintStyle: widget.searchHintStyle,
                  inputTextStyle: widget.searchInputTextStyle,
                  backgroundColor: widget.searchBackgroundColor,
                  iconColor: widget.searchIconColor,
                  borderRadius: widget.searchBorderRadius,
                  contentPadding: widget.searchContentPadding,
                  onChanged: (value) => setState(() {
                    _query = value.trim().toLowerCase();
                  }),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
                if (_isGroupSelectionMode) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: groupBusy ? null : _resetGroupMode,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.subtleText,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: !groupBusy && selectedUsers.length >= 2
                            ? () => _submitGroupSelection(selectedUsers)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              groupBusy ? theme.primary : theme.border,
                          disabledForegroundColor:
                              groupBusy ? Colors.white : theme.subtleText,
                        ),
                        child: groupBusy
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color:
                                          Colors.white.withValues(alpha: 0.95),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Creating…',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Create group',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Expanded(
                  child: data.isUsersLoading && visibleUsers.isEmpty
                      ? const MessengerDefaultInlineLoading()
                      : visibleUsers.isEmpty
                          ? Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: _isGroupSelectionMode
                                    ? Text(
                                        _query.isEmpty
                                            ? 'No more people available to add right now.'
                                            : 'No people match your search.',
                                        style:
                                            TextStyle(color: theme.subtleText),
                                      )
                                    : widget.emptyUsersBuilder?.call(context) ??
                                        Text(
                                          widget.emptyUsersMessage,
                                          style: TextStyle(
                                              color: theme.subtleText),
                                        ),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: visibleUsers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final user = visibleUsers[index];
                                return _DirectUserTile(
                                  user: user,
                                  isOpening: !_isGroupSelectionMode &&
                                      _isDirectOpenBusyForUser(
                                        data.openingDirectUserId,
                                        user.id,
                                      ),
                                  onTap: _isGroupSelectionMode
                                      ? () => _addSelectedUser(user)
                                      : () {
                                          final open = widget.onOpenDirectChat;
                                          final u = user;
                                          Navigator.of(context).pop();
                                          open(u);
                                        },
                                  showChatButton: true,
                                  actionLabel:
                                      _isGroupSelectionMode ? 'Add' : 'Chat',
                                  isSelected: false,
                                  messagePreview: null,
                                  hasUnread: false,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleGroupMode() {
    if (_isGroupSelectionMode) {
      _resetGroupMode();
      return;
    }
    setState(() {
      _isGroupSelectionMode = true;
      _selectedUserIds = const <String>[];
      _groupNameErrorText = null;
    });
  }

  void _resetGroupMode() {
    setState(() {
      _isGroupSelectionMode = false;
      _selectedUserIds = const <String>[];
      _groupNameErrorText = null;
    });
    _groupNameController.clear();
  }

  void _addSelectedUser(MessengerUser user) {
    final id = user.id.trim();
    if (id.isEmpty || _selectedUserIds.contains(id)) {
      return;
    }
    setState(() {
      _selectedUserIds = [..._selectedUserIds, id];
    });
  }

  void _removeSelectedUser(String userId) {
    setState(() {
      _selectedUserIds = _selectedUserIds
          .where((id) => id.trim() != userId.trim())
          .toList(growable: false);
    });
  }

  List<MessengerUser> _selectedUsersFrom(List<MessengerUser> sortedUsers) {
    final byId = <String, MessengerUser>{
      for (final user in sortedUsers) user.id.trim(): user,
    };
    return _selectedUserIds
        .map((id) => byId[id.trim()])
        .whereType<MessengerUser>()
        .toList(growable: false);
  }

  Future<void> _submitGroupSelection(List<MessengerUser> selectedUsers) async {
    final requestCallback = widget.onCreateGroupRequested;
    final callback = widget.onCreateGroupSelected;
    if ((requestCallback == null && callback == null) ||
        selectedUsers.length < 2 ||
        widget.sheetLive.value.isCreatingGroup) {
      return;
    }
    final trimmedGroupName = _groupNameController.text.trim();
    if (_groupNameIsRequired && trimmedGroupName.isEmpty) {
      setState(() => _groupNameErrorText = widget.groupNameRequiredErrorText);
      return;
    }
    try {
      if (requestCallback != null) {
        await requestCallback(
          MessengerGroupCreateRequest(
            selectedUsers: selectedUsers,
            groupName: trimmedGroupName,
          ),
        );
      } else if (callback != null) {
        await callback(selectedUsers);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      // Host surfaces the failure; keep the sheet open so selection stays intact.
    }
  }

  Widget _buildSelectedUsersCard(
    MessengerThemeData theme,
    List<MessengerUser> selectedUsers,
    bool isCreatingGroup,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.searchBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected people (${selectedUsers.length})',
            style: TextStyle(
              color: theme.bubbleOtherText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (selectedUsers.isEmpty)
            Text(
              'No people selected yet.',
              style: TextStyle(
                color: theme.subtleText,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedUsers
                  .map(
                    (user) => _SelectedBottomSheetUserChip(
                      user: user,
                      onRemove: isCreatingGroup
                          ? null
                          : () => _removeSelectedUser(user.id),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _SelectedBottomSheetUserChip extends StatelessWidget {
  const _SelectedBottomSheetUserChip({
    required this.user,
    required this.onRemove,
  });

  final MessengerUser user;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              _displayName(user.username),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.bubbleOtherText,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: onRemove == null ? theme.mutedText : theme.subtleText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectUserTile extends StatelessWidget {
  const _DirectUserTile({
    required this.user,
    required this.isOpening,
    required this.onTap,
    required this.showChatButton,
    this.actionLabel = 'Chat',
    required this.isSelected,
    required this.hasUnread,
    this.messagePreview,
    this.style = const MessengerUserListItemStyle(),
  });

  final MessengerUser user;
  final bool isOpening;
  final VoidCallback onTap;
  final bool showChatButton;
  final String actionLabel;
  final bool isSelected;
  final bool hasUnread;
  final String? messagePreview;
  final MessengerUserListItemStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final preview = messagePreview;
    final subtitle = preview != null && preview.isNotEmpty
        ? preview
        : '${user.roleLabel}${user.roleLabel.isNotEmpty ? ' • ' : ''}${user.isOnline ? 'Online' : 'Offline'}';
    final titleStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13.5,
    ).merge(style.titleStyle);
    final subtitleStyle = TextStyle(
      color: hasUnread ? const Color(0xFF374151) : theme.subtleText,
      fontSize: 11.5,
      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
    ).merge(style.subtitleStyle);
    final defaultBorder = BorderSide(color: theme.border);
    final tile = Container(
      margin: style.margin,
      decoration: BoxDecoration(
        color: style.backgroundColor ?? const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(style.borderRadius),
        border: Border.fromBorderSide(style.border ?? defaultBorder),
        boxShadow: style.boxShadow,
      ),
      padding: style.padding,
      child: Row(
        children: [
          MessengerAvatar(
            label: _initials(user.username),
            imageUrl: user.avatarUrl,
            compact: true,
            size: 34,
            showOnlineIndicator: true,
            isOnline: user.isOnline,
            presenceDotColor: hasUnread
                ? (style.unreadDotColor ?? theme.onlineIndicator)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName(user.username),
                  style: titleStyle,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: subtitleStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showChatButton)
            FilledButton(
              onPressed: isOpening ? null : onTap,
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                visualDensity:
                    const VisualDensity(horizontal: -4, vertical: -4),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(isOpening ? '...' : actionLabel),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: style.trailingIconColor ?? theme.mutedText,
              size: 22,
            ),
        ],
      ),
    );

    if (showChatButton) {
      return tile;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOpening ? null : onTap,
        borderRadius: BorderRadius.circular(style.borderRadius),
        child: tile,
      ),
    );
  }
}

String _displayName(String username) {
  final trimmed = username.trim();
  if (trimmed.isEmpty) {
    return 'User';
  }
  return trimmed
      .split(RegExp(r'[_-]'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _initials(String username) {
  final chunks = _displayName(username)
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList();
  if (chunks.isEmpty) {
    return 'U';
  }

  final first = chunks.first[0];
  final second = chunks.length > 1
      ? chunks[1][0]
      : (chunks.first.length > 1 ? chunks.first[1] : '');
  return '$first$second';
}
