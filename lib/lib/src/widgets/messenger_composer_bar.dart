import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messenger_attachment.dart';
import '../models/messenger_message.dart';
import '../theme/messenger_theme.dart';

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
    this.typingConversationId,
    this.onTypingStart,
    this.onTypingStop,
    this.typingStartMinInterval = const Duration(seconds: 2),
    this.typingStopIdle = const Duration(seconds: 2),
    this.hasPendingAttachment = false,
    this.pendingAttachmentLabel,
    this.onClearPendingAttachment,
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

  final String? typingConversationId;
  final Future<void> Function(String conversationId)? onTypingStart;
  final Future<void> Function(String conversationId)? onTypingStop;
  final Duration typingStartMinInterval;
  final Duration typingStopIdle;
  final bool hasPendingAttachment;
  final String? pendingAttachmentLabel;
  final VoidCallback? onClearPendingAttachment;
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
        label: 'Video',
        icon: Icons.videocam_outlined,
        onTap: widget.onPickVideo,
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
          final hasQueuedAttachment = widget.hasPendingAttachment;
          final canSend = (hasText || hasQueuedAttachment) &&
              !widget.isSending &&
              !widget.isRecording;

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
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: (widget.fieldBackgroundColor ??
                              theme.composerFieldBackground)
                          .withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_file_rounded,
                            color: theme.primary, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.pendingAttachmentLabel ?? 'Attachment ready',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        if (widget.onClearPendingAttachment != null)
                          GestureDetector(
                            onTap: widget.isSending
                                ? null
                                : widget.onClearPendingAttachment,
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
                                  hintText: widget.hintText,
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
