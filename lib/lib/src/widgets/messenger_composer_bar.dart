import 'package:flutter/material.dart';

import '../models/messenger_attachment.dart';
import '../theme/messenger_theme.dart';

class MessengerComposerBar extends StatelessWidget {
  const MessengerComposerBar({
    super.key,
    required this.controller,
    required this.isRecording,
    required this.isSending,
    required this.onSend,
    required this.onPickImage,
    required this.onPickAudio,
    required this.onToggleRecording,
    this.onPickCamera,
    this.onPickDocument,
    this.onPickVideo,
    this.hintText = 'Type your message...',
    this.attachmentSheetTitle = 'Attachments',
    this.attachmentOptions,
  });

  final TextEditingController controller;
  final bool isRecording;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickAudio;
  final VoidCallback onToggleRecording;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickDocument;
  final VoidCallback? onPickVideo;
  final String hintText;
  final String attachmentSheetTitle;
  final List<MessengerAttachmentOption>? attachmentOptions;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final hasText = controller.text.trim().isNotEmpty;
          final canSend = hasText && !isSending;

          return Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.composerFieldBackground,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (canSend) {
                              onSend();
                            }
                          },
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: TextStyle(color: theme.mutedText),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: theme.border,
                      ),
                      IconButton(
                        onPressed:
                            isSending ? null : () => _showAttachments(context),
                        icon: Icon(
                          Icons.add_rounded,
                          color: theme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: onToggleRecording,
                icon: Icon(
                  isRecording ? Icons.stop_circle_outlined : Icons.mic_none,
                  color:
                      isRecording ? const Color(0xFFDC2626) : theme.mutedText,
                ),
              ),
              _CircleButton(
                icon: Icons.send_rounded,
                color: canSend
                    ? theme.primary
                    : theme.primary.withValues(alpha: 0.35),
                iconColor: Colors.white,
                onTap: canSend ? onSend : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAttachments(BuildContext context) async {
    final items = attachmentOptions ?? _defaultAttachmentOptions(context);
    if (items.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attachmentSheetTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (option) => ListTile(
                  leading: Icon(option.icon),
                  title: Text(option.label),
                  enabled: option.onTap != null,
                  onTap: option.onTap == null
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          option.onTap?.call();
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<MessengerAttachmentOption> _defaultAttachmentOptions(
    BuildContext context,
  ) {
    final options = <MessengerAttachmentOption>[];
    options.add(
      MessengerAttachmentOption(
        label: 'Camera',
        icon: Icons.photo_camera_outlined,
        onTap: onPickCamera,
      ),
    );
    options.add(
      MessengerAttachmentOption(
        label: 'Images',
        icon: Icons.image_outlined,
        onTap: onPickImage,
      ),
    );
    options.add(
      MessengerAttachmentOption(
        label: 'Video',
        icon: Icons.videocam_outlined,
        onTap: onPickVideo,
      ),
    );
    options.add(
      MessengerAttachmentOption(
        label: 'Audio',
        icon: Icons.graphic_eq_rounded,
        onTap: onPickAudio,
      ),
    );
    options.add(
      MessengerAttachmentOption(
        label: 'Documents',
        icon: Icons.description_outlined,
        onTap: onPickDocument,
      ),
    );
    return options;
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final Color color;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor == null ? Colors.transparent : color,
          shape: BoxShape.circle,
          border: iconColor == null ? Border.all(color: color) : null,
        ),
        child: Icon(icon, color: iconColor ?? color, size: 19),
      ),
    );
  }
}
