import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../client/models/chat_message.dart';
import '../models/messenger_attachment.dart';
import '../models/messenger_message.dart';
import '../theme/messenger_theme.dart';
import '../utils/messenger_composer_attachments.dart';
import 'messenger_media_send_orchestrator.dart';

class MessengerComposerBar extends StatefulWidget {
  const MessengerComposerBar({
    super.key,
    required this.controller,
    required this.isRecording,
    required this.isSending,
    required this.onSend,
    required this.onPickImage,
    required this.onPickAudio,
    this.onStartRecording,
    this.onFinishRecording,
    this.onCancelRecording,
    required this.onToggleRecording,
    this.onPickCamera,
    this.onPickDocument,
    this.onPickVideo,
    this.hintText = 'Type your message...',
    this.inputTextStyle,
    this.hintTextStyle,
    this.fieldBackgroundColor,
    this.fieldContentPadding,
    this.attachmentSheetTitle = 'Attachments',
    this.attachmentOptions,
    this.attachmentOptionTextStyle,
    this.typingConversationId,
    this.onTypingStart,
    this.onTypingStop,
    this.typingStartMinInterval = const Duration(seconds: 2),
    this.typingStopIdle = const Duration(seconds: 2),
    this.pendingAttachments = const [],
    this.onRemovePendingAttachment,
    this.onClearAllPendingAttachments,
    this.replyDraft,
    this.onCancelReplyDraft,
    this.textFieldFocusNode,
  });

  final TextEditingController controller;
  final bool isRecording;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickAudio;
  final VoidCallback? onStartRecording;
  final VoidCallback? onFinishRecording;
  final VoidCallback? onCancelRecording;
  final VoidCallback onToggleRecording;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickDocument;
  final VoidCallback? onPickVideo;
  final String hintText;
  final TextStyle? inputTextStyle;
  final TextStyle? hintTextStyle;
  final Color? fieldBackgroundColor;
  final EdgeInsetsGeometry? fieldContentPadding;
  final String attachmentSheetTitle;
  final List<MessengerAttachmentOption>? attachmentOptions;
  final TextStyle? attachmentOptionTextStyle;

  final String? typingConversationId;
  final Future<void> Function(String conversationId)? onTypingStart;
  final Future<void> Function(String conversationId)? onTypingStop;
  final Duration typingStartMinInterval;
  final Duration typingStopIdle;
  final List<MessengerPickedMedia> pendingAttachments;
  final ValueChanged<int>? onRemovePendingAttachment;
  final VoidCallback? onClearAllPendingAttachments;
  final MessengerComposerReplyDraft? replyDraft;
  final VoidCallback? onCancelReplyDraft;
  final FocusNode? textFieldFocusNode;

  bool get _typingEnabled =>
      typingConversationId != null &&
      typingConversationId!.trim().isNotEmpty &&
      onTypingStart != null &&
      onTypingStop != null;

  @override
  State<MessengerComposerBar> createState() => _MessengerComposerBarState();
}

