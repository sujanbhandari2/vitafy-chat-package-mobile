import 'dart:async';

import 'package:flutter/material.dart';

import '../client/chat_auth.dart';
import '../client/chat_client.dart';
import '../client/models/chat_message.dart';
import '../models/messenger_conversation.dart';
import '../models/messenger_message.dart';
import '../models/messenger_user.dart';
import '../models/messenger_search_visibility.dart';
import '../models/messenger_attachment.dart';
import '../models/messenger_typing.dart';
import '../theme/messenger_theme.dart';
import 'messenger_chat_thread.dart';
import 'messenger_conversation_list.dart';
import 'messenger_media_send_orchestrator.dart';

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
    required this.onLogout,
    required this.onSelectConversation,
    required this.onOpenDirectChat,
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
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final FutureOr<void> Function(String conversationId) onSelectConversation;
  final FutureOr<void> Function(MessengerUser user) onOpenDirectChat;
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
  final MessengerThemeData? theme;
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

  @override
  State<MessengerChatShell> createState() => _MessengerChatShellState();
}

class _MessengerChatShellState extends State<MessengerChatShell> {
  String _openingDirectUserId = '';
  final Map<String, List<MessengerChatMessage>> _localMessagesByConversation =
      <String, List<MessengerChatMessage>>{};
  final Map<String, MessengerPickedMedia> _pendingMediaByConversation =
      <String, MessengerPickedMedia>{};
  final Set<String> _mediaSendingConversationIds = <String>{};
  final ValueNotifier<int> _mobileThreadVersion = ValueNotifier<int>(0);
  bool _packageRecording = false;
  String? _recordingConversationId;
  MessengerMediaSendOrchestrator? _cachedMediaOrchestrator;
  ChatClient? _cachedMediaClient;
  ChatAuth? _cachedMediaAuth;
  String? _cachedMediaSenderId;
  MessengerMediaPicker? _cachedMediaPicker;
  MessengerAudioRecorder? _cachedMediaRecorder;

