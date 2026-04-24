import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messenger_conversation.dart';
import '../models/messenger_message.dart';
import '../models/messenger_user.dart';
import '../models/messenger_search_visibility.dart';
import '../models/messenger_attachment.dart';
import '../models/messenger_typing.dart';
import '../theme/messenger_theme.dart';
import 'messenger_chat_thread.dart';
import 'messenger_conversation_list.dart';

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
    this.emptyUsersMessage = 'No users available right now.',
    this.emptyConversationsMessage = 'No conversations available yet.',
    this.emptyUsersBuilder,
    this.emptyConversationsBuilder,
    this.showStartChatFab = true,
    this.enableReactions = true,
    this.reactionOptions = const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
    this.showDateSeparators = true,
    this.composerHintText = 'Type your message...',
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
  final String emptyUsersMessage;
  final String emptyConversationsMessage;
  final WidgetBuilder? emptyUsersBuilder;
  final WidgetBuilder? emptyConversationsBuilder;
  final bool showStartChatFab;
  final bool enableReactions;
  final List<String> reactionOptions;
  final bool showDateSeparators;
  final String composerHintText;
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

  @override
  State<MessengerChatShell> createState() => _MessengerChatShellState();
}

class _MessengerChatShellState extends State<MessengerChatShell> {
  bool _isMobileThreadOpen = false;
  String _openingDirectUserId = '';

  @override
  void didUpdateWidget(covariant MessengerChatShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedConversationId != null &&
        widget.selectedConversationId != oldWidget.selectedConversationId &&
        mounted) {
      setState(() => _isMobileThreadOpen = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= widget.desktopBreakpoint;

    final selectedConversation = widget.selectedConversationId == null
        ? null
        : widget.conversations
            .where((item) => item.id == widget.selectedConversationId)
            .firstOrNull;

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
                  },
                  onSelectConversation: widget.onSelectConversation,
                  searchVisibility: widget.searchVisibility,
                  searchThreshold: widget.searchThreshold,
                  searchHintText: widget.searchHintText,
                  emptyUsersMessage: widget.emptyUsersMessage,
                  emptyConversationsMessage: widget.emptyConversationsMessage,
                  emptyUsersBuilder: widget.emptyUsersBuilder,
                  emptyConversationsBuilder: widget.emptyConversationsBuilder,
                  showStartChatFab: widget.showStartChatFab,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MessengerChatThread(
                  isMobile: false,
                  conversation: selectedConversation,
                  messages: widget.messages,
                  currentUserId: widget.currentUserId,
                  composerController: widget.composerController,
                  messagesScrollController: widget.messagesScrollController,
                  isSending: widget.isSending,
                  isRecording: widget.isRecording,
                  onSend: widget.onSend,
                  onPickImage: widget.onPickImage,
                  onPickAudio: widget.onPickAudio,
                  onToggleRecording: widget.onToggleRecording,
                  onPickCamera: widget.onPickCamera,
                  onPickVideo: widget.onPickVideo,
                  onPickDocument: widget.onPickDocument,
                  composerHintText: widget.composerHintText,
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
                ),
              ),
            ],
          )
        : _isMobileThreadOpen
            ? MessengerChatThread(
                isMobile: true,
                onBack: () => setState(() => _isMobileThreadOpen = false),
                conversation: selectedConversation,
                messages: widget.messages,
                currentUserId: widget.currentUserId,
                composerController: widget.composerController,
                messagesScrollController: widget.messagesScrollController,
                isSending: widget.isSending,
                isRecording: widget.isRecording,
                onSend: widget.onSend,
                onPickImage: widget.onPickImage,
                onPickAudio: widget.onPickAudio,
                onToggleRecording: widget.onToggleRecording,
                onPickCamera: widget.onPickCamera,
                onPickVideo: widget.onPickVideo,
                onPickDocument: widget.onPickDocument,
                composerHintText: widget.composerHintText,
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
                  if (mounted) {
                    setState(() {
                      _openingDirectUserId = '';
                      _isMobileThreadOpen = true;
                    });
                  }
                },
                onSelectConversation: (conversationId) async {
                  await widget.onSelectConversation(conversationId);
                  if (mounted) {
                    setState(() => _isMobileThreadOpen = true);
                  }
                },
                searchVisibility: widget.searchVisibility,
                searchThreshold: widget.searchThreshold,
                searchHintText: widget.searchHintText,
                emptyUsersMessage: widget.emptyUsersMessage,
                emptyConversationsMessage: widget.emptyConversationsMessage,
                emptyUsersBuilder: widget.emptyUsersBuilder,
                emptyConversationsBuilder: widget.emptyConversationsBuilder,
                showStartChatFab: widget.showStartChatFab,
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
