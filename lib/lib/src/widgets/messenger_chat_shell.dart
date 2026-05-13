import 'dart:async';

import 'package:flutter/material.dart';

import '../client/chat_auth.dart';
import '../client/chat_client.dart';
import '../client/inbox/delivery_status.dart';
import '../client/models/chat_message.dart';
import '../models/messenger_conversation.dart';
import '../models/messenger_group_create_request.dart';
import '../models/messenger_message.dart';
import '../models/messenger_thread_fetch_loading_mode.dart';
import '../models/messenger_thread_loading_style.dart';
import '../models/messenger_user.dart';
import '../models/messenger_search_visibility.dart';
import '../models/messenger_attachment.dart';
import '../models/messenger_typing.dart';
import '../theme/messenger_theme.dart';
import '../utils/messenger_thread_scroll.dart';
import 'messenger_chat_thread.dart';
import 'messenger_conversation_list.dart';
import 'messenger_list_search_chrome.dart';
import 'messenger_default_inline_loading.dart';
import 'messenger_media_send_orchestrator.dart';

/// [RouteSettings.name] for the pushed full-screen mobile thread so we can
/// [Navigator.popUntil] without popping the host chat route above this shell.
const String _kMobileThreadRouteName = 'health_messenger_ui.mobile_thread';

bool _routeIsNotMobileThreadRoute(Route<dynamic> route) {
  return route.settings.name != _kMobileThreadRouteName;
}

class MessengerChatShell extends StatefulWidget {
  const MessengerChatShell({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.conversations,
    required this.users,
    required this.selectedConversationId,
    required this.messages,
    required this.composerController,
    required this.messagesScrollController,
    required this.isSending,
    required this.isRecording,
    required this.onRefresh,
    this.enablePullToRefresh = true,
    this.isConversationListLoading = false,
    this.isListPaneRefreshing = false,
    this.conversationListLoadingBuilder,
    this.suggestedPaneLoadingBuilder,
    required this.onLogout,
    required this.onSelectConversation,
    required this.onOpenDirectChat,
    this.onCreateGroupSelected,
    this.onCreateGroupRequested,
    this.isCreatingGroup = false,
    this.groupNameInputBehavior = MessengerGroupNameInputBehavior.hidden,
    this.groupNameFieldLabelText = 'Group name',
    this.groupNameFieldHintText = 'Enter a group name',
    this.groupNameRequiredErrorText = 'Enter a group name to continue.',
    required this.onSend,
    required this.onPickImage,
    required this.onPickAudio,
    required this.onToggleRecording,
    this.onPickCamera,
    this.onPickDocument,
    this.onPickVideo,
    this.onReact,
    this.onRemoveReaction,
    this.onDelete,
    this.onMarkSeen,
    this.canDeleteMessage,
    this.onEditMessage,
    this.canEditMessage,
    this.searchVisibility = MessengerSearchVisibility.auto,
    this.searchThreshold = 10,
    this.searchHintText = 'Search',
    this.searchInputTextStyle,
    this.searchHintTextStyle,
    this.searchFieldBackgroundColor,
    this.searchFieldContentPadding,
    this.searchIconColor,
    this.searchFieldBorderRadius,
    this.emptyUsersMessage = 'No users available right now.',
    this.emptyConversationsMessage = 'No conversations available yet.',
    this.emptyUsersBuilder,
    this.emptyConversationsBuilder,
    this.showStartChatFab = true,
    this.enableReactions = true,
    this.reactionOptions = const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
    this.showDateSeparators = true,
    this.composerHintText = 'Type your message...',
    this.composerInputTextStyle,
    this.composerHintTextStyle,
    this.composerFieldBackgroundColor,
    this.composerFieldContentPadding,
    this.attachmentSheetTitle = 'Attachments',
    this.attachmentOptions,
    this.theme,
    /// Merged with [Theme.of] around package [AlertDialog]s (e.g. delete chat).
    this.packageDialogTheme,
    this.desktopBreakpoint = 980,
    this.emptyMessagesMessage = 'No messages yet.',
    this.emptyMessagesBuilder,
    this.isConversationLoading = false,
    this.loadingConversationId,
    this.loadingMessagesBuilder,
    this.threadTransitionDuration = const Duration(milliseconds: 180),
    this.remoteTypingUsers = const [],
    this.typingIndicatorPrefix = '',
    this.onTypingStart,
    this.onTypingStop,
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
    this.enablePackageMediaSending = false,
    this.mediaChatClient,
    this.mediaChatAuth,
    this.mediaSenderId,
    this.mediaPicker,
    this.mediaRecorder,
    this.onMediaSendStart,
    this.onMediaSendProgress,
    this.onMediaSendError,
    this.onMediaMessageSent,
    this.onMediaMessageSentForConversation,
    this.autoScrollThreadToBottom = true,
    this.threadScrollToBottomAnimated = false,
    this.threadScrollToBottomAnimationDuration =
        const Duration(milliseconds: 240),
    this.threadScrollToBottomAnimationCurve = Curves.easeOut,
    this.threadLoadingStyle,
    this.threadFetchLoadingMode =
        MessengerThreadFetchLoadingMode.replaceMessageList,
    this.threadFetchLoadingBuilder,
    this.prepareOutgoingConversation,
    this.onMobileThreadClosed,
    this.suggestedPeopleBuilder,
    this.onEditGroupConversation,
    this.onAddPeopleToGroupConversation,
    this.onDeleteConversation,
    this.composerReplyDraft,
    this.onComposerReplyDraftChanged,
    this.composerFocusNode,
    this.attachmentCaptionTextStyle,
    this.attachmentOptionTextStyle,
  });

  final String currentUserId;
  final String currentUserName;
  final List<MessengerConversation> conversations;
  final List<MessengerUser> users;
  final String? selectedConversationId;
  final List<MessengerChatMessage> messages;
  final TextEditingController composerController;
  final ScrollController messagesScrollController;
  final bool isSending;
  final bool isRecording;

  /// Reloads conversations/users from the host. Used by the header Edit
  /// action and by pull-to-refresh on the conversation list when
  /// [enablePullToRefresh] is true.
  final Future<void> Function() onRefresh;

  /// When true (default), the conversation list pane wraps its scrollable
  /// body in a [RefreshIndicator] that calls [onRefresh].
  final bool enablePullToRefresh;

  /// When true, [MessengerConversationList] replaces its peer scroll body with
  /// a centered spinner until the conversation list snapshot is ready.
  ///
  /// When the inbox is empty and [suggestedPeopleBuilder] is used, this also
  /// replaces the suggested slot with [suggestedPaneLoadingBuilder] (or the
  /// default inline loader) **until conversations are resolved** — not while
  /// tenant users alone are loading; use [MessengerSuggestedPeoplePanel.isLoading]
  /// for that.
  final bool isConversationListLoading;

  /// Deprecated: use [isConversationListLoading]. Still OR-ed into conversation
  /// list body loading for backwards compatibility, but no longer blocks the
  /// suggested-people builder when only this flag is true.
  @Deprecated(
    'Use isConversationListLoading. OR-ed into conversation list loading only.',
  )
  final bool isListPaneRefreshing;

  /// Overrides the default centered spinner while conversation list loading is
  /// active on [MessengerConversationList].
  final WidgetBuilder? conversationListLoadingBuilder;

