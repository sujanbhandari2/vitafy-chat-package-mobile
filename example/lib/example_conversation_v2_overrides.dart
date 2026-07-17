import 'package:flutter/material.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

import 'example_conversation_v2_theme.dart';

/// Builds [MessengerThreadViewOverrides] for the example v2 conversation screen.
MessengerThreadViewOverrides exampleConversationV2Overrides() {
  return MessengerThreadViewOverrides(
    headerBuilder: _buildHeaderWithAdvocateCard,
    messageContentBuilders: MessengerMessageContentBuilders(
      textBuilder: _buildTextContent,
      imageBuilder: _buildImageContent,
      voiceBuilder: _buildVoiceContent,
      fileBuilder: _buildFileContent,
      videoBuilder: _buildVideoContent,
      mixedAttachmentsBuilder: _buildMixedContent,
      deletedBuilder: _buildDeletedContent,
      uploadingBuilder: _buildUploadingContent,
    ),
    composerBuilder: _buildComposer,
  );
}

Widget _buildHeaderWithAdvocateCard(
  BuildContext context,
  MessengerThreadHeaderData data,
) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _buildHeader(context, data),
      if (data.conversation != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
          child: _buildAdvocateCard(context, data.conversation!),
        ),
    ],
  );
}

Widget _buildHeader(BuildContext context, MessengerThreadHeaderData data) {
  final title = data.conversation?.title.trim();
  return Container(
    color: Colors.white,
    padding: EdgeInsets.fromLTRB(data.isMobile ? 0 : 8, 4, data.isMobile ? 0 : 8, 8),
    child: Row(
      children: [
        if (data.isMobile)
          IconButton(
            onPressed: data.onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: ExampleConversationV2Theme.tealDark,
          )
        else
          const SizedBox(width: 8),
        Expanded(
          child: Text(
            (title != null && title.isNotEmpty) ? title : 'Conversation',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ExampleConversationV2Theme.tealDark,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ),
        SizedBox(width: data.isMobile ? 48 : 8),
      ],
    ),
  );
}

Widget _buildAdvocateCard(
  BuildContext context,
  MessengerConversation conversation,
) {
  final role = _advocateRoleLabel(conversation);
  final bio = _advocateBio(conversation);

  return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MessengerAvatar(
                label: conversation.avatarLabel,
                imageUrl: conversation.avatarUrl,
                size: 52,
                compact: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      color: ExampleConversationV2Theme.advocateLabel,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ExampleConversationV2Theme.incomingText,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                _AdvocateActionButton(
                  icon: Icons.phone_rounded,
                  filled: true,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Call ${conversation.title}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _AdvocateActionButton(
                  icon: Icons.mail_outline_rounded,
                  filled: false,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Email ${conversation.title}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
}

String _advocateRoleLabel(MessengerConversation conversation) {
  if (conversation.isGroup) {
    return 'Group chat';
  }
  for (final peer in conversation.peerUsers) {
    final role = peer.roleLabel.trim();
    if (role.isNotEmpty) {
      return role;
    }
  }
  return 'Advocate';
}

String _advocateBio(MessengerConversation conversation) {
  final subtitle = conversation.subtitle.trim();
  if (subtitle.isNotEmpty && subtitle.toLowerCase() != 'no messages yet') {
    return subtitle;
  }
  return '12+ years helping families navigate complex care decisions, '
      'billing disputes, and specialist referrals.';
}

Widget _buildTextContent(
  BuildContext context,
  MessengerMessageContentData data,
) {
  return Text(
    data.message.content,
    style: TextStyle(
      fontSize: 15,
      height: 1.35,
      color: data.isMine ? Colors.white : ExampleConversationV2Theme.incomingText,
      fontWeight: FontWeight.w500,
    ),
  );
}

Widget _buildImageContent(
  BuildContext context,
  MessengerMessageContentData data,
) {
  return MessengerDefaultMessageContent(
    message: data.message,
    textColor: data.textColor,
    mutedColor: data.mutedColor,
    attachmentCaptionStyle: data.attachmentCaptionStyle,
    packageDialogTheme: data.packageDialogTheme,
  );
}

Widget _buildVoiceContent(
  BuildContext context,
  MessengerMessageContentData data,
) {
  return MessengerDefaultMessageContent(
    message: data.message,
    textColor: data.textColor,
    mutedColor: data.mutedColor,
    attachmentCaptionStyle: data.attachmentCaptionStyle,
    packageDialogTheme: data.packageDialogTheme,
  );
}

Widget _buildFileContent(
  BuildContext context,
  MessengerMessageContentData data,
) {
  return MessengerDefaultMessageContent(
    message: data.message,
    textColor: data.textColor,
    mutedColor: data.mutedColor,
    attachmentCaptionStyle: data.attachmentCaptionStyle,
    packageDialogTheme: data.packageDialogTheme,
  );
}

Widget _buildVideoContent(
  BuildContext context,
  MessengerMessageContentData data,
) {
  return MessengerDefaultMessageContent(
    message: data.message,
    textColor: data.textColor,
    mutedColor: data.mutedColor,
    attachmentCaptionStyle: data.attachmentCaptionStyle,
    packageDialogTheme: data.packageDialogTheme,
  );
}

Widget _buildMixedContent(
  BuildContext context,
  MessengerMessageContentData data,
) {
  return MessengerDefaultMessageContent(
    message: data.message,
    textColor: data.textColor,
    mutedColor: data.mutedColor,
    attachmentCaptionStyle: data.attachmentCaptionStyle,
    packageDialogTheme: data.packageDialogTheme,
  );
}

Widget _buildDeletedContent(
  BuildContext context,
  MessengerMessageContentData data,
) {
  return Text(
    'Message deleted',
    style: TextStyle(
      fontSize: 14,
      color: data.textColor.withValues(alpha: 0.85),
      fontStyle: FontStyle.italic,
    ),
  );
}

Widget _buildUploadingContent(
  BuildContext context,
  MessengerMessageContentData data,
) {
  return Text(
    'Uploading...',
    style: TextStyle(
      fontSize: 14,
      color: data.textColor.withValues(alpha: 0.9),
      fontWeight: FontWeight.w600,
    ),
  );
}

Widget _buildComposer(BuildContext context, MessengerComposerData data) {
  return AnimatedBuilder(
    animation: data.controller,
    builder: (context, _) {
      final hasText = data.controller.text.trim().isNotEmpty;
      final hasQueuedAttachment = data.pendingAttachments.isNotEmpty;
      final overLimit = pendingAttachmentsOverLimit(data.pendingAttachments);
      final canSend = (hasText || hasQueuedAttachment) &&
          !data.isSending &&
          !data.isRecording &&
          !overLimit;

      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: ExampleConversationV2Theme.composerBorder,
                  ),
                ),
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: data.isSending
                          ? null
                          : () => _showAttachmentOptions(context, data),
                      icon: const Icon(Icons.attach_file_rounded),
                      color: ExampleConversationV2Theme.hint,
                      iconSize: 22,
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: TextField(
                        controller: data.controller,
                        focusNode: data.textFieldFocusNode,
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (canSend) {
                            data.onSend();
                          }
                        },
                        style: data.inputTextStyle ??
                            const TextStyle(
                              color: ExampleConversationV2Theme.incomingText,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                        decoration: InputDecoration(
                          hintText: data.hintText,
                          hintStyle: data.hintTextStyle ??
                              const TextStyle(
                                color: ExampleConversationV2Theme.hint,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (_) => _handleComposerTyping(data),
                      ),
                    ),
                    IconButton(
                      onPressed: data.isSending ? null : data.onToggleRecording,
                      icon: Icon(
                        data.isRecording
                            ? Icons.stop_rounded
                            : Icons.mic_none_rounded,
                      ),
                      color: ExampleConversationV2Theme.hint,
                      iconSize: 22,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: canSend
                  ? ExampleConversationV2Theme.teal
                  : ExampleConversationV2Theme.teal.withValues(alpha: 0.35),
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: canSend ? data.onSend : null,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: data.isSending
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _handleComposerTyping(MessengerComposerData data) async {
  final conversationId = data.typingConversationId?.trim();
  if (conversationId == null || conversationId.isEmpty) {
    return;
  }
  final text = data.controller.text.trim();
  if (text.isNotEmpty) {
    await data.onTypingStart?.call(conversationId);
  } else {
    await data.onTypingStop?.call(conversationId);
  }
}

Future<void> _showAttachmentOptions(
  BuildContext context,
  MessengerComposerData data,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                data.attachmentSheetTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (data.onPickCamera != null)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  data.onPickCamera!();
                },
              ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Images'),
              onTap: () {
                Navigator.pop(sheetContext);
                data.onPickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack_outlined),
              title: const Text('Audio'),
              onTap: () {
                Navigator.pop(sheetContext);
                data.onPickAudio();
              },
            ),
            if (data.onPickDocument != null)
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('Documents'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  data.onPickDocument!();
                },
              ),
            if (data.onPickVideo != null)
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Video'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  data.onPickVideo!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _AdvocateActionButton extends StatelessWidget {
  const _AdvocateActionButton({
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? ExampleConversationV2Theme.teal : Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: filled
                ? null
                : Border.all(color: ExampleConversationV2Theme.composerBorder),
          ),
          child: Icon(
            icon,
            size: 20,
            color: filled ? Colors.white : ExampleConversationV2Theme.teal,
          ),
        ),
      ),
    );
  }
}
