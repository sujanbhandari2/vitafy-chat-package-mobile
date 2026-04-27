import 'package:flutter/material.dart';

import '../models/messenger_conversation.dart';
import '../models/messenger_message.dart';
import '../models/messenger_attachment.dart';
import '../models/messenger_typing.dart';
import 'messenger_avatar.dart';
import 'messenger_composer_bar.dart';
import 'messenger_message_bubble.dart';
import '../theme/messenger_theme.dart';

class MessengerChatThread extends StatelessWidget {
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
    this.remoteTypingUsers = const [],
    this.typingIndicatorPrefix = '',
    this.onTypingStart,
    this.onTypingStop,
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
  final List<MessengerTypingUser> remoteTypingUsers;
  final String typingIndicatorPrefix;
  final Future<void> Function(String conversationId)? onTypingStart;
  final Future<void> Function(String conversationId)? onTypingStop;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final visibleTyping = remoteTypingUsers
        .where((user) => user.userId != currentUserId)
        .toList(growable: false);
    final typingLine = visibleTyping.isEmpty
        ? ''
        : _formatRemoteTypingLine(visibleTyping, typingIndicatorPrefix);

    final stage = Column(
      children: [
        _ThreadHeader(
          isMobile: isMobile,
          conversation: conversation,
          onBack: onBack,
        ),
        Expanded(
          child: Container(
            color: isMobile ? theme.threadBackgroundMobile : theme.background,
            child: conversation == null
                ? Semantics(
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
                  )
                : messages.isEmpty
                    ? Semantics(
                        container: true,
                        label: 'No messages in conversation',
                        child: emptyMessagesBuilder != null
                            ? emptyMessagesBuilder!(context)
                            : Center(
                                child: Text(
                                  emptyMessagesMessage,
                                  style: TextStyle(
                                    color: theme.subtleText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                      )
                    : ListView.builder(
                    controller: messagesScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final mine = message.senderId == currentUserId;
                      final showDate = showDateSeparators &&
                          (index == 0 ||
                              !_isSameDay(
                                messages[index - 1].createdAt,
                                message.createdAt,
                              ));

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showDate) _DateSeparator(date: message.createdAt),
                          MessengerMessageBubble(
                            message: message,
                            isMine: mine,
                            currentUserId: currentUserId,
                            canDelete: canDeleteMessage?.call(message) ?? mine,
                            onReact: onReact == null
                                ? null
                                : (reaction) => onReact!(message.id, reaction),
                            onRemoveReaction: onRemoveReaction == null
                                ? null
                                : (messageId, reactionType) =>
                                    onRemoveReaction!(messageId, reactionType),
                            onDelete: onDelete == null
                                ? null
                                : () => onDelete!(message.id),
                            onMarkSeen: onMarkSeen == null
                                ? null
                                : () => onMarkSeen!(message.id),
                            enableReactions: enableReactions,
                            reactionOptions: reactionOptions,
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
        if (conversation != null && typingLine.isNotEmpty)
          _RemoteTypingStrip(text: typingLine, theme: theme),
        if (conversation != null)
          MessengerComposerBar(
            controller: composerController,
            isRecording: isRecording,
            isSending: isSending,
            onSend: onSend,
            onPickImage: onPickImage,
            onPickAudio: onPickAudio,
            onToggleRecording: onToggleRecording,
            onPickCamera: onPickCamera,
            onPickVideo: onPickVideo,
            onPickDocument: onPickDocument,
            hintText: composerHintText,
            inputTextStyle: composerInputTextStyle,
            hintTextStyle: composerHintTextStyle,
            fieldBackgroundColor: composerFieldBackgroundColor,
            fieldContentPadding: composerFieldContentPadding,
            attachmentSheetTitle: attachmentSheetTitle,
            attachmentOptions: attachmentOptions,
            typingConversationId: conversation?.id,
            onTypingStart: onTypingStart,
            onTypingStop: onTypingStop,
          ),
      ],
    );

    if (isMobile) {
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
    core =
        '${names[0]}, ${names[1]} and ${names.length - 2} others are typing';
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
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
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        conversation?.title ?? 'No conversation',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  // Align(
                  //   alignment: Alignment.centerRight,
                  //   child: Row(
                  //     mainAxisSize: MainAxisSize.min,
                  //     children: [
                  //       IconButton(
                  //         onPressed: () {},
                  //         icon: Icon(Icons.call_rounded, color: theme.primary),
                  //       ),
                  //       IconButton(
                  //         onPressed: () {},
                  //         icon: Icon(
                  //           Icons.videocam_rounded,
                  //           color: theme.primary,
                  //         ),
                  //       ),
                  //       IconButton(
                  //         onPressed: () {},
                  //         icon: Icon(
                  //           Icons.info_outline_rounded,
                  //           color: theme.primary,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
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

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