  void _scheduleMobileThreadRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _mobileThreadVersion.value++;
    });
  }

  @override
  void didUpdateWidget(covariant MessengerChatShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldRefreshMobileThread =
        oldWidget.selectedConversationId != widget.selectedConversationId ||
            !identical(oldWidget.messages, widget.messages) ||
            !identical(oldWidget.conversations, widget.conversations) ||
            oldWidget.isConversationLoading != widget.isConversationLoading ||
            oldWidget.loadingConversationId != widget.loadingConversationId;
    if (shouldRefreshMobileThread) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _mobileThreadVersion.value++;
      });
    }
  }

  @override
  void dispose() {
    _mobileThreadVersion.dispose();
    super.dispose();
  }

  Widget _buildThread({
    required bool isMobile,
    VoidCallback? onBack,
    String? fallbackConversationId,
    bool forceLoading = false,
  }) {
    final selectedConversationId =
        forceLoading && fallbackConversationId != null
            ? fallbackConversationId
            : (widget.selectedConversationId ?? fallbackConversationId);
    final selectedConversation = selectedConversationId == null
        ? null
        : widget.conversations
            .where((item) => item.id == selectedConversationId)
            .firstOrNull;
    final isSelectedConversationLoading = selectedConversationId != null &&
        (forceLoading ||
            (widget.isConversationLoading &&
                (widget.loadingConversationId == null ||
                    widget.loadingConversationId == selectedConversationId)));
    final rawThreadMessages =
        widget.selectedConversationId == selectedConversationId
            ? _messagesForConversation(widget.selectedConversationId)
            : const <MessengerChatMessage>[];
    final threadMessages = isSelectedConversationLoading
        ? const <MessengerChatMessage>[]
        : rawThreadMessages;
    final pendingMedia = selectedConversationId == null
        ? null
        : _pendingMediaByConversation[selectedConversationId];
    final hasPendingAttachment = pendingMedia != null;
    final isMediaSending = selectedConversationId != null &&
        _mediaSendingConversationIds.contains(selectedConversationId);
    final isPackageRecording = _packageRecording &&
        selectedConversationId != null &&
        selectedConversationId == _recordingConversationId;

    return MessengerChatThread(
      isMobile: isMobile,
      onBack: onBack,
      conversation: selectedConversation,
      messages: threadMessages,
      isConversationLoading: isSelectedConversationLoading,
      loadingMessagesBuilder: widget.loadingMessagesBuilder,
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
      onReact: widget.onReact,
      onRemoveReaction: widget.onRemoveReaction,
      onDelete: widget.onDelete,
      onMarkSeen: widget.onMarkSeen,
      canDeleteMessage: widget.canDeleteMessage,
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
                _pendingMediaByConversation.remove(selectedConversationId);
              });
            },
    );
  }

  Future<void> _openThreadRoute(BuildContext context) async {
    final themeData = MessengerTheme.of(context);
    final fallbackConversationId = widget.selectedConversationId;
    await _openThreadRouteInternal(
      context,
      themeData: themeData,
      fallbackConversationId: fallbackConversationId,
      forceLoading: false,
    );
  }

  Future<void> _openThreadRouteInternal(
    BuildContext context, {
    required MessengerThemeData themeData,
    required String? fallbackConversationId,
    required bool forceLoading,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => MessengerTheme(
          data: themeData,
          child: Scaffold(
            body: SafeArea(
              child: ValueListenableBuilder<int>(
                valueListenable: _mobileThreadVersion,
                builder: (_, __, ___) => _buildThread(
                  isMobile: true,
                  onBack: () => Navigator.of(routeContext).maybePop(),
                  fallbackConversationId: fallbackConversationId,
                  forceLoading: forceLoading &&
                      widget.selectedConversationId != fallbackConversationId,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<MessengerChatMessage> _messagesForConversation(String? conversationId) {
    if (conversationId == null) {
      return widget.messages;
    }
    final local = _localMessagesByConversation[conversationId] ?? const [];
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
    final targetConversationId =
        conversationId ?? widget.selectedConversationId;
    if (targetConversationId == null || targetConversationId.isEmpty) {
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
        _recordingConversationId = targetConversationId;
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
      setState(() {
        _packageRecording = false;
        _recordingConversationId = null;
        if (picked != null) {
          _pendingMediaByConversation[targetConversationId] = picked;
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
    final conversationId = widget.selectedConversationId;
    if (orchestrator == null ||
        conversationId == null ||
        conversationId.isEmpty) {
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
      _pendingMediaByConversation[conversationId] = picked!;
    });
    _scheduleMobileThreadRefresh();
  }

  Future<void> _handleSendPressed(String? conversationId) async {
    final targetConversationId =
        conversationId ?? widget.selectedConversationId;
    if (targetConversationId == null || targetConversationId.isEmpty) {
      return;
    }
    final pendingMedia = _pendingMediaByConversation[targetConversationId];
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
    try {
      final sent = await orchestrator.uploadAndSend(
        conversationId: targetConversationId,
        media: pendingMedia,
        content: caption,
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
                  createdAt: item.createdAt,
                  isDeleted: item.isDeleted,
                  deliveryStatus: item.deliveryStatus,
                  reactions: item.reactions,
                  isUploading: true,
                  uploadProgress: progress,
                  senderAvatarUrl: item.senderAvatarUrl,
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
                  createdAt: item.createdAt,
                  isDeleted: item.isDeleted,
                  deliveryStatus: item.deliveryStatus,
                  reactions: item.reactions,
                  isUploading: false,
                  uploadProgress: null,
                  senderAvatarUrl: item.senderAvatarUrl,
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
    final content = message.attachments.isNotEmpty
        ? message.attachments.first.url
        : message.content;
    return MessengerChatMessage(
      id: message.id,
      senderId: message.senderId,
      senderLabel: message.senderId == widget.currentUserId
          ? widget.currentUserName
          : (message.sender?.name ?? message.senderId),
      type: _toUiType(message.type),
      content: content,
      createdAt: message.createdAt,
      deliveryStatus: message.senderId == widget.currentUserId
          ? MessengerDeliveryStatus.sent
          : MessengerDeliveryStatus.none,
    );
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
    for (final conversation in widget.conversations) {
      if (conversation.peerUsers.any((peer) => peer.id == userId)) {
        return conversation.id;
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

  Future<void> _runSelectConversation(String conversationId) async {
    try {
      await widget.onSelectConversation(conversationId);
    } catch (_) {
      // Keep navigation smooth; host callback should surface failures.
    }
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
                child: MessengerConversationList(
                  isMobile: false,
                  currentUserName: widget.currentUserName,
                  conversations: widget.conversations,
                  users: widget.users,
                  selectedConversationId: widget.selectedConversationId,
                  openingDirectUserId: _openingDirectUserId,
                  onRefresh: widget.onRefresh,
                  onLogout: widget.onLogout,
                  onOpenDirectChat: (user) async {
                    setState(() => _openingDirectUserId = user.id);
                    await widget.onOpenDirectChat(user);
                    if (mounted) {
                      setState(() => _openingDirectUserId = '');
                    }
                    return;
                  },
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
                  fabBackgroundColor: widget.fabBackgroundColor,
                  fabForegroundColor: widget.fabForegroundColor,
                  fabIcon: widget.fabIcon,
                  fabHeroTag: widget.fabHeroTag,
                  userListPadding: widget.userListPadding,
                  userListItemSpacing: widget.userListItemSpacing,
                  userListItemStyle: widget.userListItemStyle,
                  userListItemBuilder: widget.userListItemBuilder,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThread(isMobile: false),
              ),
            ],
          )
        : MessengerConversationList(
            isMobile: true,
            currentUserName: widget.currentUserName,
            conversations: widget.conversations,
            users: widget.users,
            selectedConversationId: widget.selectedConversationId,
            openingDirectUserId: _openingDirectUserId,
            onRefresh: widget.onRefresh,
            onLogout: widget.onLogout,
            onOpenDirectChat: (user) async {
              setState(() => _openingDirectUserId = user.id);
              final fallbackConversationId = _conversationIdForUser(user.id);
              if (fallbackConversationId == null) {
                await _runOpenDirectChat(user);
                if (!mounted) {
                  return;
                }
                await _openThreadRoute(this.context);
                return;
              }
              unawaited(_runOpenDirectChat(user));
              await _openThreadRouteInternal(
                this.context,
                themeData: MessengerTheme.of(this.context),
                fallbackConversationId: fallbackConversationId,
                forceLoading: true,
              );
              return;
            },
            onSelectConversation: (conversationId) async {
              unawaited(_runSelectConversation(conversationId));
              await _openThreadRouteInternal(
                this.context,
                themeData: MessengerTheme.of(this.context),
                fallbackConversationId: conversationId,
                forceLoading: true,
              );
              return;
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
            fabBackgroundColor: widget.fabBackgroundColor,
            fabForegroundColor: widget.fabForegroundColor,
            fabIcon: widget.fabIcon,
            fabHeroTag: widget.fabHeroTag,
            userListPadding: widget.userListPadding,
            userListItemSpacing: widget.userListItemSpacing,
            userListItemStyle: widget.userListItemStyle,
            userListItemBuilder: widget.userListItemBuilder,
          );

    if (widget.theme == null) {
      return shell;
    }

    return MessengerTheme(data: widget.theme!, child: shell);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    if (isEmpty) {
      return null;
    }

    return first;
  }
}
