import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messenger_conversation.dart';
import '../models/messenger_search_visibility.dart';
import '../models/messenger_user.dart';
import '../theme/messenger_theme.dart';
import 'messenger_avatar.dart';

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
    required this.onLogout,
    required this.onOpenDirectChat,
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
  });

  final String currentUserName;
  final List<MessengerConversation> conversations;
  final List<MessengerUser> users;
  final String? selectedConversationId;
  final String openingDirectUserId;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final FutureOr<void> Function(MessengerUser user) onOpenDirectChat;
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
  });

  final MessengerUser user;
  final String messagePreview;
  final bool hasUnread;
  final bool isInSelectedConversation;
}

class _MessengerConversationListState extends State<MessengerConversationList> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void dispose() {
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

  bool get _hasPeerUsers =>
      widget.conversations.any((conversation) => conversation.peerUsers.isNotEmpty);

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

  int _compareConversationsByActivity(
    MessengerConversation left,
    MessengerConversation right,
  ) {
    final activityCompare = _activityAt(right).compareTo(_activityAt(left));
    if (activityCompare != 0) {
      return activityCompare;
    }
    return left.id.compareTo(right.id);
  }

  List<MessengerConversation> _conversationsByActivity() {
    final ordered = [...widget.conversations];
    ordered.sort(_compareConversationsByActivity);
    return ordered;
  }

  List<_PeerListEntry> _orderedPeerEntries() {
    if (!_hasPeerUsers) {
      return _legacyUserEntries();
    }

    final orderedConversations = _conversationsByActivity();
    final previewByUser = <String, String>{};
    final unreadByUser = <String, int>{};
    for (final c in orderedConversations) {
      for (final u in c.peerUsers) {
        previewByUser.putIfAbsent(u.id, () => c.subtitle);
        final prev = unreadByUser[u.id] ?? 0;
        if (c.unreadCount > prev) {
          unreadByUser[u.id] = c.unreadCount;
        }
      }
    }

    final seen = <String>{};
    final orderedUsers = <MessengerUser>[];

    void addPeers(Iterable<MessengerUser> peers) {
      for (final u in peers) {
        if (seen.add(u.id)) {
          orderedUsers.add(u);
        }
      }
    }

    final selected = _conversationForId(widget.selectedConversationId);
    for (final c in orderedConversations) {
      addPeers(c.peerUsers);
    }

    return orderedUsers
        .map(
          (u) => _PeerListEntry(
            user: u,
            messagePreview: previewByUser[u.id] ?? '',
            hasUnread: (unreadByUser[u.id] ?? 0) > 0,
            isInSelectedConversation: selected != null &&
                selected.peerUsers.any((p) => p.id == u.id),
          ),
        )
        .toList(growable: false);
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
            _compareConversationsByActivity(leftConversation, rightConversation);
        if (compare != 0) {
          return compare;
        }
      } else if (leftConversation != null || rightConversation != null) {
        return leftConversation != null ? -1 : 1;
      }

