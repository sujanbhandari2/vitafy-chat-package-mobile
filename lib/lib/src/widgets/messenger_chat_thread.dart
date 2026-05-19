import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/messenger_conversation.dart';
import '../models/messenger_message.dart';
import '../models/messenger_attachment.dart';
import '../models/messenger_thread_fetch_loading_mode.dart';
import '../models/messenger_thread_loading_style.dart';
import '../models/messenger_typing.dart';
import 'messenger_avatar.dart';
import 'messenger_composer_bar.dart';
import 'messenger_media_send_orchestrator.dart';
import 'messenger_default_inline_loading.dart';
import 'messenger_incoming_seen_reporter.dart';
import 'messenger_message_bubble.dart';
import '../theme/messenger_theme.dart';
import '../utils/messenger_thread_scroll.dart';

/// Small bottom padding on the message list; the composer provides most
/// separation. Prefer a host [Scaffold] with [Scaffold.resizeToAvoidBottomInset]
/// so the keyboard resizes the viewport rather than duplicating inset padding.
const double _kThreadListBottomScrollPadding = 8;

class MessengerChatThread extends StatefulWidget {
  const MessengerChatThread({
    super.key,
    required this.conversation,
    required this.messages,
    required this.currentUserId,
    required this.composerController,
    required this.messagesScrollController,
    required this.isSending,
    required this.isRecording,
    required this.onSend,
    required this.onPickImage,
    required this.onPickAudio,
    required this.onStartRecording,
    required this.onFinishRecording,
    required this.onCancelRecording,
    required this.onToggleRecording,
    this.onPickCamera,
    this.onPickDocument,
    this.onPickVideo,
    this.composerHintText = 'Type your message...',
    this.composerInputTextStyle,
    this.composerHintTextStyle,
    this.composerFieldBackgroundColor,
    this.composerFieldContentPadding,
    this.attachmentSheetTitle = 'Attachments',
    this.attachmentOptions,
    this.onBack,
    this.onReact,
    this.onRemoveReaction,
    this.onDelete,
    this.onMarkSeen,
    this.canDeleteMessage,
    this.onEditMessage,
    this.canEditMessage,
    this.enableReactions = true,
    this.reactionOptions = const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
    this.showDateSeparators = true,
    this.isMobile = false,
    this.emptyMessagesMessage = 'No messages yet.',
    this.emptyMessagesBuilder,
    this.isConversationLoading = false,
    this.loadingMessagesBuilder,
    this.contentTransitionDuration = const Duration(milliseconds: 180),
    this.remoteTypingUsers = const [],
    this.typingIndicatorPrefix = '',
    this.onTypingStart,
    this.onTypingStop,
    this.pendingAttachments = const [],
    this.onRemovePendingAttachment,
    this.onClearAllPendingAttachments,
    this.threadLoadingStyle,
    this.threadFetchLoadingMode =
        MessengerThreadFetchLoadingMode.replaceMessageList,
    this.threadFetchLoadingBuilder,
    this.snapToBottomOnKeyboardInsetChange = true,
    this.composerReplyDraft,
    this.onComposerReplyDraftChanged,
    this.composerFocusNode,
    this.attachmentCaptionTextStyle,
    this.attachmentOptionTextStyle,
    this.onEditGroupConversation,
    this.onAddPeopleToGroupConversation,
    this.onDeleteConversation,
    this.onDismissMobileThreadAfterConversationDelete,
    this.packageDialogTheme,
  });