  /// Overrides loading UI for the suggested-people slot when
  /// [isConversationListLoading] is true and the inbox is still empty (waiting
  /// for the conversation snapshot). Falls back to [conversationListLoadingBuilder],
  /// then [MessengerDefaultInlineLoading].
  final WidgetBuilder? suggestedPaneLoadingBuilder;

  final VoidCallback onLogout;
  final FutureOr<void> Function(String conversationId) onSelectConversation;
  final FutureOr<void> Function(MessengerUser user) onOpenDirectChat;
  final FutureOr<void> Function(List<MessengerUser> selectedUsers)?
      onCreateGroupSelected;
  final FutureOr<void> Function(MessengerGroupCreateRequest request)?
      onCreateGroupRequested;
  final bool isCreatingGroup;
  final MessengerGroupNameInputBehavior groupNameInputBehavior;
  final String groupNameFieldLabelText;
  final String groupNameFieldHintText;
  final String groupNameRequiredErrorText;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickAudio;
  final VoidCallback onToggleRecording;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickDocument;
  final VoidCallback? onPickVideo;
  final Future<void> Function(String messageId, String reactionType)? onReact;
  final Future<void> Function(String messageId, String reactionType)?
      onRemoveReaction;
  final Future<void> Function(String messageId)? onDelete;
  final Future<void> Function(String messageId)? onMarkSeen;
  final bool Function(MessengerChatMessage message)? canDeleteMessage;
  final Future<void> Function(String messageId, String currentText)? onEditMessage;
  final bool Function(MessengerChatMessage message)? canEditMessage;
  final MessengerSearchVisibility searchVisibility;
  final int searchThreshold;
  final String searchHintText;
  final TextStyle? searchInputTextStyle;
  final TextStyle? searchHintTextStyle;
  final Color? searchFieldBackgroundColor;
  final EdgeInsetsGeometry? searchFieldContentPadding;
  final Color? searchIconColor;
  final double? searchFieldBorderRadius;
  final String emptyUsersMessage;
  final String emptyConversationsMessage;
  final WidgetBuilder? emptyUsersBuilder;
  final WidgetBuilder? emptyConversationsBuilder;
  final bool showStartChatFab;
  final bool enableReactions;
  final List<String> reactionOptions;
  final bool showDateSeparators;
  final String composerHintText;
  final TextStyle? composerInputTextStyle;
  final TextStyle? composerHintTextStyle;
  final Color? composerFieldBackgroundColor;
  final EdgeInsetsGeometry? composerFieldContentPadding;
  final String attachmentSheetTitle;
  final List<MessengerAttachmentOption>? attachmentOptions;
  final TextStyle? attachmentOptionTextStyle;
  final MessengerThemeData? theme;

  /// Optional [ThemeData] nested under the host [Theme] when the package shows
  /// modal dialogs ([AlertDialog], image preview, etc.). Prefer
  /// `Theme.of(context).copyWith(dialogTheme: DialogTheme(...))` so the value is
  /// a complete [ThemeData]; arbitrary field-level merging is not performed.
  final ThemeData? packageDialogTheme;

  final double desktopBreakpoint;
  final String emptyMessagesMessage;
  final WidgetBuilder? emptyMessagesBuilder;
  final bool isConversationLoading;
  final String? loadingConversationId;
  final WidgetBuilder? loadingMessagesBuilder;
  final Duration threadTransitionDuration;
  final List<MessengerTypingUser> remoteTypingUsers;
  final String typingIndicatorPrefix;
  final Future<void> Function(String conversationId)? onTypingStart;
  final Future<void> Function(String conversationId)? onTypingStop;
  final bool showHeaderEditButton;
  final bool showHeaderTitle;
  final bool showHeaderComposeButton;
  final WidgetBuilder? startNewChatEmptyBuilder;

  /// When true and the Start New Chat sheet opens with an empty user list,
  /// the sheet shows an inline loader instead of the empty-state copy.
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
  final bool enablePackageMediaSending;
  final ChatClient? mediaChatClient;
  final ChatAuth? mediaChatAuth;
  final String? mediaSenderId;
  final MessengerMediaPicker? mediaPicker;
  final MessengerAudioRecorder? mediaRecorder;
  final ValueChanged<MessengerChatMessage>? onMediaSendStart;
  final void Function(String pendingMessageId, double progress)?
      onMediaSendProgress;
  final void Function(String pendingMessageId, Object error)? onMediaSendError;
  final ValueChanged<MessengerChatMessage>? onMediaMessageSent;
  final void Function(String conversationId, MessengerChatMessage message)?
      onMediaMessageSentForConversation;

  /// When true, [MessengerChatShell] scrolls [messagesScrollController] to the
  /// latest message after conversation changes, loading state changes, or the
  /// message list grows / last message id changes.
  final bool autoScrollThreadToBottom;

  /// When false (default), uses [MessengerThreadScroll.scheduleJumpToBottom].
  final bool threadScrollToBottomAnimated;

  final Duration threadScrollToBottomAnimationDuration;
  final Curve threadScrollToBottomAnimationCurve;

  /// Customizes the default **empty-thread** loading placeholder when
  /// [loadingMessagesBuilder] is null. See [threadFetchLoadingMode] for reload
  /// behavior when messages are already shown.
  final MessengerThreadLoadingStyle? threadLoadingStyle;

  /// When the selected conversation is loading and messages are already shown.
  final MessengerThreadFetchLoadingMode threadFetchLoadingMode;

  /// Replaces the message list during refetch when [threadFetchLoadingMode] is
  /// [MessengerThreadFetchLoadingMode.replaceMessageList].
  final WidgetBuilder? threadFetchLoadingBuilder;

  /// When set, invoked before package media upload so the host can replace a
  /// placeholder conversation id (for example a draft direct chat) with a
  /// real server id. Return null to abort the send.
  final Future<String?> Function(String conversationId)?
      prepareOutgoingConversation;

  /// Called after the full-screen mobile thread route is popped (back), with
  /// the [conversationId] for the thread that was shown. Hosts should call
  /// [ChatSession.leaveConversation] (or equivalent) so the socket inbox no
  /// longer treats that room as active (otherwise inbound messages can still
  /// emit read receipts for the sender).
  final void Function(String conversationId)? onMobileThreadClosed;

  /// Optional opt-in slot for an introductory "Suggested people" surface
  /// (typically a [MessengerSuggestedPeoplePanel]). When non-null and
  /// [conversations] is empty, the shell renders this builder's widget in
  /// place of the conversation list pane (mobile and desktop). When null,
  /// the conversation list and its existing empty placeholder are unchanged.
  ///
  /// The returned widget is wrapped in [MessengerListSearchChrome] using the
  /// same [searchFieldBackgroundColor], [searchIconColor], [searchHintTextStyle],
  /// [searchFieldContentPadding], [searchFieldBorderRadius], and
  /// [searchInputTextStyle] as [MessengerConversationList], so
  /// [MessengerSuggestedPeoplePanel] search and group-name fields stay aligned
  /// with the inbox and start-new-chat sheet without extra wiring.
  ///
  /// The third argument is the shell-provided opener: on mobile it runs the
  /// same direct-chat flow as the conversation list (including navigation to
  /// the full-screen thread). On desktop it only invokes the host callback.
  final Widget Function(
    BuildContext context,
    List<MessengerUser> users,
    Future<void> Function(MessengerUser user) openDirectChat,
  )? suggestedPeopleBuilder;