      if (left.isOnline != right.isOnline) {
        return left.isOnline ? -1 : 1;
      }
      return left.username.toLowerCase().compareTo(right.username.toLowerCase());
    });

    return users
        .map(
          (user) => _PeerListEntry(
            user: user,
            messagePreview: _legacyPreviewForUser(user),
            hasUnread: _legacyHasUnreadForUser(user),
            isInSelectedConversation: selected != null &&
                _legacyConversationMatchesUser(selected, user),
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
              e.messagePreview.toLowerCase().contains(queryLower),
        )
        .toList(growable: false);
  }

  Widget _buildMainUserListItem(BuildContext context, _PeerListEntry entry) {
    final data = MessengerUserListItemData(
      user: entry.user,
      isSelected: entry.isInSelectedConversation,
      hasUnread: entry.hasUnread,
      isOpening: widget.openingDirectUserId == entry.user.id,
      messagePreview: entry.messagePreview.isEmpty ? null : entry.messagePreview,
      onTap: () {
        widget.onOpenDirectChat(entry.user);
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
                    onPressed: widget.onRefresh,
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
    final searchBg = widget.searchFieldBackgroundColor ?? theme.searchBackground;
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
          Container(
            height: 38,
            padding: searchContentPadding ??
                const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(searchRadius),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: searchIconColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: widget.searchInputTextStyle,
                    decoration: InputDecoration(
                      hintText: widget.searchHintText,
                      hintStyle: searchHintStyle,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () => _searchController.clear(),
                    child: Icon(Icons.close_rounded, color: searchIconColor),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: filteredEntries.isEmpty
              ? _buildEmptyPeerList(context)
              : ListView.separated(
                  padding: widget.userListPadding,
                  itemCount: filteredEntries.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: widget.userListItemSpacing),
                  itemBuilder: (context, index) {
                    final entry = filteredEntries[index];
                    return _buildMainUserListItem(context, entry);
                  },
                ),
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
    final heroTag =
        widget.fabHeroTag ?? (widget.isMobile ? 'startChatMobile' : 'startChatDesktop');

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

  Future<void> _openDirectPicker(BuildContext context) async {
    final theme = MessengerTheme.of(context);
    final searchBg = widget.searchFieldBackgroundColor ?? theme.searchBackground;
    final searchIconColor = widget.searchIconColor ?? theme.mutedText;
    final searchHintStyle =
        widget.searchHintTextStyle ?? TextStyle(color: theme.mutedText);
    final searchContentPadding = widget.searchFieldContentPadding;
    final searchRadius = widget.searchFieldBorderRadius ?? 12;

    final sortedUsers = [...widget.users]..sort((a, b) {
        if (a.isOnline == b.isOnline) {
          return a.username.toLowerCase().compareTo(b.username.toLowerCase());
        }
        return a.isOnline ? -1 : 1;
      });

    String query = '';
    final searchController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setState) {
          final filteredUsers = query.isEmpty
              ? sortedUsers
              : sortedUsers
                  .where(
                    (user) =>
                        user.username.toLowerCase().contains(query) ||
                        user.roleLabel.toLowerCase().contains(query),
                  )
                  .toList(growable: false);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start New Chat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 38,
                    padding: searchContentPadding ??
                        const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: searchBg,
                      borderRadius: BorderRadius.circular(searchRadius),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: searchIconColor,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            style: widget.searchInputTextStyle,
                            onChanged: (value) => setState(() {
                              query = value.trim().toLowerCase();
                            }),
                            decoration: InputDecoration(
                              hintText: widget.searchHintText,
                              hintStyle: searchHintStyle,
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              searchController.clear();
                              setState(() => query = '');
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: searchIconColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (filteredUsers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: widget.emptyUsersBuilder?.call(sheetContext) ??
                          Text(
                            widget.emptyUsersMessage,
                            style: TextStyle(
                              color: MessengerTheme.of(context).subtleText,
                            ),
                          ),
                    )
                  else
                    ...filteredUsers.map(
                      (user) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DirectUserTile(
                          user: user,
                          isOpening: widget.openingDirectUserId == user.id,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            widget.onOpenDirectChat(user);
                          },
                          showChatButton: true,
                          isSelected: false,
                          messagePreview: null,
                          hasUnread: false,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
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

class _DirectUserTile extends StatelessWidget {
  const _DirectUserTile({
    required this.user,
    required this.isOpening,
    required this.onTap,
    required this.showChatButton,
    required this.isSelected,
    required this.hasUnread,
    this.messagePreview,
    this.style = const MessengerUserListItemStyle(),
  });

  final MessengerUser user;
  final bool isOpening;
  final VoidCallback onTap;
  final bool showChatButton;
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
      color: theme.subtleText,
      fontSize: 11.5,
    ).merge(style.subtitleStyle);
    final defaultBorder = BorderSide(color: theme.border);
    final defaultSelectedBorder =
        BorderSide(color: theme.primary.withValues(alpha: 0.35));
    final tile = Container(
      margin: style.margin,
      decoration: BoxDecoration(
        color: isSelected
            ? (style.selectedBackgroundColor ??
                theme.primary.withValues(alpha: 0.12))
            : (style.backgroundColor ?? const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(style.borderRadius),
        border: Border.fromBorderSide(
          isSelected ? (style.selectedBorder ?? defaultSelectedBorder) : (style.border ?? defaultBorder),
        ),
        boxShadow: style.boxShadow,
      ),
      padding: style.padding,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              MessengerAvatar(
                label: _initials(user.username),
                imageUrl: user.avatarUrl,
                compact: true,
                size: 34,
                showOnlineIndicator: true,
                isOnline: user.isOnline,
              ),
              if (hasUnread)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: style.unreadDotColor ?? theme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
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
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(isOpening ? '...' : 'Chat'),
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
  return username
      .split(RegExp(r'[_-]'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _initials(String username) {
  final chunks = _displayName(
    username,
  ).split(' ').where((part) => part.isNotEmpty).toList();
  if (chunks.isEmpty) {
    return 'U';
  }

  final first = chunks.first[0];
  final second = chunks.length > 1
      ? chunks[1][0]
      : (chunks.first.length > 1 ? chunks.first[1] : '');
  return '$first$second';
}
