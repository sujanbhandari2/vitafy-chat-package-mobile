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
import 'messenger_default_inline_loading.dart';
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
    this.hasPendingAttachment = false,
    this.pendingAttachmentLabel,
    this.onClearPendingAttachment,
    this.threadLoadingStyle,
    this.threadFetchLoadingMode =
        MessengerThreadFetchLoadingMode.replaceMessageList,
    this.threadFetchLoadingBuilder,
    this.snapToBottomOnKeyboardInsetChange = true,
    this.composerReplyDraft,
    this.onComposerReplyDraftChanged,
    this.composerFocusNode,
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
  final bool hasPendingAttachment;
  final String? pendingAttachmentLabel;
  final VoidCallback? onClearPendingAttachment;
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
          final message = widget.messages[index];
          final mine = message.senderId == widget.currentUserId;
          final showDate = widget.showDateSeparators &&
              (index == 0 ||
                  !_isSameDay(
                    widget.messages[index - 1].createdAt,
                    message.createdAt,
                  ));

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDate) _DateSeparator(date: message.createdAt),
              MessengerMessageBubble(
                deleteActionTextStyle: Theme.of(context).textTheme.bodyMedium!,
                message: message,
                isMine: mine,
                currentUserId: widget.currentUserId,
                canDelete: widget.canDeleteMessage?.call(message) ?? mine,
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
                onSwipeToReply:
                    widget.onComposerReplyDraftChanged == null
                        ? null
                        : (MessengerChatMessage m) {
                            widget.onComposerReplyDraftChanged!(
                              MessengerComposerReplyDraft.fromMessage(m),
                            );
                            final focus = widget.composerFocusNode;
                            if (focus != null) {
                              SchedulerBinding.instance
                                  .addPostFrameCallback((_) {
                                if (focus.canRequestFocus) {
                                  focus.requestFocus();
                                }
                              });
                            }
                          },
              ),
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
            typingConversationId: widget.conversation?.id,
            onTypingStart: widget.onTypingStart,
            onTypingStop: widget.onTypingStop,
            hasPendingAttachment: widget.hasPendingAttachment,
            pendingAttachmentLabel: widget.pendingAttachmentLabel,
            onClearPendingAttachment: widget.onClearPendingAttachment,
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

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.isMobile,
    required this.conversation,
    this.onBack,
  });

  final bool isMobile;
  final MessengerConversation? conversation;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
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
              height: 48,
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                      ),
                      MessengerAvatar(
                        label: conversation?.avatarLabel ?? 'CH',
                        imageUrl: conversation?.avatarUrl,
                        compact: true,
                        size: 34,
                        showOnlineIndicator: conversation?.isOnline != null,
                        isOnline: conversation?.isOnline ?? false,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Text(
                      conversation?.title ?? 'No conversation',
                      textAlign: TextAlign.center,
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
            )
          : Row(
              children: [
                MessengerAvatar(
                  label: conversation?.avatarLabel ?? 'CH',
                  imageUrl: conversation?.avatarUrl,
                  compact: true,
                  size: 34,
                  showOnlineIndicator: conversation?.isOnline != null,
                  isOnline: conversation?.isOnline ?? false,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation?.title ?? 'No conversation',
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
