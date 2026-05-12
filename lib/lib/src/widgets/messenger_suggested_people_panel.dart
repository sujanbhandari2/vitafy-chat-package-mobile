import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messenger_user.dart';
import '../theme/messenger_theme.dart';
import 'messenger_avatar.dart';

/// Self-contained panel that lists tenant users to start a brand new
/// direct chat with — explicitly **not** a conversations list.
///
/// Defaults render a "Suggested people" title, a helper line and a
/// vertical list of user rows. Every visual region can be overridden
/// via the optional builder / widget slots without losing tap behavior.
///
/// Typical wiring (host-composed or via [MessengerChatShell]'s
/// `suggestedPeopleBuilder` slot — use the third callback argument as
/// [onUserSelected] on mobile so the shell can open the full-screen thread):
///
/// ```dart
/// MessengerSuggestedPeoplePanel(
///   users: tenantUsers,
///   openingUserId: currentlyOpeningUserId,
///   onUserSelected: openDirectChat,
/// )
/// ```
class MessengerSuggestedPeoplePanel extends StatelessWidget {
  const MessengerSuggestedPeoplePanel({
    super.key,
    required this.users,
    required this.onUserSelected,
    this.openingUserId = '',
    this.titleText = 'Suggested people',
    this.helperText =
        "You don't have any conversations yet. Choose someone to start messaging.",
    this.titleWidget,
    this.helperWidget,
    this.headerBuilder,
    this.itemBuilder,
    this.separatorBuilder,
    this.footerWidget,
    this.emptyText = 'No people available right now.',
    this.emptyBuilder,
    this.isLoading = false,
    this.loadingBuilder,
    this.showSearchField = false,
    this.searchQuery = '',
    this.onSearchQueryChanged,
    this.searchHintText = 'Search people...',
    this.noSearchResultsText = 'No people match your search.',
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.itemSpacing = 8,
    this.titleTextStyle,
    this.helperTextStyle,
    this.physics,
    this.shrinkWrap = false,
    this.semanticsLabel = 'Suggested people',
    this.onPullToRefresh,
  }) : assert(
          !showSearchField || onSearchQueryChanged != null,
          'onSearchQueryChanged is required when showSearchField is true.',
        );

  /// Users to suggest starting a chat with.
  final List<MessengerUser> users;

  /// Invoked when a user row is tapped (default rows or your custom
  /// [itemBuilder] rows can call it).
  final FutureOr<void> Function(MessengerUser user) onUserSelected;

  /// User id whose row should currently appear busy (e.g. spinner) while
  /// the host is creating the underlying conversation.
  final String openingUserId;

  /// Default header title — ignored when [titleWidget] or [headerBuilder]
  /// is provided.
  final String titleText;

  /// Default helper line under the title — ignored when [helperWidget] or
  /// [headerBuilder] is provided.
  final String helperText;

  /// Replaces the default [titleText] widget when non-null. Ignored when
  /// [headerBuilder] is provided.
  final Widget? titleWidget;

  /// Replaces the default [helperText] widget when non-null. Ignored when
  /// [headerBuilder] is provided.
  final Widget? helperWidget;

  /// Replaces the entire header block (title + helper). Receives the
  /// current users so the host can show counts or contextual hints.
  final Widget Function(BuildContext context, List<MessengerUser> users)?
      headerBuilder;

  /// Builds an individual user row. When null, a built-in compact row is
  /// rendered (avatar + username + role + online dot).
  final Widget Function(BuildContext context, MessengerUser user, int index)?
      itemBuilder;

  /// Optional custom separator between rows. When null, a [SizedBox] of
  /// height [itemSpacing] is used.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Optional widget rendered below the user list (e.g. a privacy note).
  final Widget? footerWidget;

  /// Default empty-state copy when [users] is empty.
  final String emptyText;

  /// Custom builder for the empty state. Replaces [emptyText] when set.
  final WidgetBuilder? emptyBuilder;

  /// When true, the loading branch is rendered instead of the list.
  final bool isLoading;

  /// Custom loading builder. Defaults to a centered [CircularProgressIndicator].
  final WidgetBuilder? loadingBuilder;

  /// Enables the built-in search input shown above the people list.
  final bool showSearchField;

  /// Controlled query value used for local filtering when [showSearchField]
  /// is true.
  final String searchQuery;

  /// Called whenever the search input changes.
  final ValueChanged<String>? onSearchQueryChanged;

  /// Search input placeholder text.
  final String searchHintText;

  /// Copy shown when [searchQuery] has text but no users match.
  final String noSearchResultsText;

  /// Outer padding around the whole panel.
  final EdgeInsetsGeometry padding;

  /// Vertical gap between default rows when [separatorBuilder] is null.
  final double itemSpacing;

  /// Style override for the default title.
  final TextStyle? titleTextStyle;

  /// Style override for the default helper line.
  final TextStyle? helperTextStyle;

  /// Optional [ScrollPhysics] forwarded to the internal list.
  final ScrollPhysics? physics;

  /// Forwarded to the internal list. Set to true when nesting inside
  /// another scrollable.
  final bool shrinkWrap;

  /// Accessibility label wrapped around the panel.
  final String semanticsLabel;