  final MessengerConversation? conversation;
  final List<MessengerChatMessage> messages;
  final String currentUserId;
  final TextEditingController composerController;
  final ScrollController messagesScrollController;
  final bool isSending;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickAudio;
  final VoidCallback onStartRecording;
  final VoidCallback onFinishRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onToggleRecording;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickDocument;
  final VoidCallback? onPickVideo;
  final String composerHintText;
  final TextStyle? composerInputTextStyle;
  final TextStyle? composerHintTextStyle;
  final Color? composerFieldBackgroundColor;
  final EdgeInsetsGeometry? composerFieldContentPadding;
  final String attachmentSheetTitle;
  final List<MessengerAttachmentOption>? attachmentOptions;
  final VoidCallback? onBack;
  final Future<void> Function(String messageId, String reactionType)? onReact;
  final Future<void> Function(String messageId, String reactionType)?
      onRemoveReaction;
  final Future<void> Function(String messageId)? onDelete;
  final Future<void> Function(String messageId)? onMarkSeen;
  final bool Function(MessengerChatMessage message)? canDeleteMessage;
  final Future<void> Function(String messageId, String newText)? onEditMessage;
  final bool Function(MessengerChatMessage message)? canEditMessage;
  final bool enableReactions;
  final List<String> reactionOptions;
  final bool showDateSeparators;
  final bool isMobile;
  final String emptyMessagesMessage;
  final WidgetBuilder? emptyMessagesBuilder;
  final bool isConversationLoading;
  final WidgetBuilder? loadingMessagesBuilder;
  final Duration contentTransitionDuration;
  final List<MessengerTypingUser> remoteTypingUsers;
  final String typingIndicatorPrefix;
  final Future<void> Function(String conversationId)? onTypingStart;
  final Future<void> Function(String conversationId)? onTypingStop;
  final List<MessengerPickedMedia> pendingAttachments;
  final ValueChanged<int>? onRemovePendingAttachment;
  final VoidCallback? onClearAllPendingAttachments;
  final MessengerThreadLoadingStyle? threadLoadingStyle;

  /// When [messages] is not empty and [isConversationLoading] is true, controls
  /// whether the list is replaced by a loader or left visible.
  final MessengerThreadFetchLoadingMode threadFetchLoadingMode;

  /// Replaces the message list while refetching when [threadFetchLoadingMode] is
  /// [MessengerThreadFetchLoadingMode.replaceMessageList].
  final WidgetBuilder? threadFetchLoadingBuilder;

  /// When true, [MediaQuery.viewInsets] bottom changes (e.g. keyboard) trigger
  /// a jump to the latest message so the thread stays pinned to the composer.
  final bool snapToBottomOnKeyboardInsetChange;

  /// When set together with [onComposerReplyDraftChanged], swipe-to-reply is
  /// enabled and this draft is shown above the composer input.
  final MessengerComposerReplyDraft? composerReplyDraft;

  /// Host updates reply draft (including clearing with `null` after send).
  final ValueChanged<MessengerComposerReplyDraft?>?
      onComposerReplyDraftChanged;

  /// Optional focus node for the composer [TextField] (e.g. focus after swipe).
  final FocusNode? composerFocusNode;

  /// Overrides default styling for captions shown under attachment payloads.
  final TextStyle? attachmentCaptionTextStyle;

  /// Overrides text styling for + sheet options (Camera, Images, etc).
  final TextStyle? attachmentOptionTextStyle;

  final FutureOr<void> Function(MessengerConversation conversation)?
      onEditGroupConversation;
  final FutureOr<void> Function(MessengerConversation conversation)?
      onAddPeopleToGroupConversation;
  final FutureOr<void> Function(MessengerConversation conversation)?
      onDeleteConversation;

  /// After a successful delete from the package confirmation dialog on a
  /// pushed mobile thread, dismisses that full-screen route (one level back).
  final VoidCallback? onDismissMobileThreadAfterConversationDelete;

  /// Merged with [Theme.of] for package modal dialogs in this thread.
  /// Provided by [MessengerChatShell.packageDialogTheme].
  final ThemeData? packageDialogTheme;

  @override
  State<MessengerChatThread> createState() => _MessengerChatThreadState();
}

