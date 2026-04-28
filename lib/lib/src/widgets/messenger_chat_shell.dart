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
    this.onMediaSendStart,
    this.onMediaSendProgress,
    this.onMediaSendError,
    this.onMediaMessageSent,
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
  final ValueChanged<MessengerChatMessage>? onMediaSendStart;
  final void Function(String pendingMessageId, double progress)?
      onMediaSendProgress;
  final void Function(String pendingMessageId, Object error)? onMediaSendError;
  final ValueChanged<MessengerChatMessage>? onMediaMessageSent;

  @override
  State<MessengerChatShell> createState() => _MessengerChatShellState();
}

class _MessengerChatShellState extends State<MessengerChatShell> {
  String _openingDirectUserId = '';
  final Map<String, List<MessengerChatMessage>> _localMessagesByConversation =
      <String, List<MessengerChatMessage>>{};

  Widget _buildThread({
    required bool isMobile,
    VoidCallback? onBack,
  }) {
    final selectedConversation = widget.selectedConversationId == null
        ? null
        : widget.conversations
            .where((item) => item.id == widget.selectedConversationId)
            .firstOrNull;

    return MessengerChatThread(
      isMobile: isMobile,
      onBack: onBack,
      conversation: selectedConversation,
      messages: _messagesForConversation(widget.selectedConversationId),
      currentUserId: widget.currentUserId,
      composerController: widget.composerController,
      messagesScrollController: widget.messagesScrollController,
      isSending: widget.isSending,
      isRecording: widget.isRecording,
      onSend: widget.onSend,
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
    );
  }

  Future<void> _openThreadRoute(BuildContext context) async {
    final themeData = MessengerTheme.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => MessengerTheme(
          data: themeData,
          child: Scaffold(
            body: SafeArea(
              child: _buildThread(
                isMobile: true,
                onBack: () => Navigator.of(routeContext).maybePop(),
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
      return null;
    }
    final client = widget.mediaChatClient;
    final auth = widget.mediaChatAuth;
    final senderId = widget.mediaSenderId;
    if (client == null || auth == null || senderId == null || senderId.isEmpty) {
      return null;
    }
    return MessengerMediaSendOrchestrator(
      client: client,
      auth: auth,
      senderId: senderId,
      picker: widget.mediaPicker,
    );
  }

  Future<void> _handleMediaPick({
    required MessengerMediaKind kind,
    required VoidCallback fallback,
  }) async {
    final orchestrator = _buildOrchestrator();
    final conversationId = widget.selectedConversationId;
    if (orchestrator == null || conversationId == null || conversationId.isEmpty) {
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
    final pending = MessengerChatMessage(
      id: _tempMessageId(kind),
      senderId: widget.currentUserId,
      senderLabel: widget.currentUserName,
      type: _toUiType(picked.messageType),
      content: picked.file.path,
      createdAt: DateTime.now(),
      isUploading: true,
      uploadProgress: 0,
    );
    _upsertLocalMessage(conversationId, pending);
    widget.onMediaSendStart?.call(pending);
    try {
      final sent = await orchestrator.uploadAndSend(
        conversationId: conversationId,
        media: picked,
        onUploadProgress: (progress) {
          _updateUploadProgress(conversationId, pending.id, progress);
          widget.onMediaSendProgress?.call(pending.id, progress);
        },
      );
      _removeLocalMessage(conversationId, pending.id);
      final sentUi = _toUiMessage(sent);
      _upsertLocalMessage(conversationId, sentUi);
      widget.onMediaMessageSent?.call(sentUi);
    } catch (error) {
      _updateUploadFailure(conversationId, pending.id);
      widget.onMediaSendError?.call(pending.id, error);
    }
  }

  void _upsertLocalMessage(String conversationId, MessengerChatMessage message) {
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
                  await widget.onOpenDirectChat(user);
                  if (!mounted) {
                    return;
                  }
                  setState(() => _openingDirectUserId = '');
                  await _openThreadRoute(this.context);
                  return;
                },
                onSelectConversation: (conversationId) async {
                  await widget.onSelectConversation(conversationId);
                  if (!mounted) {
                    return;
                  }
                  await _openThreadRoute(this.context);
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