  /// When non-null, the panel body is wrapped in [RefreshIndicator] and this
  /// callback is awaited on overscroll (same contract as [RefreshIndicator.onRefresh]).
  final Future<void> Function()? onPullToRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final normalizedSearchQuery = searchQuery.trim();
    final filteredUsers = _filterUsers(users, normalizedSearchQuery);

    final header = headerBuilder?.call(context, users) ??
        _buildDefaultHeader(context, theme);

    Widget body;
    if (isLoading) {
      body = loadingBuilder?.call(context) ?? _buildDefaultLoading();
    } else if (users.isEmpty) {
      body = emptyBuilder?.call(context) ?? _buildDefaultEmpty(theme);
    } else if (filteredUsers.isEmpty && normalizedSearchQuery.isNotEmpty) {
      body = _buildNoSearchResults(theme);
    } else {
      body = _buildList(context, filteredUsers);
    }

    body = _wrapWithPullToRefresh(context, body,
        scrollableList: !isLoading && filteredUsers.isNotEmpty);

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            if (showSearchField) ...[
              const SizedBox(height: 10),
              _buildSearchField(theme),
            ],
            const SizedBox(height: 12),
            Flexible(child: body),
            if (footerWidget != null) ...[
              const SizedBox(height: 12),
              footerWidget!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _wrapWithPullToRefresh(
    BuildContext context,
    Widget body, {
    required bool scrollableList,
  }) {
    final refresh = onPullToRefresh;
    if (refresh == null) {
      return body;
    }
    if (scrollableList) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: body,
      );
    }
    return RefreshIndicator(
      onRefresh: refresh,
      child: LayoutBuilder(
        builder: (ctx, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultHeader(BuildContext context, MessengerThemeData theme) {
    final defaultTitleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: theme.bubbleMineText,
    ).merge(titleTextStyle);
    final defaultHelperStyle = TextStyle(
      fontSize: 13,
      color: theme.subtleText,
      height: 1.35,
    ).merge(helperTextStyle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleWidget ?? Text(titleText, style: defaultTitleStyle),
        const SizedBox(height: 4),
        helperWidget ?? Text(helperText, style: defaultHelperStyle),
      ],
    );
  }

  Widget _buildDefaultLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }

  Widget _buildDefaultEmpty(MessengerThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          emptyText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.subtleText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResults(MessengerThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          noSearchResultsText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.subtleText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(MessengerThemeData theme) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.searchBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: theme.mutedText, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              key: ValueKey<String>(searchQuery),
              initialValue: searchQuery,
              onChanged: onSearchQueryChanged,
              decoration: InputDecoration(
                hintText: searchHintText,
                hintStyle: TextStyle(color: theme.mutedText),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (searchQuery.trim().isNotEmpty)
            GestureDetector(
              onTap: () => onSearchQueryChanged?.call(''),
              child: Icon(Icons.close_rounded, color: theme.mutedText),
            ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<MessengerUser> visibleUsers) {
    final listPhysics = onPullToRefresh != null
        ? AlwaysScrollableScrollPhysics(
            parent: physics ?? const ClampingScrollPhysics(),
          )
        : physics;

    return ListView.separated(
      primary: false,
      physics: listPhysics,
      shrinkWrap: shrinkWrap,
      padding: EdgeInsets.zero,
      itemCount: visibleUsers.length,
      separatorBuilder:
          separatorBuilder ?? (_, __) => SizedBox(height: itemSpacing),
      itemBuilder: (context, index) {
        final user = visibleUsers[index];
        if (itemBuilder != null) {
          return itemBuilder!(context, user, index);
        }
        return _SuggestedUserRow(
          user: user,
          isOpening: _isOpening(user.id),
          onTap: () => onUserSelected(user),
        );
      },
    );
  }

  bool _isOpening(String userId) {
    final opening = openingUserId.trim();
    if (opening.isEmpty) {
      return false;
    }
    return opening == userId.trim();
  }

  List<MessengerUser> _filterUsers(
    List<MessengerUser> source,
    String query,
  ) {
    final q = query.toLowerCase();
    if (q.isEmpty) {
      return source;
    }
    return source.where((user) {
      return user.username.toLowerCase().contains(q) ||
          user.roleLabel.toLowerCase().contains(q) ||
          user.id.toLowerCase().contains(q);
    }).toList(growable: false);
  }
}

class _SuggestedUserRow extends StatelessWidget {
  const _SuggestedUserRow({
    required this.user,
    required this.isOpening,
    required this.onTap,
  });

  final MessengerUser user;
  final bool isOpening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final subtitleParts = <String>[
      if (user.roleLabel.trim().isNotEmpty) user.roleLabel.trim(),
      user.isOnline ? 'Online' : 'Offline',
    ];
    final subtitle = subtitleParts.join(' • ');

    return InkWell(
      onTap: isOpening ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            MessengerAvatar(
              label: _initials(user.username),
              imageUrl: user.avatarUrl,
              compact: true,
              size: 36,
              showOnlineIndicator: true,
              isOnline: user.isOnline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.subtleText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            isOpening
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: theme.primary,
                    size: 20,
                  ),
          ],
        ),
      ),
    );
  }

  String _initials(String text) {
    final parts = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'CH';
    }
    if (parts.length == 1) {
      final part = parts.first;
      return part.substring(0, part.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}