  final FutureOr<void> Function(MessengerConversation conversation)?
      onEditGroupConversation;
  final FutureOr<void> Function(MessengerConversation conversation)?
      onAddPeopleToGroupConversation;

  /// Deletes the conversation (host API, cache, etc.) after the user
  /// confirms in the package delete dialog shown from the thread header.
  ///
  /// Do not show a second confirmation dialog in this callback, and do not
  /// pop the pushed mobile thread route yourself — the thread header shows the
  /// package confirmation dialog, then dismisses that route after delete
  /// succeeds so navigation stays a single step back to the conversation list.
  ///
  /// The shell also closes that route when the opened conversation disappears
  /// from [conversations] and [selectedConversationId] no longer pins it (for
  /// example sync from another device while not in the delete flow).
  final FutureOr<void> Function(MessengerConversation conversation)?
      onDeleteConversation;

  /// Shown above the composer while replying to a message (swipe-to-reply).
  final MessengerComposerReplyDraft? composerReplyDraft;

  /// Host owns draft state; invoked when the user swipes to reply or cancels.
  final ValueChanged<MessengerComposerReplyDraft?>? onComposerReplyDraftChanged;

  /// Optional [FocusNode] for the thread composer field.
  final FocusNode? composerFocusNode;

  /// Passed through to each [MessengerMessageBubble] in the thread.
  final TextStyle? attachmentCaptionTextStyle;

  @override
  State<MessengerChatShell> createState() => _MessengerChatShellState();
}

class _MessengerChatShellState extends State<MessengerChatShell> {
  /// [isConversationListLoading] plus deprecated [isListPaneRefreshing] for the
  /// conversation list body only.
  bool get _effectiveConversationListLoading =>
      widget.isConversationListLoading || widget.isListPaneRefreshing;

  /// Full-pane suggested-slot spinner: only while the conversation snapshot is
  /// loading, not for tenant-user-only fetches.
  bool get _suggestedSlotWaitingForConversations =>
      widget.isConversationListLoading;

  String _openingDirectUserId = '';
  final Map<String, List<MessengerChatMessage>> _localMessagesByConversation =
      <String, List<MessengerChatMessage>>{};
  final Map<String, MessengerPickedMedia> _pendingMediaByConversation =
      <String, MessengerPickedMedia>{};
  final Set<String> _mediaSendingConversationIds = <String>{};
  final ValueNotifier<int> _mobileThreadVersion = ValueNotifier<int>(0);
  /// Ensures at most one auto-[Navigator.maybePop] is scheduled for the
  /// full-screen mobile thread while [ValueListenableBuilder] rebuilds.
  bool _mobileThreadAutoClosePopScheduled = false;