class _MessengerComposerBarState extends State<MessengerComposerBar> {
  Timer? _idleStopTimer;
  Timer? _recordingTicker;
  DateTime? _lastTypingStartSent;
  DateTime? _recordingStartedAt;
  bool _hadNonEmptyForTyping = false;
  Duration _recordingElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
    if (widget.isRecording) {
      _startRecordingTicker();
    }
  }

  @override
  void didUpdateWidget(MessengerComposerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
      _cancelIdleTimer();
      unawaited(_emitStopIfNeeded(oldWidget));
      _lastTypingStartSent = null;
      _hadNonEmptyForTyping = false;
    }
    if (oldWidget.typingConversationId != widget.typingConversationId &&
        widget._typingEnabled) {
      _cancelIdleTimer();
      unawaited(_emitStop());
      _lastTypingStartSent = null;
      _hadNonEmptyForTyping = false;
    }
    if (!oldWidget.isRecording && widget.isRecording) {
      _startRecordingTicker();
    } else if (oldWidget.isRecording && !widget.isRecording) {
      _stopRecordingTicker(reset: true);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    _cancelIdleTimer();
    _stopRecordingTicker(reset: false);
    unawaited(_emitStop());
    super.dispose();
  }

  void _cancelIdleTimer() {
    _idleStopTimer?.cancel();
    _idleStopTimer = null;
  }

  void _startRecordingTicker() {
    _recordingStartedAt = DateTime.now();
    _recordingElapsed = Duration.zero;
    _recordingTicker?.cancel();
    _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _recordingStartedAt == null) {
        return;
      }
      setState(() {
        _recordingElapsed = DateTime.now().difference(_recordingStartedAt!);
      });
    });
  }

  void _stopRecordingTicker({required bool reset}) {
    _recordingTicker?.cancel();
    _recordingTicker = null;
    if (reset) {
      _recordingStartedAt = null;
      _recordingElapsed = Duration.zero;
    }
  }

  String _formatRecordingDuration() {
    final totalSeconds = _recordingElapsed.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _emitStop() async {
    if (!widget._typingEnabled) {
      return;
    }
    final id = widget.typingConversationId!.trim();
    try {
      await widget.onTypingStop!(id);
    } catch (_) {}
  }

  Future<void> _emitStopIfNeeded(MessengerComposerBar old) async {
    if (!old._typingEnabled) {
      return;
    }
    final id = old.typingConversationId!.trim();
    try {
      await old.onTypingStop!(id);
    } catch (_) {}
  }

  Future<void> _emitStart() async {
    if (!widget._typingEnabled) {
      return;
    }
    final id = widget.typingConversationId!.trim();
    try {
      await widget.onTypingStart!(id);
    } catch (_) {}
  }

  void _scheduleIdleStop() {
    if (!widget._typingEnabled) {
      return;
    }
    _cancelIdleTimer();
    _idleStopTimer = Timer(widget.typingStopIdle, () {
      if (!mounted) {
        return;
      }
      _idleStopTimer = null;
      if (widget.controller.text.trim().isEmpty) {
        return;
      }
      unawaited(_emitStop());
      _lastTypingStartSent = null;
      _hadNonEmptyForTyping = false;
    });
  }

  void _handleTextChanged() {
    if (!widget._typingEnabled) {
      return;
    }

    final trimmed = widget.controller.text.trim();
    if (trimmed.isEmpty) {
      _cancelIdleTimer();
      if (_hadNonEmptyForTyping) {
        unawaited(_emitStop());
      }
      _lastTypingStartSent = null;
      _hadNonEmptyForTyping = false;
      return;
    }

    _hadNonEmptyForTyping = true;
    final now = DateTime.now();
    final last = _lastTypingStartSent;
    final min = widget.typingStartMinInterval;
    if (last == null || now.difference(last) >= min) {
      _lastTypingStartSent = now;
      unawaited(_emitStart());
    }
    _scheduleIdleStop();
  }

  Future<void> _showAttachments(BuildContext context) async {
    final items =
        widget.attachmentOptions ?? _defaultAttachmentOptions(context);
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
                widget.attachmentSheetTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (option) => ListTile(
                  leading: Icon(option.icon),
                  title: Text(
                    option.label,
                    style: widget.attachmentOptionTextStyle,
                  ),
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
        onTap: widget.onPickCamera,
      ),
    );
    options.add(
      MessengerAttachmentOption(
        label: 'Images',
        icon: Icons.image_outlined,
        onTap: widget.onPickImage,
      ),
    );
    options.add(
      MessengerAttachmentOption(
        label: 'Audio',
        icon: Icons.graphic_eq_rounded,
        onTap: widget.onPickAudio,
      ),
    );
    options.add(
      MessengerAttachmentOption(
        label: 'Documents',
        icon: Icons.description_outlined,
        onTap: widget.onPickDocument,
      ),
    );
    return options;
  }

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
        animation: widget.controller,
        builder: (context, _) {
          final hasText = widget.controller.text.trim().isNotEmpty;
          final pending = widget.pendingAttachments;
          final hasQueuedAttachment = pending.isNotEmpty;
          final overLimit = pendingAttachmentsOverLimit(pending);
          final canSend = (hasText || hasQueuedAttachment) &&
              !widget.isSending &&
              !widget.isRecording &&
              !overLimit;
          final effectiveHint = hasQueuedAttachment && !hasText
              ? 'Add a caption… (optional)'
              : widget.hintText;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.replyDraft != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: (widget.fieldBackgroundColor ??
                              theme.composerFieldBackground)
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                theme.primary.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Replying to ${widget.replyDraft!.senderLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.replyDraft!.preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.subtleText,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onCancelReplyDraft != null)
                          GestureDetector(
                            onTap: widget.isSending
                                ? null
                                : widget.onCancelReplyDraft,
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: widget.isSending
                                  ? theme.mutedText
                                  : theme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (widget.isRecording)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: (widget.fieldBackgroundColor ??
                              theme.composerFieldBackground)
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.border),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: widget.isSending
                              ? null
                              : (widget.onCancelRecording ??
                                  widget.onToggleRecording),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFDC2626),
                          ),
                          tooltip: 'Discard recording',
                        ),
                        Icon(
                          Icons.mic_rounded,
                          color: theme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Recording ${_formatRecordingDuration()}',
                            style: TextStyle(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: widget.isSending
                              ? null
                              : (widget.onFinishRecording ??
                                  widget.onToggleRecording),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (hasQueuedAttachment)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ComposerPendingAttachments(
                    pending: pending,
                    isSending: widget.isSending,
                    overLimit: overLimit,
                    fieldBackgroundColor: widget.fieldBackgroundColor ??
                        theme.composerFieldBackground,
                    theme: theme,
                    onRemove: widget.onRemovePendingAttachment,
                    onClearAll: widget.onClearAllPendingAttachments,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.fieldBackgroundColor ??
                            theme.composerFieldBackground,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              label: 'Message composer',
                              textField: true,
                              child: TextField(
                                focusNode: widget.textFieldFocusNode,
                                controller: widget.controller,
                                style: widget.inputTextStyle,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) {
                                  if (canSend) {
                                    widget.onSend();
                                  }
                                },
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: effectiveHint,
                                  hintStyle: widget.hintTextStyle ??
                                      TextStyle(color: theme.mutedText),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: widget.fieldContentPadding ??
                                      const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
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
                            onPressed: widget.isSending
                                ? null
                                : () => _showAttachments(context),
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
                    onPressed: widget.isSending
                        ? null
                        : widget.isRecording
                            ? (widget.onFinishRecording ??
                                widget.onToggleRecording)
                            : (widget.onStartRecording ??
                                widget.onToggleRecording),
                    icon: Icon(
                      widget.isRecording
                          ? Icons.stop_circle_outlined
                          : Icons.mic_none,
                      color: widget.isRecording
                          ? const Color(0xFFDC2626)
                          : theme.mutedText,
                    ),
                  ),
                  _CircleButton(
                    icon: Icons.send_rounded,
                    color: canSend
                        ? theme.primary
                        : theme.primary.withValues(alpha: 0.35),
                    iconColor: Colors.white,
                    onTap: canSend ? widget.onSend : null,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ComposerPendingAttachments extends StatelessWidget {
  const _ComposerPendingAttachments({
    required this.pending,
    required this.isSending,
    required this.overLimit,
    required this.fieldBackgroundColor,
    required this.theme,
    this.onRemove,
    this.onClearAll,
  });

  final List<MessengerPickedMedia> pending;
  final bool isSending;
  final bool overLimit;
  final Color fieldBackgroundColor;
  final MessengerThemeData theme;
  final ValueChanged<int>? onRemove;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final totalBytes = pendingAttachmentsTotalBytes(pending);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: fieldBackgroundColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: overLimit ? const Color(0xFFDC2626) : theme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (overLimit)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'These attachments total ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB '
                'combined (limit 25 MB). Remove some files or send in smaller batches.',
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ...List.generate(pending.length, (index) {
            final att = pending[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index < pending.length - 1 ? 6 : 0),
              child: _ComposerPendingRow(
                att: att,
                theme: theme,
                isSending: isSending,
                onRemove: onRemove == null
                    ? null
                    : () => onRemove!(index),
              ),
            );
          }),
          if (pending.length > 1 && onClearAll != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isSending ? null : onClearAll,
                  child: const Text('Remove all'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComposerPendingRow extends StatelessWidget {
  const _ComposerPendingRow({
    required this.att,
    required this.theme,
    required this.isSending,
    this.onRemove,
  });

  final MessengerPickedMedia att;
  final MessengerThemeData theme;
  final bool isSending;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final label = att.fromRecorder
        ? 'Voice recording'
        : att.displayName;
    return Row(
      children: [
        _ComposerPendingThumb(att: att),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              Text(
                _formatFileSize(att.file),
                style: TextStyle(
                  color: theme.mutedText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (onRemove != null)
          IconButton(
            onPressed: isSending ? null : onRemove,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: isSending ? theme.mutedText : theme.primary,
            ),
            tooltip: 'Remove attachment',
          ),
      ],
    );
  }

  String _formatFileSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) {
        return '$bytes B';
      }
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }
}

class _ComposerPendingThumb extends StatelessWidget {
  const _ComposerPendingThumb({required this.att});

  final MessengerPickedMedia att;

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    if (att.fromRecorder) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.mic_rounded, size: 20, color: Color(0xFF2563EB)),
      );
    }
    if (att.messageType == MessageType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          att.file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _typeIcon(Icons.image_outlined),
        ),
      );
    }
    if (att.messageType == MessageType.video) {
      return _typeIcon(Icons.videocam_outlined);
    }
    if (att.messageType == MessageType.voice) {
      return _typeIcon(Icons.graphic_eq_rounded);
    }
    return _typeIcon(Icons.description_outlined);
  }

  Widget _typeIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
    );
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
