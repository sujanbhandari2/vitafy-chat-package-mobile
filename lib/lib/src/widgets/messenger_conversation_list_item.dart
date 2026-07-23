import 'package:flutter/material.dart';

import '../models/messenger_user.dart';
import '../theme/messenger_theme.dart';
import 'messenger_avatar.dart';
import 'messenger_group_avatar.dart';

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
    this.conversationId,
    this.isConversationRow = false,
    this.useGroupAvatar = false,
    this.groupAvatarUsers = const [],
    this.showOnlinePresence = true,
    required this.displayTitle,
    required this.subtitle,
    this.roleLabel = '',
  });

  final MessengerUser user;
  final bool isSelected;
  final bool hasUnread;
  final bool isOpening;
  final String? messagePreview;
  final VoidCallback onTap;
  final String? conversationId;
  final bool isConversationRow;
  final bool useGroupAvatar;
  final List<MessengerUser> groupAvatarUsers;
  final bool showOnlinePresence;
  final String displayTitle;
  final String subtitle;
  final String roleLabel;
}

/// Formats a username for display in conversation list rows.
String conversationListItemDisplayName(String username) {
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

/// Derives avatar initials from a username for conversation list rows.
String conversationListItemInitials(String username) {
  final chunks = conversationListItemDisplayName(username)
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

/// Subtitle shown under the title when no message preview is available.
String conversationListItemSubtitle({
  required MessengerUser user,
  required String? messagePreview,
  required bool showOnlinePresence,
}) {
  final preview = messagePreview;
  if (preview != null && preview.isNotEmpty) {
    return preview;
  }
  if (showOnlinePresence) {
    return '${user.roleLabel}${user.roleLabel.isNotEmpty ? ' • ' : ''}${user.isOnline ? 'Online' : 'Offline'}';
  }
  return user.roleLabel.trim();
}

/// Default conversation list row card (avatar, title, role chip, preview).
class MessengerConversationListItem extends StatelessWidget {
  const MessengerConversationListItem({
    super.key,
    required this.data,
    this.style = const MessengerUserListItemStyle(),
    this.showRoleChip = true,
    this.showChatButton = false,
    this.actionLabel = 'Chat',
  });

  final MessengerUserListItemData data;
  final MessengerUserListItemStyle style;
  final bool showRoleChip;
  final bool showChatButton;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final role = data.roleLabel;
    final titleStyle = const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13.5,
    ).merge(style.titleStyle);
    final subtitleStyle = TextStyle(
      color: data.hasUnread ? const Color(0xFF374151) : theme.subtleText,
      fontSize: 11.5,
      fontWeight: data.hasUnread ? FontWeight.w700 : FontWeight.w500,
    ).merge(style.subtitleStyle);
    final defaultBorder = BorderSide(color: theme.border);
    final backgroundColor = data.isSelected
        ? (style.selectedBackgroundColor ??
            style.backgroundColor ??
            const Color(0xFFF8FAFC))
        : (style.backgroundColor ?? const Color(0xFFF8FAFC));
    final borderSide = data.isSelected
        ? (style.selectedBorder ?? style.border ?? defaultBorder)
        : (style.border ?? defaultBorder);
    final tile = Container(
      margin: style.margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(style.borderRadius),
        border: Border.fromBorderSide(borderSide),
        boxShadow: style.boxShadow,
      ),
      padding: style.padding,
      child: Row(
        children: [
          data.useGroupAvatar
              ? MessengerGroupAvatar(
                  users: data.groupAvatarUsers,
                  fallbackLabel: data.user.username,
                  size: 34,
                )
              : MessengerAvatar(
                  label: conversationListItemInitials(data.user.username),
                  imageUrl: data.user.avatarUrl,
                  compact: true,
                  size: 34,
                  showOnlineIndicator: data.showOnlinePresence,
                  isOnline: data.user.isOnline,
                ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.displayTitle,
                        style: titleStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showRoleChip && role.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      MessengerConversationListRoleChip(
                        label: role,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                Text(
                  data.subtitle,
                  style: subtitleStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showChatButton)
            FilledButton(
              onPressed: data.isOpening ? null : data.onTap,
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
              child: data.isOpening
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(actionLabel),
            )
          else if (data.isOpening)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
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
        onTap: data.isOpening ? null : data.onTap,
        borderRadius: BorderRadius.circular(style.borderRadius),
        child: tile,
      ),
    );
  }
}

/// Role badge shown next to a conversation list row title.
class MessengerConversationListRoleChip extends StatelessWidget {
  const MessengerConversationListRoleChip({
    super.key,
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      constraints: BoxConstraints(
        minHeight: compact ? 20 : 24,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 0 : 1,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xFF292929),
          fontSize: compact ? 10.5 : 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