class _MessengerChatThreadState extends State<MessengerChatThread> {
  double _lastViewInsetBottom = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.snapToBottomOnKeyboardInsetChange) {
      _lastViewInsetBottom = MediaQuery.of(context).viewInsets.bottom;
      return;
    }
    if (widget.conversation == null || widget.messages.isEmpty) {
      _lastViewInsetBottom = MediaQuery.of(context).viewInsets.bottom;
      return;
    }
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    if (bottom != _lastViewInsetBottom) {
      _lastViewInsetBottom = bottom;
      MessengerThreadScroll.scheduleJumpToBottom(
        widget.messagesScrollController,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final loadingStyle =
        widget.threadLoadingStyle ?? MessengerThreadLoadingStyle.defaults;
    final visibleTyping = widget.remoteTypingUsers
        .where((user) => user.userId != widget.currentUserId)
        .toList(growable: false);
    final typingLine = visibleTyping.isEmpty
        ? ''
        : _formatRemoteTypingLine(visibleTyping, widget.typingIndicatorPrefix);

    Widget buildMessageList() {
      final bottomPad = _kThreadListBottomScrollPadding;
      return ListView.builder(
        controller: widget.messagesScrollController,
        clipBehavior: Clip.none,
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomPad),
        itemCount: widget.messages.length,
        itemBuilder: (context, index) {
          if (index < 0 || index >= widget.messages.length) {
            return const SizedBox.shrink();
          }
          final message = widget.messages[index];
          final mine = message.senderId == widget.currentUserId;
          final showDate = widget.showDateSeparators &&
              (index == 0 ||
                  !_isSameDay(
                    widget.messages[index - 1].createdAt,
                    message.createdAt,
                  ));

          final bubble = MessengerMessageBubble(
            packageDialogTheme: widget.packageDialogTheme,
            deleteActionTextStyle: Theme.of(context).textTheme.bodyMedium!,
            attachmentCaptionTextStyle: widget.attachmentCaptionTextStyle,
            message: message,
            isMine: mine,
            currentUserId: widget.currentUserId,
            canDelete: widget.canDeleteMessage?.call(message) ?? mine,
            canEdit: widget.canEditMessage?.call(message) ?? false,
            onEdit: widget.onEditMessage == null
                ? null
                : () {
                    final id = message.id;
                    final text = message.content;
                    unawaited(widget.onEditMessage!(id, text));
                  },
            onReact: widget.onReact == null
                ? null
                : (reaction) => widget.onReact!(message.id, reaction),
            onRemoveReaction: widget.onRemoveReaction == null
                ? null
                : (messageId, reactionType) =>
                    widget.onRemoveReaction!(messageId, reactionType),
            onDelete:
                widget.onDelete == null ? null : () => widget.onDelete!(message.id),
            onMarkSeen: widget.onMarkSeen == null
                ? null
                : () => widget.onMarkSeen!(message.id),
            enableReactions: widget.enableReactions,
            reactionOptions: widget.reactionOptions,
            onSwipeToReply: widget.onComposerReplyDraftChanged == null
                ? null
                : (MessengerChatMessage m) {
                    widget.onComposerReplyDraftChanged!(
                      MessengerComposerReplyDraft.fromMessage(m),
                    );
                    final focus = widget.composerFocusNode;
                    if (focus != null) {
                      SchedulerBinding.instance.addPostFrameCallback((_) {
                        if (focus.canRequestFocus) {
                          focus.requestFocus();
                        }
                      });
                    }
                  },
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDate) _DateSeparator(date: message.createdAt),
              if (!mine && widget.onMarkSeen != null)
                MessengerIncomingSeenReporter(
                  enabled: true,
                  onSeen: () => unawaited(widget.onMarkSeen!(message.id)),
                  child: bubble,
                )
              else
                bubble,
            ],
          );
        },
      );
    }

    Widget buildEmptyMessages() {
      return Semantics(
        key: const ValueKey('threadEmpty'),
        container: true,
        label: 'No messages in conversation',
        child: widget.emptyMessagesBuilder != null
            ? widget.emptyMessagesBuilder!(context)
            : Center(
                child: Text(
                  widget.emptyMessagesMessage,
                  style: TextStyle(
                    color: theme.subtleText,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
      );
    }

    /// When [messages] is non-empty and not in refetch-replace mode, keeps one
    /// [ListView] subtree so opening a thread (loading → loaded) does not reset
    /// scroll to the top.
    Widget threadBody;
    if (widget.conversation == null) {
      threadBody = Semantics(
        key: const ValueKey('threadNoneSelected'),
        container: true,
        label: 'No conversation selected',
        child: const Center(
          child: Text(
            'Select a conversation.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    } else if (widget.messages.isEmpty) {
      if (widget.isConversationLoading) {
        final builder = widget.loadingMessagesBuilder;
        threadBody = builder != null
            ? KeyedSubtree(
                key: const ValueKey('threadLoadingCustom'),
                child: builder(context),
              )
            : _ThreadLoadingPlaceholder(
                key: const ValueKey('threadLoading'),
                style: loadingStyle,
              );
      } else {
        threadBody = buildEmptyMessages();
      }
    } else if (widget.isConversationLoading &&
        widget.threadFetchLoadingMode ==
            MessengerThreadFetchLoadingMode.replaceMessageList) {
      threadBody = KeyedSubtree(
        key: const ValueKey('threadRefetchLoading'),
        child: widget.threadFetchLoadingBuilder?.call(context) ??
            const MessengerDefaultInlineLoading(),
      );
    } else {
      threadBody = ClipRect(
        clipBehavior: Clip.hardEdge,
        child: KeyedSubtree(
          key: ValueKey('threadMessages-${widget.conversation?.id ?? 'none'}'),
          child: buildMessageList(),
        ),
      );
    }

    final stage = Column(
      children: [
        _ThreadHeader(
          isMobile: widget.isMobile,
          conversation: widget.conversation,
          onBack: widget.onBack,
          onEditGroupConversation: widget.onEditGroupConversation,
          onAddPeopleToGroupConversation: widget.onAddPeopleToGroupConversation,
          onDeleteConversation: widget.onDeleteConversation,
          onDismissMobileThreadAfterConversationDelete:
              widget.onDismissMobileThreadAfterConversationDelete,
          packageDialogTheme: widget.packageDialogTheme,
        ),
        Expanded(
          child: ClipRect(
            child: ColoredBox(
              color: widget.isMobile
                  ? theme.threadBackgroundMobile
                  : theme.background,
              child: AnimatedSwitcher(
                duration: widget.contentTransitionDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: threadBody,
              ),
            ),
          ),
        ),
        if (widget.conversation != null && typingLine.isNotEmpty)
          _RemoteTypingStrip(text: typingLine, theme: theme),
        if (widget.conversation != null)
          MessengerComposerBar(
            controller: widget.composerController,
            isRecording: widget.isRecording,
            isSending: widget.isSending,
            onSend: widget.onSend,
            onPickImage: widget.onPickImage,
            onPickAudio: widget.onPickAudio,
            onStartRecording: widget.onStartRecording,
            onFinishRecording: widget.onFinishRecording,
            onCancelRecording: widget.onCancelRecording,
            onToggleRecording: widget.onToggleRecording,
            onPickCamera: widget.onPickCamera,
            onPickVideo: widget.onPickVideo,
            onPickDocument: widget.onPickDocument,
            hintText: widget.composerHintText,
            inputTextStyle: widget.composerInputTextStyle,
            hintTextStyle: widget.composerHintTextStyle,
            fieldBackgroundColor: widget.composerFieldBackgroundColor,
            fieldContentPadding: widget.composerFieldContentPadding,
            attachmentSheetTitle: widget.attachmentSheetTitle,
            attachmentOptions: widget.attachmentOptions,
            attachmentOptionTextStyle: widget.attachmentOptionTextStyle,
            typingConversationId: widget.conversation?.id,
            onTypingStart: widget.onTypingStart,
            onTypingStop: widget.onTypingStop,
            pendingAttachments: widget.pendingAttachments,
            onRemovePendingAttachment: widget.onRemovePendingAttachment,
            onClearAllPendingAttachments: widget.onClearAllPendingAttachments,
            replyDraft: widget.composerReplyDraft,
            onCancelReplyDraft: widget.onComposerReplyDraftChanged == null
                ? null
                : () => widget.onComposerReplyDraftChanged!(null),
            textFieldFocusNode: widget.composerFocusNode,
          ),
      ],
    );

    if (widget.isMobile) {
      return stage;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E3FB)),
      ),
      child: stage,
    );
  }
}

String _formatRemoteTypingLine(
  List<MessengerTypingUser> users,
  String prefix,
) {
  if (users.isEmpty) {
    return '';
  }
  final names = users.map((e) => e.displayLabel).toList();
  final String core;
  if (names.length == 1) {
    core = '${names[0]} is typing';
  } else if (names.length == 2) {
    core = '${names[0]} and ${names[1]} are typing';
  } else {
    core = '${names[0]}, ${names[1]} and ${names.length - 2} others are typing';
  }
  final p = prefix.trim();
  if (p.isEmpty) {
    return core;
  }
  return '$p $core';
}

class _RemoteTypingStrip extends StatelessWidget {
  const _RemoteTypingStrip({
    required this.text,
    required this.theme,
  });

  final String text;
  final MessengerThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Typing: $text',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: TextStyle(
              color: theme.mutedText,
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
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

class _MessengerDeleteChatDialogState extends State<_MessengerDeleteChatDialog> {
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

enum _ThreadHeaderOverflowAction {
  editGroup,
  addPeople,
  deleteChat,
}

class _ThreadHeader extends StatefulWidget {
  const _ThreadHeader({
    required this.isMobile,
    required this.conversation,
    this.onBack,
    this.onEditGroupConversation,
    this.onAddPeopleToGroupConversation,
    this.onDeleteConversation,
    this.onDismissMobileThreadAfterConversationDelete,
    this.packageDialogTheme,
  });

  final bool isMobile;
  final MessengerConversation? conversation;
  final VoidCallback? onBack;
  final FutureOr<void> Function(MessengerConversation conversation)?
      onEditGroupConversation;
  final FutureOr<void> Function(MessengerConversation conversation)?
      onAddPeopleToGroupConversation;
  final FutureOr<void> Function(MessengerConversation conversation)?
      onDeleteConversation;
  final VoidCallback? onDismissMobileThreadAfterConversationDelete;
  final ThemeData? packageDialogTheme;

  @override
  State<_ThreadHeader> createState() => _ThreadHeaderState();
}

class _ThreadHeaderState extends State<_ThreadHeader> {
  /// Prevents stacking host dialogs/sheets when [PopupMenuButton.onSelected]
  /// is not awaited and the user opens the overflow menu again while an async
  /// host callback (e.g. delete confirmation) is still in flight.
  bool _overflowActionInFlight = false;

  bool _showMenu(MessengerConversation? c) {
    if (c == null) {
      return false;
    }
    if (widget.onDeleteConversation != null) {
      return true;
    }
    if (!c.isGroup) {
      return false;
    }
    return widget.onEditGroupConversation != null ||
        widget.onAddPeopleToGroupConversation != null;
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
    if (c.isGroup && widget.onEditGroupConversation != null) {
      items.add(
        PopupMenuItem(
          value: _ThreadHeaderOverflowAction.editGroup,
          child: Text('Edit', style: menuStyle),
        ),
      );
    }
    if (c.isGroup && widget.onAddPeopleToGroupConversation != null) {
      items.add(
        PopupMenuItem(
          value: _ThreadHeaderOverflowAction.addPeople,
          child: Text('Add people', style: menuStyle),
        ),
      );
    }
    if (widget.onDeleteConversation != null) {
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
    final delete = widget.onDeleteConversation;
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
        packageDialogTheme: widget.packageDialogTheme,
        child: _MessengerDeleteChatDialog(
          conversationTitle: label,
          onDeleteConfirmed: () async {
            await Future<void>.sync(() => delete(c));
          },
          onDismissMobileThreadAfterDelete:
              widget.onDismissMobileThreadAfterConversationDelete,
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
          await widget.onEditGroupConversation?.call(c);
          return;
        case _ThreadHeaderOverflowAction.addPeople:
          await widget.onAddPeopleToGroupConversation?.call(c);
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
    final c = widget.conversation;
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
    final c = widget.conversation;
    final showOnlinePresence =
        c != null && !c.isGroup && c.isOnline != null;
    final menu = _overflowMenu(context, theme);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: widget.isMobile
            ? null
            : const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      padding: EdgeInsets.fromLTRB(widget.isMobile ? 4 : 12, 8, 8, 8),
      child: widget.isMobile
          ? SizedBox(
              height: 48,
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                      ),
                      MessengerAvatar(
                        label: c?.avatarLabel ?? 'CH',
                        imageUrl: c?.avatarUrl,
                        compact: true,
                        size: 34,
                        showOnlineIndicator: showOnlinePresence,
                        isOnline: c?.isOnline ?? false,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Text(
                      c?.title ?? 'No conversation',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
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
                  label: c?.avatarLabel ?? 'CH',
                  imageUrl: c?.avatarUrl,
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
                      Text(
                        c?.title ?? 'No conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                if (menu != null) menu,
              ],
            ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.dateSeparatorBackground,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _formatDate(date),
            style: TextStyle(
              color: theme.dateSeparatorText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthLabel(date.month)} ${date.year}';
  }

  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) {
      return '';
    }
    return months[month - 1];
  }
}

class _ThreadLoadingPlaceholder extends StatelessWidget {
  const _ThreadLoadingPlaceholder({
    super.key,
    required this.style,
  });

  final MessengerThreadLoadingStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final textStyle = style.placeholderTextStyle ??
        TextStyle(
          color: theme.subtleText,
          fontWeight: FontWeight.w600,
        );
    return Semantics(
      container: true,
      label: style.placeholderSemanticsLabel,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: style.placeholderIndicatorSize,
                height: style.placeholderIndicatorSize,
                child: CircularProgressIndicator(
                  strokeWidth: style.placeholderIndicatorStrokeWidth,
                  color: style.indicatorColor,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                style.placeholderMessage,
                style: textStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
