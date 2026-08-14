import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/messenger_conversation.dart';
import '../models/messenger_message.dart';
import '../models/messenger_attachment.dart';
import '../models/messenger_inbox_people.dart';
import '../models/messenger_thread_fetch_loading_mode.dart';
import '../models/messenger_user.dart';
import '../models/messenger_thread_loading_style.dart';
import '../models/messenger_thread_view_overrides.dart';
import '../models/messenger_typing.dart';
import 'messenger_composer_bar.dart';
import 'messenger_default_thread_header.dart';
import 'messenger_media_send_orchestrator.dart';
import 'messenger_default_inline_loading.dart';
import 'messenger_incoming_seen_reporter.dart';
import 'messenger_message_bubble.dart';
import 'messenger_thread_associated_people_panel.dart';
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
    this.onRetryUpload,
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
    this.threadViewOverrides,
    this.showAssociatedPeopleOnThread = false,
    this.associatedPeopleUsers,
    this.associatedPeopleSectionHeaderBuilder,
    this.associatedPeopleItemBuilder,
    this.associatedPeopleEmptyMessage =
        'No more associated people available to start a chat with.',
    this.openingDirectUserId = '',
    this.onOpenAssociatedPerson,
    this.currentPlatformUserId,
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
  final Future<void> Function(String messageId)? onRetryUpload;
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
  final ValueChanged<MessengerComposerReplyDraft?>? onComposerReplyDraftChanged;

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

  /// Optional overrides for header, bubbles, composer, and floating overlay.
  final MessengerThreadViewOverrides? threadViewOverrides;

  /// When true, shows associated people below the thread header (opt-in v2).
  final bool showAssociatedPeopleOnThread;

  /// Tenant directory for the optional associated-people thread panel.
  final List<MessengerUser>? associatedPeopleUsers;

  /// Optional header above associated people in the thread panel.
  final Widget Function(BuildContext context, int associatedPeopleCount)?
      associatedPeopleSectionHeaderBuilder;

  /// Custom row builder for associated people in the thread panel.
  final Widget Function(BuildContext context, MessengerAvailablePersonData data)?
      associatedPeopleItemBuilder;

  /// Empty copy when every associated person is already in this conversation.
  final String associatedPeopleEmptyMessage;

  /// Mirrors inbox direct-open busy state for associated-person taps.
  final String openingDirectUserId;

  /// Opens a direct chat when an associated person is tapped in the thread.
  final FutureOr<void> Function(MessengerUser user)? onOpenAssociatedPerson;

  /// Optional platform user id excluded from associated people (matches inbox).
  final String? currentPlatformUserId;

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

          final overrides = widget.threadViewOverrides;
          final bubbleBuilder = overrides?.messageBubbleBuilder;
          Widget bubble;
          if (bubbleBuilder != null) {
            bubble = bubbleBuilder(
              context,
              MessengerMessageBubbleContext(
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
                onRemoveReaction: widget.onRemoveReaction,
                onDelete: widget.onDelete == null
                    ? null
                    : () => widget.onDelete!(message.id),
                onRetryUpload: widget.onRetryUpload == null
                    ? null
                    : () => unawaited(widget.onRetryUpload!(message.id)),
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
                attachmentCaptionTextStyle: widget.attachmentCaptionTextStyle,
                packageDialogTheme: widget.packageDialogTheme,
              ),
            );
          } else {
            bubble = MessengerMessageBubble(
              packageDialogTheme: widget.packageDialogTheme,
              deleteActionTextStyle: Theme.of(context).textTheme.bodyMedium!,
              attachmentCaptionTextStyle: widget.attachmentCaptionTextStyle,
              contentBuilders: overrides?.messageContentBuilders,
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
              onDelete: widget.onDelete == null
                  ? null
                  : () => widget.onDelete!(message.id),
              onRetryUpload: widget.onRetryUpload == null
                  ? null
                  : () => unawaited(widget.onRetryUpload!(message.id)),
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
              showDeliveryStatus: true,
            );
          }

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

    final headerData = MessengerThreadHeaderData(
      conversation: widget.conversation,
      isMobile: widget.isMobile,
      onBack: widget.onBack,
      onEditGroupConversation: widget.onEditGroupConversation,
      onAddPeopleToGroupConversation: widget.onAddPeopleToGroupConversation,
      onDeleteConversation: widget.onDeleteConversation,
      onDismissMobileThreadAfterConversationDelete:
          widget.onDismissMobileThreadAfterConversationDelete,
      packageDialogTheme: widget.packageDialogTheme,
    );
    final overrides = widget.threadViewOverrides;
    final header = overrides?.headerBuilder != null
        ? overrides!.headerBuilder!(context, headerData)
        : MessengerDefaultThreadHeader(data: headerData);

    Widget innerViewport = ColoredBox(
      color: widget.isMobile ? theme.threadBackgroundMobile : theme.background,
      child: AnimatedSwitcher(
        duration: widget.contentTransitionDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: threadBody,
      ),
    );

    if (widget.conversation != null && typingLine.isNotEmpty) {
      innerViewport = Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(child: innerViewport),
          _RemoteTypingStrip(text: typingLine, theme: theme),
        ],
      );
    }

    final overlayBuilder = overrides?.threadOverlayBuilder;
    final Widget messageViewport;
    if (overlayBuilder != null) {
      messageViewport = LayoutBuilder(
        builder: (context, constraints) {
          final overlayData = MessengerThreadOverlayData(
            conversation: widget.conversation,
            bounds: Size(constraints.maxWidth, constraints.maxHeight),
            defaultTopOffset: overrides!.threadOverlayTopOffset,
          );
          final overlayChild = overlayBuilder(context, overlayData);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              innerViewport,
              if (!_isPositionedWidget(overlayChild))
                Positioned(
                  top: overlayData.defaultTopOffset,
                  left: 0,
                  right: 0,
                  child: overlayChild,
                )
              else
                overlayChild,
            ],
          );
        },
      );
    } else {
      messageViewport = innerViewport;
    }

    final stage = Column(
      children: [
        header,
        if (widget.showAssociatedPeopleOnThread &&
            widget.conversation != null &&
            widget.onOpenAssociatedPerson != null)
          MessengerThreadAssociatedPeoplePanel(
            conversation: widget.conversation,
            allPeople: widget.associatedPeopleUsers ?? const [],
            currentUserId: widget.currentUserId,
            currentPlatformUserId: widget.currentPlatformUserId,
            openingDirectUserId: widget.openingDirectUserId,
            onOpenAssociatedPerson: widget.onOpenAssociatedPerson,
            sectionHeaderBuilder: widget.associatedPeopleSectionHeaderBuilder,
            itemBuilder: widget.associatedPeopleItemBuilder,
            emptyMessage: widget.associatedPeopleEmptyMessage,
          ),
        Expanded(
          child: ClipRect(child: messageViewport),
        ),
        if (widget.conversation != null) _buildComposer(context),
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

  Widget _buildComposer(BuildContext context) {
    final composerData = MessengerComposerData(
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
    );
    final composerBuilder = widget.threadViewOverrides?.composerBuilder;
    if (composerBuilder != null) {
      return composerBuilder(context, composerData);
    }
    return MessengerComposerBar(
      controller: composerData.controller,
      isRecording: composerData.isRecording,
      isSending: composerData.isSending,
      onSend: composerData.onSend,
      onPickImage: composerData.onPickImage,
      onPickAudio: composerData.onPickAudio,
      onStartRecording: composerData.onStartRecording,
      onFinishRecording: composerData.onFinishRecording,
      onCancelRecording: composerData.onCancelRecording,
      onToggleRecording: composerData.onToggleRecording,
      onPickCamera: composerData.onPickCamera,
      onPickVideo: composerData.onPickVideo,
      onPickDocument: composerData.onPickDocument,
      hintText: composerData.hintText,
      inputTextStyle: composerData.inputTextStyle,
      hintTextStyle: composerData.hintTextStyle,
      fieldBackgroundColor: composerData.fieldBackgroundColor,
      fieldContentPadding: composerData.fieldContentPadding,
      attachmentSheetTitle: composerData.attachmentSheetTitle,
      attachmentOptions: composerData.attachmentOptions,
      attachmentOptionTextStyle: composerData.attachmentOptionTextStyle,
      typingConversationId: composerData.typingConversationId,
      onTypingStart: composerData.onTypingStart,
      onTypingStop: composerData.onTypingStop,
      pendingAttachments: composerData.pendingAttachments,
      onRemovePendingAttachment: composerData.onRemovePendingAttachment,
      onClearAllPendingAttachments: composerData.onClearAllPendingAttachments,
      replyDraft: composerData.replyDraft,
      onCancelReplyDraft: composerData.onCancelReplyDraft,
      textFieldFocusNode: composerData.textFieldFocusNode,
    );
  }
}

bool _isPositionedWidget(Widget widget) {
  return widget is Positioned;
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

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final localDate = date.toLocal();
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
            _formatDate(localDate),
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
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}
