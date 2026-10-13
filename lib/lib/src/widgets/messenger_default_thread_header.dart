import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messenger_conversation.dart';
import '../models/messenger_thread_view_overrides.dart';
import '../theme/messenger_theme.dart';
import '../utils/messenger_thread_header_avatar.dart';
import 'messenger_avatar.dart';

enum _ThreadHeaderOverflowAction {
  editGroup,
  addPeople,
  deleteChat,
}

/// Default conversation thread header (back, avatar, title, overflow menu).
class MessengerDefaultThreadHeader extends StatefulWidget {
  const MessengerDefaultThreadHeader({
    super.key,
    required this.data,
  });

  final MessengerThreadHeaderData data;

  @override
  State<MessengerDefaultThreadHeader> createState() =>
      _MessengerDefaultThreadHeaderState();
}

class _MessengerDefaultThreadHeaderState
    extends State<MessengerDefaultThreadHeader> {
  bool _overflowActionInFlight = false;

  bool _showMenu(MessengerConversation? c) {
    if (c == null) {
      return false;
    }
    if (widget.data.onDeleteConversation != null) {
      return true;
    }
    if (!c.isGroup) {
      return false;
    }
    return widget.data.onEditGroupConversation != null ||
        widget.data.onAddPeopleToGroupConversation != null;
  }

  List<PopupMenuEntry<_ThreadHeaderOverflowAction>> _menuItems(
    BuildContext context,
    MessengerConversation c,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final menuStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: onSurface,
    );
    final deleteStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.error,
    );
    final items = <PopupMenuEntry<_ThreadHeaderOverflowAction>>[];
    if (c.isGroup && widget.data.onEditGroupConversation != null) {
      items.add(
        PopupMenuItem(
          value: _ThreadHeaderOverflowAction.editGroup,
          child: Text('Edit', style: menuStyle),
        ),
      );
    }
    if (c.isGroup && widget.data.onAddPeopleToGroupConversation != null) {
      items.add(
        PopupMenuItem(
          value: _ThreadHeaderOverflowAction.addPeople,
          child: Text('Add people', style: menuStyle),
        ),
      );
    }
    if (widget.data.onDeleteConversation != null) {
      items.add(
        PopupMenuItem(
          value: _ThreadHeaderOverflowAction.deleteChat,
          child: Text('Delete chat', style: deleteStyle),
        ),
      );
    }
    return items;
  }

  Future<void> _showDeleteChatConfirmation(MessengerConversation c) async {
    final delete = widget.data.onDeleteConversation;
    if (delete == null) {
      return;
    }
    final rawTitle = c.title.trim();
    final label = rawTitle.isEmpty ? 'this chat' : rawTitle;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => wrapMessengerPackageDialogTheme(
        ambientContext: context,
        packageDialogTheme: widget.data.packageDialogTheme,
        child: _MessengerDeleteChatDialog(
          conversationTitle: label,
          onDeleteConfirmed: () async {
            await Future<void>.sync(() => delete(c));
          },
          onDismissMobileThreadAfterDelete:
              widget.data.onDismissMobileThreadAfterConversationDelete,
        ),
      ),
    );
  }

  Future<void> _onMenuSelected(
    MessengerConversation c,
    _ThreadHeaderOverflowAction action,
  ) async {
    if (_overflowActionInFlight) {
      return;
    }
    _overflowActionInFlight = true;
    if (mounted) {
      setState(() {});
    }
    try {
      switch (action) {
        case _ThreadHeaderOverflowAction.editGroup:
          await widget.data.onEditGroupConversation?.call(c);
          return;
        case _ThreadHeaderOverflowAction.addPeople:
          await widget.data.onAddPeopleToGroupConversation?.call(c);
          return;
        case _ThreadHeaderOverflowAction.deleteChat:
          await _showDeleteChatConfirmation(c);
          return;
      }
    } finally {
      _overflowActionInFlight = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget? _overflowMenu(BuildContext context, MessengerThemeData theme) {
    final c = widget.data.conversation;
    if (!_showMenu(c) || c == null) {
      return null;
    }
    return PopupMenuButton<_ThreadHeaderOverflowAction>(
      enabled: !_overflowActionInFlight,
      icon: Icon(Icons.more_vert_rounded, color: theme.primary),
      itemBuilder: (menuContext) => _menuItems(menuContext, c),
      onSelected: (action) => unawaited(_onMenuSelected(c, action)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final c = widget.data.conversation;
    final roleLabel = _conversationRoleLabel(c);
    final showOnlinePresence = c != null && !c.isGroup && c.isOnline != null;
    final avatarLabel = messengerThreadHeaderAvatarLabel(c);
    final avatarUrl = messengerThreadHeaderAvatarUrl(c);
    final menu = _overflowMenu(context, theme);
    final isMobile = widget.data.isMobile;
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: isMobile
            ? null
            : const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      padding: EdgeInsets.fromLTRB(isMobile ? 4 : 12, 8, 8, 8),
      child: isMobile
          ? SizedBox(
              height: roleLabel.isEmpty ? 48 : 56,
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: widget.data.onBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                      ),
                      MessengerAvatar(
                        label: avatarLabel,
                        imageUrl: avatarUrl,
                        compact: true,
                        size: 34,
                        showOnlineIndicator: showOnlinePresence,
                        isOnline: c?.isOnline ?? false,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            c?.title ?? 'No conversation',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          if (roleLabel.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              roleLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.subtleText,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (menu != null) menu,
                ],
              ),
            )
          : Row(
              children: [
                MessengerAvatar(
                  label: avatarLabel,
                  imageUrl: avatarUrl,
                  compact: true,
                  size: 34,
                  showOnlineIndicator: showOnlinePresence,
                  isOnline: c?.isOnline ?? false,
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
                              c?.title ?? 'No conversation',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (roleLabel.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          roleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.subtleText,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (menu != null) menu,
              ],
            ),
    );
  }

  String _conversationRoleLabel(MessengerConversation? conversation) {
    if (conversation == null || conversation.isGroup) {
      return '';
    }
    for (final user in conversation.peerUsers) {
      final role = user.roleLabel.trim();
      if (role.isNotEmpty) {
        return role;
      }
    }
    return '';
  }
}

class _MessengerDeleteChatDialog extends StatefulWidget {
  const _MessengerDeleteChatDialog({
    required this.conversationTitle,
    required this.onDeleteConfirmed,
    this.onDismissMobileThreadAfterDelete,
  });

  final String conversationTitle;
  final Future<void> Function() onDeleteConfirmed;
  final VoidCallback? onDismissMobileThreadAfterDelete;

  @override
  State<_MessengerDeleteChatDialog> createState() =>
      _MessengerDeleteChatDialogState();
}

class _MessengerDeleteChatDialogState
    extends State<_MessengerDeleteChatDialog> {
  bool _deleting = false;

  Future<void> _onDeletePressed() async {
    setState(() => _deleting = true);
    try {
      await widget.onDeleteConfirmed();
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      widget.onDismissMobileThreadAfterDelete?.call();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _deleting = false);
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not delete the chat.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        title: const Text('Delete chat'),
        content: Text(
          'Delete "${widget.conversationTitle}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: _deleting
                ? null
                : () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _deleting ? null : _onDeletePressed,
            child: _deleting
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onError,
                    ),
                  )
                : const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