  /// While [onDeleteConversation] runs on mobile, the shell already pops the
  /// thread when the callback finishes; suppress the list-driven auto-close so
  /// [Navigator] does not pop twice.
  bool _suppressMobileThreadAutoCloseOnce = false;
  bool _packageRecording = false;
  String? _recordingConversationId;
  MessengerMediaSendOrchestrator? _cachedMediaOrchestrator;
  ChatClient? _cachedMediaClient;
  ChatAuth? _cachedMediaAuth;
  String? _cachedMediaSenderId;
  MessengerMediaPicker? _cachedMediaPicker;
  MessengerAudioRecorder? _cachedMediaRecorder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.autoScrollThreadToBottom ||
          widget.messages.isEmpty) {
        return;
      }
      _runThreadScrollToBottom();
    });
  }

  void _runThreadScrollToBottom() {
    if (widget.threadScrollToBottomAnimated) {
      MessengerThreadScroll.scheduleAnimateToBottom(
        widget.messagesScrollController,
        duration: widget.threadScrollToBottomAnimationDuration,
        curve: widget.threadScrollToBottomAnimationCurve,
      );
    } else {
      MessengerThreadScroll.scheduleJumpToBottom(
        widget.messagesScrollController,
      );
    }
  }

  void _scheduleMobileThreadRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _mobileThreadVersion.value++;
    });
  }

  /// Completes after the next frame, so parent/host [setState]/notifier updates
  /// can rebuild this widget before we read [MessengerChatShell.selectedConversationId].
  Future<void> _waitUntilPostFrame() async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;
  }

  /// Normalized map key for [_pendingMediaByConversation] (trimmed non-empty ids).
  String? _conversationKey(String? conversationId) {
    final trimmed = conversationId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  @override
  void didUpdateWidget(covariant MessengerChatShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldRefreshMobileThread =
        oldWidget.selectedConversationId != widget.selectedConversationId ||
            !identical(oldWidget.messages, widget.messages) ||
            !identical(oldWidget.conversations, widget.conversations) ||
            oldWidget.isConversationLoading != widget.isConversationLoading ||
            oldWidget.loadingConversationId != widget.loadingConversationId ||
            oldWidget.composerReplyDraft?.targetMessageId !=
                widget.composerReplyDraft?.targetMessageId;
    if (shouldRefreshMobileThread) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _mobileThreadVersion.value++;
      });
    }

    if (widget.autoScrollThreadToBottom &&
        _shouldScheduleThreadScrollToBottom(oldWidget)) {
      _runThreadScrollToBottom();
    }
  }

  bool _shouldScheduleThreadScrollToBottom(MessengerChatShell oldWidget) {
    if (oldWidget.selectedConversationId != widget.selectedConversationId) {
      return true;
    }
    if (oldWidget.isConversationLoading != widget.isConversationLoading) {
      return true;
    }
    final oldMessages = oldWidget.messages;
    final newMessages = widget.messages;
    if (oldMessages.length != newMessages.length) {
      return true;
    }
    if (oldMessages.isEmpty) {
      return false;
    }
    return oldMessages.last.id != newMessages.last.id;
  }

  @override
  void dispose() {
    _mobileThreadVersion.dispose();
    super.dispose();
  }

  /// When non-null (mobile pushed thread only), wraps [host] so list-driven
  /// auto-close does not [Navigator.maybePop] while delete is in flight (which
  /// would stack with the thread dismissal the package performs after the
  /// confirmation dialog closes).
  FutureOr<void> Function(MessengerConversation conversation)?
      _wrapDeleteConversationWithMobilePop(
    BuildContext routeContext,
    FutureOr<void> Function(MessengerConversation conversation)? host,
  ) {
    if (host == null) {
      return null;
    }
    return (MessengerConversation c) async {
      _suppressMobileThreadAutoCloseOnce = true;
      try {
        await Future<void>.sync(() => host(c));
      } finally {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _suppressMobileThreadAutoCloseOnce = false;
            });
          });
        });
      }
    };
  }

  void _scheduleDismissMobileThreadAfterDelete() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Remove only our named mobile thread route. [maybePop] can remove the
      // wrong route if the stack is mid-update; [popUntil] is stable for the
      // example stack: Configuration → Chat → Thread → (dialog).
      Navigator.of(context, rootNavigator: true)
          .popUntil(_routeIsNotMobileThreadRoute);
    });
  }

  Widget _buildThread({
    required bool isMobile,
    VoidCallback? onBack,
    String? fallbackConversationId,
    bool forceLoading = false,
    BuildContext? mobileRouteContextForDeletePop,
  }) {
    final hostTrimmed = widget.selectedConversationId?.trim();
    final fallbackTrimmed = fallbackConversationId?.trim();
    final hostHasSelection = hostTrimmed != null && hostTrimmed.isNotEmpty;
    final selectedConversationId = hostHasSelection
        ? hostTrimmed
        : (fallbackTrimmed != null && fallbackTrimmed.isNotEmpty
            ? fallbackTrimmed
            : null);
    final selectedConversation = _conversationForShellId(
          selectedConversationId,
        ) ??
        (selectedConversationId != null &&
                selectedConversationId.trim().isNotEmpty
            ? MessengerConversation(
                id: selectedConversationId.trim(),
                title: 'Chat',
                subtitle: '',
                avatarLabel: 'CH',
                createdAt: DateTime.now(),
              )
            : null);
    final isSelectedConversationLoading = selectedConversationId != null &&
        (forceLoading ||
            (widget.isConversationLoading &&
                (widget.loadingConversationId == null ||
                    _conversationIdsEqual(
                      widget.loadingConversationId,
                      selectedConversationId,
                    ))));
    final rawThreadMessages = _conversationIdsEqual(
      widget.selectedConversationId,
      selectedConversationId,
    )
        ? _messagesForConversation(widget.selectedConversationId)
        : const <MessengerChatMessage>[];
    final threadMessages = rawThreadMessages;
    final pendingMediaKey = _conversationKey(selectedConversationId);
    final pendingMedia = pendingMediaKey == null
        ? null
        : _pendingMediaByConversation[pendingMediaKey];
    final hasPendingAttachment = pendingMedia != null;
    final isMediaSending = pendingMediaKey != null &&
        _mediaSendingConversationIds.contains(pendingMediaKey);
    final isPackageRecording = _packageRecording &&
        selectedConversationId != null &&
        selectedConversationId == _recordingConversationId;

    return MessengerChatThread(
      isMobile: isMobile,
      onBack: onBack,
      conversation: selectedConversation,
      messages: threadMessages,
      snapToBottomOnKeyboardInsetChange: widget.autoScrollThreadToBottom,
      packageDialogTheme: widget.packageDialogTheme,
      isConversationLoading: isSelectedConversationLoading,
      loadingMessagesBuilder: widget.loadingMessagesBuilder,
      threadLoadingStyle: widget.threadLoadingStyle,
      threadFetchLoadingMode: widget.threadFetchLoadingMode,
      threadFetchLoadingBuilder: widget.threadFetchLoadingBuilder,
      contentTransitionDuration: widget.threadTransitionDuration,
      currentUserId: widget.currentUserId,
      composerController: widget.composerController,
      messagesScrollController: widget.messagesScrollController,
      isSending: widget.isSending || isMediaSending,
      isRecording: widget.isRecording || isPackageRecording,
      onSend: () {
        unawaited(_handleSendPressed(selectedConversationId));
      },
      onPickImage: () {
        unawaited(
          _handleMediaPick(
            kind: MessengerMediaKind.image,
            fallback: widget.onPickImage,
          ),
        );
      },
      onPickAudio: () {
        unawaited(
          _handleMediaPick(
            kind: MessengerMediaKind.voice,
            fallback: widget.onPickAudio,
          ),
        );
      },
      onStartRecording: () {
        unawaited(_handleStartRecording(selectedConversationId));
      },
      onFinishRecording: () {
        unawaited(_handleFinishRecording(selectedConversationId));
      },
      onCancelRecording: () {
        unawaited(_handleCancelRecording(selectedConversationId));
      },
      onToggleRecording: widget.onToggleRecording,
      onPickCamera: widget.onPickCamera == null
          ? null
          : () {
              unawaited(
                _handleMediaPick(
                  kind: MessengerMediaKind.camera,
                  fallback: widget.onPickCamera!,
                ),
              );
            },
      onPickVideo: widget.onPickVideo == null
          ? null
          : () {
              unawaited(
                _handleMediaPick(
                  kind: MessengerMediaKind.video,
                  fallback: widget.onPickVideo!,
                ),
              );
            },
      onPickDocument: widget.onPickDocument == null
          ? null
          : () {
              unawaited(
                _handleMediaPick(
                  kind: MessengerMediaKind.file,
                  fallback: widget.onPickDocument!,
                ),
              );
            },
      composerHintText: widget.composerHintText,
      composerInputTextStyle: widget.composerInputTextStyle,
      composerHintTextStyle: widget.composerHintTextStyle,
      composerFieldBackgroundColor: widget.composerFieldBackgroundColor,
      composerFieldContentPadding: widget.composerFieldContentPadding,
      attachmentSheetTitle: widget.attachmentSheetTitle,
      attachmentOptions: widget.attachmentOptions,
      attachmentOptionTextStyle: widget.attachmentOptionTextStyle,
      onReact: widget.onReact,
      onRemoveReaction: widget.onRemoveReaction,
      onDelete: widget.onDelete,
      onMarkSeen: widget.onMarkSeen,
      canDeleteMessage: widget.canDeleteMessage,
      onEditMessage: widget.onEditMessage,
      canEditMessage: widget.canEditMessage,
      enableReactions: widget.enableReactions,
      reactionOptions: widget.reactionOptions,
      showDateSeparators: widget.showDateSeparators,
      emptyMessagesMessage: widget.emptyMessagesMessage,
      emptyMessagesBuilder: widget.emptyMessagesBuilder,
      remoteTypingUsers: widget.remoteTypingUsers,
      typingIndicatorPrefix: widget.typingIndicatorPrefix,
      onTypingStart: widget.onTypingStart,
      onTypingStop: widget.onTypingStop,
      hasPendingAttachment: hasPendingAttachment,
      pendingAttachmentLabel: pendingMedia?.displayName,
      onClearPendingAttachment: !hasPendingAttachment
          ? null
          : () {
              setState(() {
                final k = _conversationKey(selectedConversationId);
                if (k != null) {
                  _pendingMediaByConversation.remove(k);
                }
              });
              _scheduleMobileThreadRefresh();
            },
      composerReplyDraft: widget.composerReplyDraft,
      onComposerReplyDraftChanged: widget.onComposerReplyDraftChanged,
      composerFocusNode: widget.composerFocusNode,
      attachmentCaptionTextStyle: widget.attachmentCaptionTextStyle,
      onEditGroupConversation: widget.onEditGroupConversation,
      onAddPeopleToGroupConversation: widget.onAddPeopleToGroupConversation,
      onDeleteConversation: mobileRouteContextForDeletePop == null
          ? widget.onDeleteConversation
          : _wrapDeleteConversationWithMobilePop(
              mobileRouteContextForDeletePop,
              widget.onDeleteConversation,
            ),
      onDismissMobileThreadAfterConversationDelete:
          mobileRouteContextForDeletePop == null
              ? null
              : _scheduleDismissMobileThreadAfterDelete,
    );
  }

  Future<void> _openThreadRouteInternal(
    BuildContext context, {
    required MessengerThemeData themeData,
    required String? fallbackConversationId,
    required bool forceLoading,
  }) async {
    final selected = widget.selectedConversationId?.trim();
    final fallback = fallbackConversationId?.trim();
    final mobileClosedConversationId = (selected != null && selected.isNotEmpty)
        ? selected
        : (fallback != null && fallback.isNotEmpty ? fallback : '');

    _mobileThreadAutoClosePopScheduled = false;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: _kMobileThreadRouteName),
        builder: (routeContext) => MessengerTheme(
          data: themeData,
          child: Scaffold(
            body: SafeArea(
              child: ValueListenableBuilder<int>(
                valueListenable: _mobileThreadVersion,
                builder: (_, __, ___) {
                  final hostSel = widget.selectedConversationId?.trim();
                  final hostHasSelection =
                      hostSel != null && hostSel.isNotEmpty;
                  final openedId = mobileClosedConversationId.trim();
                  if (openedId.isNotEmpty) {
                    final stillThere = widget.conversations.any(
                      (c) => c.id.trim() == openedId,
                    );
                    final hostPinsOpened =
                        hostHasSelection && hostSel == openedId;
                    if (!stillThere &&
                        !hostPinsOpened &&
                        !_mobileThreadAutoClosePopScheduled &&
                        !_suppressMobileThreadAutoCloseOnce) {
                      // [_mobileThreadVersion] can change several times while the
                      // host updates [conversations] / selection; only one pop.
                      _mobileThreadAutoClosePopScheduled = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!routeContext.mounted) {
                          return;
                        }
                        Navigator.of(routeContext, rootNavigator: true)
                            .popUntil(_routeIsNotMobileThreadRoute);
                      });
                    }
                  }
                  return _buildThread(
                    isMobile: true,
                    mobileRouteContextForDeletePop: routeContext,
                    onBack: () => Navigator.of(routeContext, rootNavigator: true)
                        .popUntil(_routeIsNotMobileThreadRoute),
                    fallbackConversationId: fallbackConversationId?.trim(),
                    forceLoading: forceLoading &&
                        !hostHasSelection &&
                        !_conversationIdsEqual(
                          widget.selectedConversationId,
                          fallbackConversationId,
                        ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    _mobileThreadAutoClosePopScheduled = false;
    if (!mounted) {
      return;
    }
    if (mobileClosedConversationId.isNotEmpty) {
      widget.onMobileThreadClosed?.call(mobileClosedConversationId);
    }
  }

  List<MessengerChatMessage> _messagesForConversation(String? conversationId) {
    if (conversationId == null) {
      return widget.messages;
    }
    final key = conversationId.trim();
    final local = _localMessagesByConversation[key] ?? const [];
    if (local.isEmpty) {
      return widget.messages;
    }
    final hostIds = widget.messages.map((item) => item.id).toSet();
    final merged = <MessengerChatMessage>[
      ...widget.messages,
      ...local.where((item) => !hostIds.contains(item.id)),
    ];
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  MessengerMediaSendOrchestrator? _buildOrchestrator() {
    if (!widget.enablePackageMediaSending) {
      _clearOrchestratorCache();
      return null;
    }
    final client = widget.mediaChatClient;
    final auth = widget.mediaChatAuth;
    final senderId = widget.mediaSenderId;
    final picker = widget.mediaPicker;
    final recorder = widget.mediaRecorder;
    if (client == null ||
        auth == null ||
        senderId == null ||
        senderId.isEmpty) {
      _clearOrchestratorCache();
      return null;
    }
    final hasSameConfig = _cachedMediaOrchestrator != null &&
        identical(_cachedMediaClient, client) &&
        identical(_cachedMediaAuth, auth) &&
        _cachedMediaSenderId == senderId &&
        identical(_cachedMediaPicker, picker) &&
        identical(_cachedMediaRecorder, recorder);
    if (hasSameConfig) {
      return _cachedMediaOrchestrator;
    }
    final orchestrator = MessengerMediaSendOrchestrator(
      client: client,
      auth: auth,
      senderId: senderId,
      picker: picker,
      recorder: recorder,
    );
    _cachedMediaOrchestrator = orchestrator;
    _cachedMediaClient = client;
    _cachedMediaAuth = auth;
    _cachedMediaSenderId = senderId;
    _cachedMediaPicker = picker;
    _cachedMediaRecorder = recorder;
    return orchestrator;
  }

  void _clearOrchestratorCache() {
    _cachedMediaOrchestrator = null;
    _cachedMediaClient = null;
    _cachedMediaAuth = null;
    _cachedMediaSenderId = null;
    _cachedMediaPicker = null;
    _cachedMediaRecorder = null;
  }

  Future<void> _handleStartRecording(String? conversationId) async {
    final recordingKey =
        _conversationKey(conversationId ?? widget.selectedConversationId);
    if (recordingKey == null) {
      return;
    }
    final orchestrator = _buildOrchestrator();
    if (orchestrator == null) {
      widget.onToggleRecording();
      return;
    }
    if (_packageRecording || orchestrator.isRecording) {
      return;
    }
    try {
      await orchestrator.startVoiceRecording();
      if (!mounted) {
        return;
      }
      setState(() {
        _packageRecording = true;
        _recordingConversationId = recordingKey;
      });
      _scheduleMobileThreadRefresh();
    } catch (error) {
      widget.onMediaSendError?.call('record-start', error);
    }
  }

  Future<void> _handleFinishRecording(String? conversationId) async {
    final targetConversationId = conversationId ??
        _recordingConversationId ??
        widget.selectedConversationId;
    if (targetConversationId == null || targetConversationId.isEmpty) {
      return;
    }
    final orchestrator = _buildOrchestrator();
    if (orchestrator == null) {
      widget.onToggleRecording();
      return;
    }
    if (!orchestrator.isRecording && !_packageRecording) {
      return;
    }
    try {
      final picked = await orchestrator.finishVoiceRecording();
      if (!mounted) {
        return;
      }
      final finishKey = _conversationKey(targetConversationId);
      setState(() {
        _packageRecording = false;
        _recordingConversationId = null;
        if (picked != null && finishKey != null) {
          _pendingMediaByConversation[finishKey] = picked;
        }
      });
      _scheduleMobileThreadRefresh();
    } catch (error) {
      if (mounted) {
        setState(() {
          _packageRecording = false;
          _recordingConversationId = null;
        });
      }
      widget.onMediaSendError?.call('record-stop', error);
    }
  }

  Future<void> _handleCancelRecording(String? conversationId) async {
    final targetConversationId = conversationId ??
        _recordingConversationId ??
        widget.selectedConversationId;
    if (targetConversationId == null || targetConversationId.isEmpty) {
      return;
    }
    final orchestrator = _buildOrchestrator();
    if (orchestrator == null) {
      widget.onToggleRecording();
      return;
    }
    if (!orchestrator.isRecording && !_packageRecording) {
      return;
    }
    try {
      await orchestrator.cancelVoiceRecording();
    } catch (error) {
      widget.onMediaSendError?.call('record-cancel', error);
    } finally {
      if (mounted) {
        setState(() {
          _packageRecording = false;
          _recordingConversationId = null;
        });
      }
      _scheduleMobileThreadRefresh();
    }
  }

  Future<void> _handleMediaPick({
    required MessengerMediaKind kind,
    required VoidCallback fallback,
  }) async {
    final orchestrator = _buildOrchestrator();
    final pickKey = _conversationKey(widget.selectedConversationId);
    if (orchestrator == null || pickKey == null) {
      fallback();
      return;
    }
    MessengerPickedMedia? picked;
    try {
      picked = await orchestrator.pickMedia(kind);
    } catch (error) {
      widget.onMediaSendError?.call('picker-${kind.name}', error);
      fallback();
      return;
    }
    if (picked == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingMediaByConversation[pickKey] = picked!;
    });
    _scheduleMobileThreadRefresh();
  }

  Future<void> _handleSendPressed(String? conversationId) async {
    final selectionKey =
        _conversationKey(conversationId ?? widget.selectedConversationId);
    if (selectionKey == null) {
      return;
    }

    MessengerPickedMedia? pendingMedia =
        _pendingMediaByConversation[selectionKey];
    var targetConversationId = selectionKey;

    final prepare = widget.prepareOutgoingConversation;
    if (prepare != null) {
      final resolved = await prepare(targetConversationId);
      if (resolved == null || resolved.trim().isEmpty) {
        widget.onMediaSendError?.call(
          'conversation',
          StateError(
            'Could not prepare conversation for outgoing message.',
          ),
        );
        return;
      }
      targetConversationId = resolved.trim();
      if (selectionKey != targetConversationId && pendingMedia != null) {
        final media = pendingMedia;
        if (mounted) {
          setState(() {
            _pendingMediaByConversation.remove(selectionKey);
            _pendingMediaByConversation[targetConversationId] = media;
          });
        }
      } else if (selectionKey != targetConversationId) {
        pendingMedia = _pendingMediaByConversation[targetConversationId];
      }
    }
    if (_mediaSendingConversationIds.contains(targetConversationId)) {
      return;
    }
    if (pendingMedia == null) {
      widget.onSend();
      return;
    }

    final orchestrator = _buildOrchestrator();
    if (orchestrator == null) {
      widget.onMediaSendError?.call(
        'media-config',
        StateError(
          'Media sending is not configured. '
          'Provide mediaChatClient, mediaChatAuth, and mediaSenderId.',
        ),
      );
      return;
    }

    final caption = widget.composerController.text.trim();
    final pending = MessengerChatMessage(
      id: _tempMessageId(_mediaKindForMessageType(pendingMedia.messageType)),
      senderId: widget.currentUserId,
      senderLabel: widget.currentUserName,
      type: _toUiType(pendingMedia.messageType),
      content: pendingMedia.file.path,
      caption: caption.isEmpty ? null : caption,
      createdAt: DateTime.now(),
      isUploading: true,
      uploadProgress: 0,
    );
    _upsertLocalMessage(targetConversationId, pending);
    widget.onMediaSendStart?.call(pending);
    if (mounted) {
      setState(() {
        _mediaSendingConversationIds.add(targetConversationId);
      });
      _scheduleMobileThreadRefresh();
    }
    final trimmedReplyId =
        widget.composerReplyDraft?.targetMessageId.trim() ?? '';
    final replyToMessageId = trimmedReplyId.isEmpty ? null : trimmedReplyId;

    try {
      final sent = await orchestrator.uploadAndSend(
        conversationId: targetConversationId,
        media: pendingMedia,
        content: caption,
        replyToMessageId: replyToMessageId,
        onUploadProgress: (progress) {
          _updateUploadProgress(targetConversationId, pending.id, progress);
          widget.onMediaSendProgress?.call(pending.id, progress);
        },
      );
      _removeLocalMessage(targetConversationId, pending.id);
      final sentUi = _toUiMessage(sent);
      _upsertLocalMessage(targetConversationId, sentUi);
      if (mounted) {
        setState(() {
          _pendingMediaByConversation.remove(targetConversationId);
        });
        widget.composerController.clear();
        widget.onComposerReplyDraftChanged?.call(null);
        _scheduleMobileThreadRefresh();
      }
      widget.onMediaMessageSent?.call(sentUi);
      widget.onMediaMessageSentForConversation?.call(
        targetConversationId,
        sentUi,
      );
    } catch (error) {
      _updateUploadFailure(targetConversationId, pending.id);
      widget.onMediaSendError?.call(pending.id, error);
    } finally {
      if (mounted) {
        setState(() {
          _mediaSendingConversationIds.remove(targetConversationId);
        });
        _scheduleMobileThreadRefresh();
      }
    }
  }

  void _upsertLocalMessage(
      String conversationId, MessengerChatMessage message) {
    if (!mounted) {
      return;
    }
    setState(() {
      final list = List<MessengerChatMessage>.from(
        _localMessagesByConversation[conversationId] ?? const [],
      );
      final index = list.indexWhere((item) => item.id == message.id);
      if (index == -1) {
        list.add(message);
      } else {
        list[index] = message;
      }
      _localMessagesByConversation[conversationId] = list;
    });
    _scheduleMobileThreadRefresh();
  }

  void _removeLocalMessage(String conversationId, String messageId) {
    if (!mounted) {
      return;
    }
    setState(() {
      final current = _localMessagesByConversation[conversationId];
      if (current == null || current.isEmpty) {
        return;
      }
      final next = current.where((item) => item.id != messageId).toList();
      if (next.isEmpty) {
        _localMessagesByConversation.remove(conversationId);
      } else {
        _localMessagesByConversation[conversationId] = next;
      }
    });
    _scheduleMobileThreadRefresh();
  }

  void _updateUploadProgress(
    String conversationId,
    String messageId,
    double progress,
  ) {
    final current = _localMessagesByConversation[conversationId];
    if (current == null || current.isEmpty || !mounted) {
      return;
    }
    final next = current
        .map(
          (item) => item.id == messageId
              ? MessengerChatMessage(
                  id: item.id,
                  senderId: item.senderId,
                  senderLabel: item.senderLabel,
                  type: item.type,
                  content: item.content,
                  caption: item.caption,
                  createdAt: item.createdAt,
                  isDeleted: item.isDeleted,
                  deliveryStatus: item.deliveryStatus,
                  reactions: item.reactions,
                  isUploading: true,
                  uploadProgress: progress,
                  senderAvatarUrl: item.senderAvatarUrl,
                  quotedReply: item.quotedReply,
                )
              : item,
        )
        .toList();
    setState(() {
      _localMessagesByConversation[conversationId] = next;
    });
    _scheduleMobileThreadRefresh();
  }

  void _updateUploadFailure(String conversationId, String messageId) {
    final current = _localMessagesByConversation[conversationId];
    if (current == null || current.isEmpty || !mounted) {
      return;
    }
    final next = current
        .map(
          (item) => item.id == messageId
              ? MessengerChatMessage(
                  id: item.id,
                  senderId: item.senderId,
                  senderLabel: item.senderLabel,
                  type: item.type,
                  content: item.content,
                  caption: item.caption,
                  createdAt: item.createdAt,
                  isDeleted: item.isDeleted,
                  deliveryStatus: item.deliveryStatus,
                  reactions: item.reactions,
                  isUploading: false,
                  uploadProgress: null,
                  senderAvatarUrl: item.senderAvatarUrl,
                  quotedReply: item.quotedReply,
                )
              : item,
        )
        .toList();
    setState(() {
      _localMessagesByConversation[conversationId] = next;
    });
    _scheduleMobileThreadRefresh();
  }

  String _tempMessageId(MessengerMediaKind kind) {
    return 'pending-${kind.name}-${DateTime.now().microsecondsSinceEpoch}';
  }

  MessengerChatMessage _toUiMessage(ChatMessage message) {
    final body = message.content.trim();
    final deliveryStatus = message.senderId == widget.currentUserId
        ? messengerDeliveryStatusFor(
            message,
            currentUserId: widget.currentUserId,
          )
        : MessengerDeliveryStatus.none;
    if (message.attachments.isEmpty) {
      return MessengerChatMessage(
        id: message.id,
        senderId: message.senderId,
        senderLabel: message.senderId == widget.currentUserId
            ? widget.currentUserName
            : (message.sender?.name ?? message.senderId),
        type: _toUiType(message.type),
        content: body,
        createdAt: message.createdAt,
        deliveryStatus: deliveryStatus,
        quotedReply: _shellQuotedReply(message),
      );
    }
    final url = message.attachments.first.url.trim();
    return MessengerChatMessage(
      id: message.id,
      senderId: message.senderId,
      senderLabel: message.senderId == widget.currentUserId
          ? widget.currentUserName
          : (message.sender?.name ?? message.senderId),
      type: _toUiType(message.type),
      content: url.isNotEmpty ? url : body,
      caption: url.isNotEmpty && body.isNotEmpty ? body : null,
      createdAt: message.createdAt,
      deliveryStatus: deliveryStatus,
      quotedReply: _shellQuotedReply(message),
    );
  }

  MessengerQuotedMessage? _shellQuotedReply(ChatMessage message) {
    final r = message.replyTo;
    if (r == null) {
      return null;
    }
    final id = r.id.trim();
    if (id.isEmpty) {
      return null;
    }
    final label = r.sender?.name?.trim();
    return MessengerQuotedMessage(
      messageId: id,
      senderLabel: label != null && label.isNotEmpty ? label : r.senderId,
      preview: _shellReplyToPreview(r),
      messageType: _toUiType(r.type),
    );
  }

  String _shellReplyToPreview(ReplyToMessage r) {
    final c = r.content.trim();
    if (c.isNotEmpty) {
      return c.length > 80 ? '${c.substring(0, 79)}…' : c;
    }
    switch (r.type) {
      case MessageType.image:
        return 'Photo';
      case MessageType.video:
        return 'Video';
      case MessageType.voice:
        return 'Voice message';
      case MessageType.file:
        return 'File';
      case MessageType.text:
      case MessageType.link:
      case MessageType.other:
        return 'Message';
    }
  }

  MessengerMessageType _toUiType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return MessengerMessageType.image;
      case MessageType.voice:
        return MessengerMessageType.voice;
      case MessageType.video:
        return MessengerMessageType.video;
      case MessageType.file:
        return MessengerMessageType.file;
      case MessageType.text:
      case MessageType.link:
      case MessageType.other:
        return MessengerMessageType.text;
    }
  }

  MessengerMediaKind _mediaKindForMessageType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return MessengerMediaKind.image;
      case MessageType.voice:
        return MessengerMediaKind.voice;
      case MessageType.video:
        return MessengerMediaKind.video;
      case MessageType.file:
      case MessageType.text:
      case MessageType.link:
      case MessageType.other:
        return MessengerMediaKind.file;
    }
  }

  String? _conversationIdForUser(String userId) {
    final uid = userId.trim();
    for (final conversation in widget.conversations) {
      if (conversation.peerUsers.any((peer) => peer.id.trim() == uid)) {
        return conversation.id.trim();
      }
    }
    return null;
  }

  bool _conversationIdsEqual(String? a, String? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.trim() == b.trim();
  }

  MessengerConversation? _conversationForShellId(String? id) {
    if (id == null || id.trim().isEmpty) {
      return null;
    }
    final t = id.trim();
    for (final c in widget.conversations) {
      if (c.id.trim() == t) {
        return c;
      }
    }
    return null;
  }

  Future<void> _runOpenDirectChat(MessengerUser user) async {
    try {
      await widget.onOpenDirectChat(user);
    } finally {
      if (mounted) {
        setState(() => _openingDirectUserId = '');
      }
    }
  }

  Future<void> _runCreateGroupSelected(
    List<MessengerUser> selectedUsers,
  ) async {
    final createGroup = widget.onCreateGroupSelected;
    if (createGroup == null) {
      return;
    }
    await createGroup(selectedUsers);
  }

  Future<void> _runCreateGroupRequested(
    MessengerGroupCreateRequest request,
  ) async {
    final createGroup = widget.onCreateGroupRequested;
    if (createGroup == null) {
      return;
    }
    await createGroup(request);
  }

  Future<void> _mobileOpenDirectChatAndShowThread(MessengerUser user) async {
    setState(() => _openingDirectUserId = user.id);
    await _runOpenDirectChat(user);
    if (!mounted) {
      return;
    }
    await _waitUntilPostFrame();
    if (!mounted) {
      return;
    }
    final selected = widget.selectedConversationId?.trim();
    // After [_waitUntilPostFrame], a non-empty host selection matches the opened DM.
    final idForRoute = (selected != null && selected.isNotEmpty)
        ? selected
        : _conversationIdForUser(user.id);
    if (idForRoute == null || idForRoute.trim().isEmpty) {
      return;
    }
    await _openThreadRouteInternal(
      context,
      themeData: MessengerTheme.of(context),
      fallbackConversationId: idForRoute,
      forceLoading: true,
    );
  }

  Future<void> _mobileCreateGroupAndShowThread(
    List<MessengerUser> selectedUsers,
  ) async {
    await _runCreateGroupSelected(selectedUsers);
    if (!mounted) {
      return;
    }
    await _waitUntilPostFrame();
    if (!mounted) {
      return;
    }
    final selected = widget.selectedConversationId?.trim();
    if (selected == null || selected.isEmpty) {
      return;
    }
    await _openThreadRouteInternal(
      context,
      themeData: MessengerTheme.of(context),
      fallbackConversationId: selected,
      forceLoading: true,
    );
  }

  Future<void> _mobileCreateNamedGroupAndShowThread(
    MessengerGroupCreateRequest request,
  ) async {
    await _runCreateGroupRequested(request);
    if (!mounted) {
      return;
    }
    await _waitUntilPostFrame();
    if (!mounted) {
      return;
    }
    final selected = widget.selectedConversationId?.trim();
    if (selected == null || selected.isEmpty) {
      return;
    }
    await _openThreadRouteInternal(
      context,
      themeData: MessengerTheme.of(context),
      fallbackConversationId: selected,
      forceLoading: true,
    );
  }

  Future<void> _runSelectConversation(String conversationId) async {
    try {
      await widget.onSelectConversation(conversationId);
    } catch (_) {
      // Keep navigation smooth; host callback should surface failures.
    }
  }

  bool get _shouldShowSuggestedPanel =>
      widget.suggestedPeopleBuilder != null && widget.conversations.isEmpty;

  Widget _suggestedPaneLoadingBody(BuildContext context) {
    return widget.suggestedPaneLoadingBuilder?.call(context) ??
        widget.conversationListLoadingBuilder?.call(context) ??
        const MessengerDefaultInlineLoading();
  }

  Widget _buildDesktopConversationPane() {
    if (_shouldShowSuggestedPanel) {
      if (_suggestedSlotWaitingForConversations) {
        final theme = MessengerTheme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: _suggestedPaneLoadingBody(context),
        );
      }
      return MessengerListSearchChrome.resolve(
        context,
        searchFieldBackgroundColor: widget.searchFieldBackgroundColor,
        searchIconColor: widget.searchIconColor,
        searchHintTextStyle: widget.searchHintTextStyle,
        searchFieldContentPadding: widget.searchFieldContentPadding,
        searchFieldBorderRadius: widget.searchFieldBorderRadius,
        searchInputTextStyle: widget.searchInputTextStyle,
        child: widget.suggestedPeopleBuilder!(
          context,
          widget.users,
          (user) async {
            setState(() => _openingDirectUserId = user.id);
            try {
              await widget.onOpenDirectChat(user);
            } finally {
              if (mounted) {
                setState(() => _openingDirectUserId = '');
              }
            }
          },
        ),
      );
    }
    return MessengerConversationList(
      isMobile: false,
      currentUserName: widget.currentUserName,
      conversations: widget.conversations,
      users: widget.users,
      selectedConversationId: widget.selectedConversationId,
      openingDirectUserId: _openingDirectUserId,
      onRefresh: widget.onRefresh,
      enablePullToRefresh: widget.enablePullToRefresh,
      isConversationListLoading: _effectiveConversationListLoading,
      conversationListLoadingBuilder: widget.conversationListLoadingBuilder,
      onLogout: widget.onLogout,
      onOpenDirectChat: (user) async {
        setState(() => _openingDirectUserId = user.id);
        await widget.onOpenDirectChat(user);
        if (mounted) {
          setState(() => _openingDirectUserId = '');
        }
        return;
      },
      onCreateGroupSelected: widget.onCreateGroupSelected,
      onCreateGroupRequested: widget.onCreateGroupRequested,
      isCreatingGroup: widget.isCreatingGroup,
      groupNameInputBehavior: widget.groupNameInputBehavior,
      groupNameFieldLabelText: widget.groupNameFieldLabelText,
      groupNameFieldHintText: widget.groupNameFieldHintText,
      groupNameRequiredErrorText: widget.groupNameRequiredErrorText,
      onSelectConversation: widget.onSelectConversation,
      searchVisibility: widget.searchVisibility,
      searchThreshold: widget.searchThreshold,
      searchHintText: widget.searchHintText,
      searchInputTextStyle: widget.searchInputTextStyle,
      searchHintTextStyle: widget.searchHintTextStyle,
      searchFieldBackgroundColor: widget.searchFieldBackgroundColor,
      searchFieldContentPadding: widget.searchFieldContentPadding,
      searchIconColor: widget.searchIconColor,
      searchFieldBorderRadius: widget.searchFieldBorderRadius,
      emptyUsersMessage: widget.emptyUsersMessage,
      emptyConversationsMessage: widget.emptyConversationsMessage,
      emptyUsersBuilder: widget.emptyUsersBuilder,
      emptyConversationsBuilder: widget.emptyConversationsBuilder,
      showStartChatFab: widget.showStartChatFab,
      showHeaderEditButton: widget.showHeaderEditButton,
      showHeaderTitle: widget.showHeaderTitle,
      showHeaderComposeButton: widget.showHeaderComposeButton,
      startNewChatEmptyBuilder: widget.startNewChatEmptyBuilder,
      startNewChatUsersLoading: widget.startNewChatUsersLoading,
      fabBackgroundColor: widget.fabBackgroundColor,
      fabForegroundColor: widget.fabForegroundColor,
      fabIcon: widget.fabIcon,
      fabHeroTag: widget.fabHeroTag,
      userListPadding: widget.userListPadding,
      userListItemSpacing: widget.userListItemSpacing,
      userListItemStyle: widget.userListItemStyle,
      userListItemBuilder: widget.userListItemBuilder,
    );
  }

  Widget _buildMobileConversationPane() {
    if (_shouldShowSuggestedPanel) {
      if (_suggestedSlotWaitingForConversations) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: _suggestedPaneLoadingBody(context),
        );
      }
      return MessengerListSearchChrome.resolve(
        context,
        searchFieldBackgroundColor: widget.searchFieldBackgroundColor,
        searchIconColor: widget.searchIconColor,
        searchHintTextStyle: widget.searchHintTextStyle,
        searchFieldContentPadding: widget.searchFieldContentPadding,
        searchFieldBorderRadius: widget.searchFieldBorderRadius,
        searchInputTextStyle: widget.searchInputTextStyle,
        child: widget.suggestedPeopleBuilder!(
          context,
          widget.users,
          _mobileOpenDirectChatAndShowThread,
        ),
      );
    }
    return MessengerConversationList(
      isMobile: true,
      currentUserName: widget.currentUserName,
      conversations: widget.conversations,
      users: widget.users,
      selectedConversationId: widget.selectedConversationId,
      openingDirectUserId: _openingDirectUserId,
      onRefresh: widget.onRefresh,
      enablePullToRefresh: widget.enablePullToRefresh,
      isConversationListLoading: _effectiveConversationListLoading,
      conversationListLoadingBuilder: widget.conversationListLoadingBuilder,
      onLogout: widget.onLogout,
      onOpenDirectChat: _mobileOpenDirectChatAndShowThread,
      onCreateGroupSelected: widget.onCreateGroupSelected == null
          ? null
          : _mobileCreateGroupAndShowThread,
      onCreateGroupRequested: widget.onCreateGroupRequested == null
          ? null
          : _mobileCreateNamedGroupAndShowThread,
      isCreatingGroup: widget.isCreatingGroup,
      groupNameInputBehavior: widget.groupNameInputBehavior,
      groupNameFieldLabelText: widget.groupNameFieldLabelText,
      groupNameFieldHintText: widget.groupNameFieldHintText,
      groupNameRequiredErrorText: widget.groupNameRequiredErrorText,
      onSelectConversation: (conversationId) async {
        await _runSelectConversation(conversationId);
        if (!mounted) {
          return;
        }
        await _openThreadRouteInternal(
          context,
          themeData: MessengerTheme.of(context),
          fallbackConversationId: conversationId,
          forceLoading: true,
        );
      },
      searchVisibility: widget.searchVisibility,
      searchThreshold: widget.searchThreshold,
      searchHintText: widget.searchHintText,
      searchInputTextStyle: widget.searchInputTextStyle,
      searchHintTextStyle: widget.searchHintTextStyle,
      searchFieldBackgroundColor: widget.searchFieldBackgroundColor,
      searchFieldContentPadding: widget.searchFieldContentPadding,
      searchIconColor: widget.searchIconColor,
      searchFieldBorderRadius: widget.searchFieldBorderRadius,
      emptyUsersMessage: widget.emptyUsersMessage,
      emptyConversationsMessage: widget.emptyConversationsMessage,
      emptyUsersBuilder: widget.emptyUsersBuilder,
      emptyConversationsBuilder: widget.emptyConversationsBuilder,
      showStartChatFab: widget.showStartChatFab,
      showHeaderEditButton: widget.showHeaderEditButton,
      showHeaderTitle: widget.showHeaderTitle,
      showHeaderComposeButton: widget.showHeaderComposeButton,
      startNewChatEmptyBuilder: widget.startNewChatEmptyBuilder,
      startNewChatUsersLoading: widget.startNewChatUsersLoading,
      fabBackgroundColor: widget.fabBackgroundColor,
      fabForegroundColor: widget.fabForegroundColor,
      fabIcon: widget.fabIcon,
      fabHeroTag: widget.fabHeroTag,
      userListPadding: widget.userListPadding,
      userListItemSpacing: widget.userListItemSpacing,
      userListItemStyle: widget.userListItemStyle,
      userListItemBuilder: widget.userListItemBuilder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= widget.desktopBreakpoint;

    final shell = isDesktop
        ? Row(
            children: [
              SizedBox(
                width: 360,
                child: _buildDesktopConversationPane(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThread(isMobile: false),
              ),
            ],
          )
        : _buildMobileConversationPane();

    if (widget.theme == null) {
      return shell;
    }

    return MessengerTheme(data: widget.theme!, child: shell);
  }
}
