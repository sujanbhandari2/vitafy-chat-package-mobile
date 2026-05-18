import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:http/http.dart' as http;

import '../models/messenger_message.dart';
import '../theme/messenger_theme.dart';
import 'messenger_avatar.dart';

class MessengerMessageBubble extends StatefulWidget {
  const MessengerMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.currentUserId,
    this.canDelete = false,
    this.onReact,
    this.onRemoveReaction,
    this.onDelete,
    this.canEdit = false,
    this.onEdit,
    this.onMarkSeen,
    this.enableReactions = true,
    this.reactionOptions = const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
    this.deleteActionIcon = Icons.delete_outline,
    this.deleteActionTextStyle = const TextStyle(
      color: Color(0xFFDC2626),
      fontSize: 16,
    ),
    this.onSwipeToReply,
    this.attachmentCaptionTextStyle,
    this.packageDialogTheme,
  });

  final MessengerChatMessage message;
  final bool isMine;
  final String? currentUserId;
  final bool canDelete;
  final ValueChanged<String>? onReact;
  final Future<void> Function(String messageId, String reactionType)?
      onRemoveReaction;
  final FutureOr<void> Function()? onDelete;
  /// When set with [canEdit], long-press shows an "Edit message" action (text only).
  final VoidCallback? onEdit;
  final bool canEdit;
  final VoidCallback? onMarkSeen;
  final bool enableReactions;
  final List<String> reactionOptions;
  final IconData deleteActionIcon;
  final TextStyle deleteActionTextStyle;
  final ValueChanged<MessengerChatMessage>? onSwipeToReply;
  /// Merged onto the default caption style under attachment payloads (image,
  /// video, file, voice). Omitted fields keep theme-derived defaults.
  final TextStyle? attachmentCaptionTextStyle;

  /// Merged with [Theme.of] for package dialogs opened from this bubble
  /// (e.g. image preview). See [MessengerChatShell.packageDialogTheme].
  final ThemeData? packageDialogTheme;

  @override
  State<MessengerMessageBubble> createState() => _MessengerMessageBubbleState();
}

class _MessengerMessageBubbleState extends State<MessengerMessageBubble> {
  bool _messageActionsSheetOpen = false;
  bool _messageSheetClosingOnce = false;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final bubbleColor = widget.isMine ? theme.bubbleMine : theme.bubbleOther;
    final textColor =
        widget.isMine ? theme.bubbleMineText : theme.bubbleOtherText;
    final timeColor =
        widget.isMine ? theme.bubbleMineTime : theme.bubbleOtherTime;
    final attachmentCaptionStyle =
        _mergedAttachmentCaptionStyle(
      textColor: textColor,
      override: widget.attachmentCaptionTextStyle,
    );
    return Semantics(
      container: true,
      label: 'Message from ${widget.message.senderLabel}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              widget.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!widget.isMine) ...[
              MessengerAvatar(
                label: _initials(widget.message.senderLabel),
                imageUrl: widget.message.senderAvatarUrl,
                size: 26,
                compact: true,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: _SwipeToReplyDetector(
                enabled: widget.onSwipeToReply != null &&
                    !widget.message.isUploading &&
                    !widget.message.isDeleted,
                isMine: widget.isMine,
                onCommit: widget.onSwipeToReply == null
                    ? null
                    : () => widget.onSwipeToReply!(widget.message),
                child: GestureDetector(
                  onLongPress: () => _showMessageActionsSheet(context),
                  child: Column(
                    crossAxisAlignment: widget.isMine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: _maxBubbleWidth(context),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(18),
                          border: widget.isMine
                              ? Border.all(color: theme.border)
                              : null,
                        ),
                        child: IntrinsicWidth(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.message.quotedReply != null) ...[
                                _BubbleQuotedReply(
                                  quote: widget.message.quotedReply!,
                                  textColor: textColor,
                                  mutedColor: timeColor,
                                  accentColor: theme.primary,
                                  maxTextWidth: _maxBubbleWidth(context) - 56,
                                ),
                                const SizedBox(height: 8),
                              ],
                              Align(
                                alignment: widget.isMine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: _MessageContent(
                                  message: widget.message,
                                  textColor: textColor,
                                  mutedColor: timeColor,
                                  attachmentCaptionStyle:
                                      attachmentCaptionStyle,
                                  packageDialogTheme: widget.packageDialogTheme,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: widget.isMine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat('h:mm a')
                                          .format(widget.message.createdAt),
                                      style: TextStyle(
                                        color: timeColor,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (widget.isMine) ...[
                                      const SizedBox(width: 4),
                                      _DeliveryTick(
                                        status:
                                            widget.message.deliveryStatus,
                                        bubbleColor: bubbleColor,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (widget.message.isUploading ||
                                  widget.message.uploadProgress != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: SizedBox(
                                    width: 220,
                                    child: LinearProgressIndicator(
                                      minHeight: 3,
                                      value: widget.message.uploadProgress,
                                      backgroundColor: timeColor
                                          .withValues(alpha: 0.2),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        timeColor,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (widget.message.reactions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: widget.message.reactions.map(
                          (reaction) {
                            final canRemove = widget.onRemoveReaction != null &&
                                widget.currentUserId != null &&
                                reaction.userId == widget.currentUserId;
                            final chip = Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: theme.reactionBackground,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: theme.reactionBorder,
                                ),
                              ),
                              child: Text(
                                reaction.reactionType,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                            if (!canRemove) {
                              return chip;
                            }
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => widget.onRemoveReaction!(
                                  widget.message.id,
                                  reaction.reactionType,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                child: chip,
                              ),
                            );
                          },
                        ).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMessageActionsSheet(BuildContext context) async {
    final canReact = !widget.message.isDeleted &&
        widget.enableReactions &&
        widget.onReact != null;
    final canDelete = widget.canDelete && widget.onDelete != null;
    final canEdit =
        widget.canEdit && widget.onEdit != null && !widget.message.isDeleted;
    final hasAnyAction = canReact || canDelete || canEdit;
    if (!hasAnyAction) {
      return;
    }
    _dismissKeyboardFocus();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canReact) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 12, right: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: widget.reactionOptions
                          .map(
                            (reaction) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () {
                                    Navigator.of(sheetContext).pop();
                                    widget.onReact?.call(reaction);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      reaction,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),
            ],
            if (canEdit)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    widget.onEdit?.call();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 22,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Edit message',
                          style: widget.deleteActionTextStyle.merge(
                            TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (canDelete)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _confirmAndDeleteMessage();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.deleteActionIcon,
                          size: 22,
                          color: widget.deleteActionTextStyle.color ??
                              const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Delete message',
                          style: widget.deleteActionTextStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _dismissKeyboardFocus() {
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus != null && currentFocus.hasFocus) {
      currentFocus.unfocus();
    }
  }

  Future<void> _confirmAndDeleteMessage() async {
    _dismissKeyboardFocus();
    final didDelete = await showDialog<bool>(
          context: context,
          useRootNavigator: true,
          builder: (dialogContext) => wrapMessengerPackageDialogTheme(
            ambientContext: context,
            packageDialogTheme: widget.packageDialogTheme,
            child: _MessengerDeleteMessageDialog(
              onDeleteConfirmed: () async {
                await Future<void>.sync(() => widget.onDelete?.call());
              },
            ),
          ),
        ) ??
        false;
    if (!didDelete || !mounted) {
      return;
    }
  }

  double _maxBubbleWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= 0) {
      return 320;
    }
    return width * 0.72 > 420 ? 420 : width * 0.72;
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return 'U';
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : 'U';
    final second = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1][0]
        : (parts.first.length > 1 ? parts.first[1] : '');
    return '$first$second'.toUpperCase();
  }
}

class _MessengerDeleteMessageDialog extends StatefulWidget {
  const _MessengerDeleteMessageDialog({
    required this.onDeleteConfirmed,
  });

  final Future<void> Function() onDeleteConfirmed;

  @override
  State<_MessengerDeleteMessageDialog> createState() =>
      _MessengerDeleteMessageDialogState();
}

class _MessengerDeleteMessageDialogState
    extends State<_MessengerDeleteMessageDialog> {
  bool _deleting = false;

  Future<void> _onDeletePressed() async {
    setState(() => _deleting = true);
    try {
      await widget.onDeleteConfirmed();
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _deleting = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not delete the message.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'Are you sure you want to delete this message? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: _deleting
                ? null
                : () => Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: _deleting ? null : _onDeletePressed,
            child: _deleting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onError,
                    ),
                  )
                : const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SwipeToReplyDetector extends StatefulWidget {
  const _SwipeToReplyDetector({
    required this.enabled,
    required this.isMine,
    required this.child,
    this.onCommit,
  });

  final bool enabled;
  final bool isMine;
  final VoidCallback? onCommit;
  final Widget child;

  @override
  State<_SwipeToReplyDetector> createState() => _SwipeToReplyDetectorState();
}

class _SwipeToReplyDetectorState extends State<_SwipeToReplyDetector> {
  static const double _kMaxPull = 56;
  static const double _kCommitThreshold = 40;
  double _pull = 0;

  bool _swipeNegative(BuildContext context) {
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    return isLtr ? widget.isMine : !widget.isMine;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || widget.onCommit == null) {
      return;
    }
    final negate = _swipeNegative(context);
    setState(() {
      final next = _pull + details.delta.dx;
      if (negate) {
        _pull = next.clamp(-_kMaxPull, 0.0);
      } else {
        _pull = next.clamp(0.0, _kMaxPull);
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled || widget.onCommit == null) {
      setState(() => _pull = 0);
      return;
    }
    final negate = _swipeNegative(context);
    final commit =
        negate ? _pull <= -_kCommitThreshold : _pull >= _kCommitThreshold;
    if (commit) {
      widget.onCommit!();
    }
    setState(() => _pull = 0);
  }

  void _onHorizontalDragCancel() {
    setState(() => _pull = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _onHorizontalDragCancel,
      behavior: HitTestBehavior.deferToChild,
      child: Transform.translate(
        offset: Offset(_pull, 0),
        child: widget.child,
      ),
    );
  }
}

class _BubbleQuotedReply extends StatelessWidget {
  const _BubbleQuotedReply({
    required this.quote,
    required this.textColor,
    required this.mutedColor,
    required this.accentColor,
    required this.maxTextWidth,
  });

  final MessengerQuotedMessage quote;
  final Color textColor;
  final Color mutedColor;
  final Color accentColor;
  /// Caps quote text lines so [IntrinsicWidth] can shrink-wrap short previews.
  final double maxTextWidth;

  @override
  Widget build(BuildContext context) {
    final thumb = _maybeThumbUrl();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 40,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        if (thumb != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              thumb,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                width: 32,
                height: 32,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxTextWidth > 40 ? maxTextWidth : 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                quote.senderLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor.withValues(alpha: 0.92),
                ),
              ),
              Text(
                quote.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: mutedColor,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _maybeThumbUrl() {
    if (quote.messageType != MessengerMessageType.image) {
      return null;
    }
    final u = quote.preview.trim();
    final uri = Uri.tryParse(u);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        u.isNotEmpty) {
      return u;
    }
    return null;
  }
}

class _DeliveryTick extends StatelessWidget {
  const _DeliveryTick({
    required this.status,
    required this.bubbleColor,
  });

  final MessengerDeliveryStatus status;
  final Color bubbleColor;

  static const double _chipSize = 16;
  static const double _iconSize = 11;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    if (status == MessengerDeliveryStatus.none) {
      return const SizedBox.shrink();
    }

    final icon =
        status == MessengerDeliveryStatus.sent ? Icons.done : Icons.done_all;
    final iconColor = status == MessengerDeliveryStatus.seen
        ? theme.primary
        : theme.mutedText;

    // White chip on dark outgoing bubbles so blue "seen" ticks stay visible.
    final onDarkBubble = bubbleColor.computeLuminance() < 0.45;
    final chipFill = onDarkBubble ? Colors.white : theme.surface;
    final chipBorder = onDarkBubble
        ? null
        : Border.all(color: theme.border.withValues(alpha: 0.7));

    return Semantics(
      label: _semanticsLabel(status),
      child: Container(
        width: _chipSize,
        height: _chipSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: chipFill,
          shape: BoxShape.circle,
          border: chipBorder,
        ),
        child: Icon(icon, size: _iconSize, color: iconColor),
      ),
    );
  }

  static String _semanticsLabel(MessengerDeliveryStatus status) {
    switch (status) {
      case MessengerDeliveryStatus.none:
        return '';
      case MessengerDeliveryStatus.sent:
        return 'Message sent';
      case MessengerDeliveryStatus.delivered:
        return 'Message delivered';
      case MessengerDeliveryStatus.seen:
        return 'Message seen';
    }
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.textColor,
    required this.mutedColor,
    required this.attachmentCaptionStyle,
    this.packageDialogTheme,
  });

  final MessengerChatMessage message;
  final Color textColor;
  final Color mutedColor;
  final TextStyle attachmentCaptionStyle;
  final ThemeData? packageDialogTheme;

  Widget _attachmentCaptionIfAny() {
    final cap = message.caption?.trim() ?? '';
    if (cap.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(cap, style: attachmentCaptionStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Text(
        'Message deleted',
        style: TextStyle(
          fontSize: 14,
          color: textColor.withValues(alpha: 0.85),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (message.isUploading) {
      return Text(
        'Uploading...',
        style: TextStyle(
          fontSize: 14,
          color: textColor.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (message.type == MessengerMessageType.image) {
      final uri = Uri.tryParse(message.content);
      final isNetwork =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      return GestureDetector(
        onTap: () => _openImagePreview(context, message.content, isNetwork),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isNetwork
                  ? Image.network(
                      message.content,
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        final expected = loadingProgress.expectedTotalBytes;
                        final loaded = loadingProgress.cumulativeBytesLoaded;
                        final value = expected == null
                            ? null
                            : loaded / expected.toDouble();
                        return Container(
                          width: 220,
                          height: 220,
                          alignment: Alignment.center,
                          color: mutedColor.withValues(alpha: 0.15),
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 2,
                            color: mutedColor,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 220,
                        height: 100,
                        child: Center(child: Text('Unable to load image')),
                      ),
                    )
                  : Image.file(
                      File(message.content),
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 220,
                        height: 100,
                        child: Center(child: Text('Unable to load image')),
                      ),
                    ),
            ),
            _attachmentCaptionIfAny(),
          ],
        ),
      );
    }

    if (message.type == MessengerMessageType.video) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaAssetTile(
            icon: Icons.videocam_rounded,
            label: _labelForContent(message.content, fallback: 'Video'),
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          _attachmentCaptionIfAny(),
        ],
      );
    }

    if (message.type == MessengerMessageType.file) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaAssetTile(
            icon: Icons.insert_drive_file_rounded,
            label: _labelForContent(message.content, fallback: 'File'),
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          _attachmentCaptionIfAny(),
        ],
      );
    }

    if (message.type == MessengerMessageType.voice) {
      final uri = Uri.tryParse(message.content);
      final isNetwork =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessengerVoicePlayer(
            source: message.content,
            preferDeviceFile: !isNetwork,
            iconColor: textColor,
            waveformActiveColor: textColor,
            waveformInactiveColor: textColor.withValues(alpha: 0.35),
          ),
          _attachmentCaptionIfAny(),
        ],
      );
    }

    return Text(
      message.content,
      style: TextStyle(fontSize: 14.5, color: textColor, height: 1.28),
    );
  }

  void _openImagePreview(
    BuildContext context,
    String source,
    bool isNetwork,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) => wrapMessengerPackageDialogTheme(
        ambientContext: context,
        packageDialogTheme: packageDialogTheme,
        child: Builder(
          builder: (context) {
            final imageWidget = isNetwork
            ? Image.network(
                source,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'Unable to load image',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            : Image.file(
                File(source),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'Unable to load image',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: imageWidget,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  elevation: 4,
                  shadowColor: Colors.black45,
                  child: IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
          },
        ),
      ),
    );
  }
}

class _MediaAssetTile extends StatelessWidget {
  const _MediaAssetTile({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.mutedColor,
  });

  final IconData icon;
  final String label;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: mutedColor.withValues(alpha: 0.14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: textColor.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [TextStyle.merge] returns [other] unchanged when [other.inherit] is false,
/// which drops bubble defaults such as [color]. Normalize so host overrides
/// layer on the themed base instead of replacing it.
TextStyle _mergedAttachmentCaptionStyle({
  required Color textColor,
  TextStyle? override,
}) {
  // Keep the caption's color identical to the bubble's body text so a caption
  // sent alongside an attachment doesn't look faded compared to a plain
  // text-only message.
  final base = TextStyle(
    fontSize: 13,
    color: textColor,
    height: 1.25,
  );
  if (override == null) {
    return base;
  }
  final o = override.inherit ? override : override.copyWith(inherit: true);
  return base.merge(o);
}

String _labelForContent(String content, {required String fallback}) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return fallback;
  }
  if (uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.last;
  }
  return fallback;
}

class MessengerVoicePlayer extends StatefulWidget {
  const MessengerVoicePlayer({
    super.key,
    required this.source,
    this.preferDeviceFile = false,
    required this.iconColor,
    required this.waveformActiveColor,
    required this.waveformInactiveColor,
  });

  final String source;
  final bool preferDeviceFile;
  final Color iconColor;
  final Color waveformActiveColor;
  final Color waveformInactiveColor;

  @override
  State<MessengerVoicePlayer> createState() => _MessengerVoicePlayerState();
}

/// Logical playback stage for [MessengerVoicePlayer]. Combines audio-player
/// transport state with our own loading/error tracking so the UI can show a
/// spinner and disable controls until the source is ready.
enum _VoicePlaybackStage {
  /// Initial state: source has not been primed yet, or is currently priming.
  loading,

  /// Source is primed and ready; playback has not started.
  ready,

  /// Currently playing audio.
  playing,

  /// User paused playback.
  paused,

  /// Playback reached the end.
  completed,

  /// Source could not be primed or played.
  error,
}

class _MessengerVoicePlayerState extends State<MessengerVoicePlayer> {
  static final Map<String, String> _downloadedAudioCache = <String, String>{};

  /// Total wall-clock time we wait for duration metadata before allowing
  /// playback controls while the duration label still shows a loading
  /// indicator (never `00:00` as a fake placeholder).
  static const Duration _maxLoadingWindow = Duration(seconds: 30);

  late final AudioPlayer _player;
  _VoicePlaybackStage _stage = _VoicePlaybackStage.loading;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _primedSource;
  String? _playbackError;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;
  Timer? _loadingFallbackTimer;

  /// True while a play/pause/prime operation is in flight. Prevents duplicate
  /// taps from racing and putting the player into an inconsistent state.
  bool _busy = false;

  /// If the user tapped the play button while the bubble was still loading,
  /// we remember that intent and auto-start playback the moment the audio is
  /// truly ready (duration available + source primed). Tapping again while
  /// loading cancels the queued auto-play.
  bool _autoPlayWhenReady = false;

  /// Tracks the most recent prime request so stale results from older sources
  /// (after [didUpdateWidget]) cannot overwrite newer state.
  int _primeToken = 0;

  bool get _hasKnownDuration => _duration > Duration.zero;

  static const List<double> _waveformHeights = [
    4,
    9,
    6,
    13,
    8,
    14,
    5,
    11,
    7,
    15,
    6,
    12,
    8,
    14,
    5,
    10,
    7,
    13,
    6,
    11,
    8,
    12,
    6,
    9,
  ];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    // Keep buffered data + the prepared source between plays. The default
    // [ReleaseMode.release] tears the MediaPlayer down after completion, which
    // causes replay to silently re-download the file and triggers the
    // reset/release/prepareAsync loops seen in Android logs.
    unawaited(_player.setReleaseMode(ReleaseMode.stop));
    _stateSub = _player.onPlayerStateChanged.listen(_handlePlayerState);
    _durationSub = _player.onDurationChanged.listen((duration) {
      if (!mounted || duration <= Duration.zero) {
        return;
      }
      setState(() {
        _duration = duration;
      });
      // Duration arriving from the stream is the most reliable "ready" signal
      // for large network audio (some platforms only emit it after the prepared
      // event). Only flip out of loading once we actually have metadata.
      if (_primedSource != null && _stage == _VoicePlaybackStage.loading) {
        _markReady();
      }
    });
    _positionSub = _player.onPositionChanged.listen((position) {
      if (!mounted) {
        return;
      }
      final clamped = _duration == Duration.zero || position <= _duration
          ? position
          : _duration;
      setState(() => _position = clamped);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _stage = _VoicePlaybackStage.completed;
        _position = Duration.zero;
        _playbackError = null;
      });
    });
    _VoicePlayerLifecycleHandler.instance.register(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_primeSource());
    });
  }

  @override
  void didUpdateWidget(covariant MessengerVoicePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _primedSource = null;
      unawaited(_resetPlayerForNewSource());
    }
  }

  Future<void> _resetPlayerForNewSource() async {
    _cancelLoadingFallbackTimer();
    try {
      await _player.stop();
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() {
      _duration = Duration.zero;
      _position = Duration.zero;
      _stage = _VoicePlaybackStage.loading;
      _playbackError = null;
      _autoPlayWhenReady = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_primeSource());
    });
  }

  @override
  void dispose() {
    _cancelLoadingFallbackTimer();
    _VoicePlayerLifecycleHandler.instance.unregister(this);
    _stateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    // Best-effort stop before disposing to release any platform-side resources
    // immediately — disposing alone is not always enough on iOS.
    unawaited(_safeStop());
    _player.dispose();
    super.dispose();
  }

  Future<void> _safeStop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Stops playback when the host app is being terminated.
  Future<void> _stopForLifecycle() async {
    await _safeStop();
    if (!mounted) {
      return;
    }
    setState(() {
      _stage = _primedSource == null
          ? _VoicePlaybackStage.loading
          : _VoicePlaybackStage.ready;
      _position = Duration.zero;
    });
  }

  /// Pauses playback when the host app moves to the background so audio does
  /// not continue while the user is in another app.
  Future<void> _pauseForLifecycle() async {
    if (_stage != _VoicePlaybackStage.playing) {
      return;
    }
    try {
      await _player.pause();
    } catch (_) {}
  }

  void _handlePlayerState(PlayerState state) {
    if (!mounted) {
      return;
    }
    setState(() {
      switch (state) {
        case PlayerState.playing:
          _stage = _VoicePlaybackStage.playing;
          _playbackError = null;
          break;
        case PlayerState.paused:
          // During the initial preparation phase some platforms emit a
          // transient `paused` event before metadata is in. Ignore those so
          // the bubble stays in `loading`. Once we've left loading, every
          // `paused` event is a real user/system pause.
          if (_stage != _VoicePlaybackStage.loading) {
            _stage = _VoicePlaybackStage.paused;
          }
          break;
        case PlayerState.completed:
          _stage = _VoicePlaybackStage.completed;
          _position = Duration.zero;
          break;
        case PlayerState.stopped:
          // Stopped is emitted both as a transient state during preparation
          // and when another bubble starts playing and pre-empts this one.
          // Only honour it once we've already left the loading phase.
          if (_stage != _VoicePlaybackStage.loading) {
            _stage = _VoicePlaybackStage.ready;
            _position = Duration.zero;
          }
          break;
        case PlayerState.disposed:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _stage == _VoicePlaybackStage.playing;
    final isLoading = _stage == _VoicePlaybackStage.loading;
    final awaitingDuration = !_hasKnownDuration;
    // Allow taps while loading so the user can queue an auto-play request,
    // but keep the button visually subdued so it's clear playback hasn't
    // actually started yet.
    final canTap = !_busy;
    final progress = !_hasKnownDuration
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              enabled: canTap,
              label: isLoading
                  ? (_autoPlayWhenReady
                      ? 'Audio loading, will play when ready'
                      : 'Audio loading, tap to play when ready')
                  : isPlaying
                      ? 'Pause audio'
                      : 'Play audio',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: canTap ? _onPlayPauseTap : null,
                child: Opacity(
                  opacity: isLoading ? 0.55 : 1.0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.iconColor.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: widget.iconColor,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 135,
              height: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(_waveformHeights.length, (index) {
                  final threshold = (index + 1) / _waveformHeights.length;
                  final isActive =
                      !isLoading && !awaitingDuration && progress >= threshold;
                  return Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 2,
                        height: _waveformHeights[index],
                        decoration: BoxDecoration(
                          color: isActive
                              ? widget.waveformActiveColor
                              : widget.waveformInactiveColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 8),
            _buildDurationLabel(),
          ],
        ),
        if (_playbackError != null) ...[
          const SizedBox(height: 4),
          Text(
            _playbackError!,
            style: TextStyle(
              color: widget.iconColor.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDurationLabel() {
    // Never show a numeric time as a stand-in for unknown duration. Keep a
    // spinner until [onDurationChanged] / [getDuration] reports a value > 0,
    // including after the long-timeout "ready" fallback (same for errors).
    if (!_hasKnownDuration) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.iconColor.withValues(alpha: 0.85),
          ),
        ),
      );
    }
    return Text(
      _timeLabelForUi(),
      style: TextStyle(
        color: widget.iconColor.withValues(alpha: 0.9),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Future<void> _onPlayPauseTap() async {
    if (_busy) {
      return;
    }
    // While the bubble is still loading, capture the user's intent so we can
    // auto-start playback the moment metadata arrives instead of silently
    // dropping the tap. Tapping again cancels the queued auto-play.
    if (_stage == _VoicePlaybackStage.loading) {
      setState(() => _autoPlayWhenReady = !_autoPlayWhenReady);
      return;
    }
    _busy = true;
    try {
      switch (_stage) {
        case _VoicePlaybackStage.playing:
          await _pause();
          break;
        case _VoicePlaybackStage.paused:
          await _resumeFromPaused();
          break;
        case _VoicePlaybackStage.ready:
        case _VoicePlaybackStage.completed:
        case _VoicePlaybackStage.error:
          await _startPlayback();
          break;
        case _VoicePlaybackStage.loading:
          break;
      }
    } finally {
      if (mounted) {
        setState(() {});
      }
      _busy = false;
    }
  }

  Future<void> _pause() async {
    try {
      await _player.pause();
    } catch (_) {
      _setPlaybackError('Unable to pause audio');
    }
  }

  Future<void> _resumeFromPaused() async {
    try {
      await _stopOtherPlayers();
      await _player.resume();
      _clearPlaybackError();
    } catch (_) {
      _setPlaybackError('Unable to resume audio');
    }
  }

  /// Start playback from the beginning (or from a completed state). Reuses the
  /// already-primed source when possible so the play button responds instantly
  /// instead of re-downloading or re-setting the source on every tap.
  Future<void> _startPlayback() async {
    if (_primedSource == widget.source) {
      try {
        await _stopOtherPlayers();
        if (_stage == _VoicePlaybackStage.completed) {
          // With ReleaseMode.stop the source is still primed after completion,
          // so a simple seek-to-start + resume is enough to replay without
          // touching the network or recreating the underlying MediaPlayer.
          await _player.seek(Duration.zero);
          if (mounted) {
            setState(() => _position = Duration.zero);
          }
        }
        await _player.resume();
        _VoicePlayerLifecycleHandler.instance.markActive(this);
        _clearPlaybackError();
        return;
      } catch (_) {
        // Avoid nuking primed + full re-download on a flaky resume(); try
        // lighter recovery first (same player, same buffered source).
        try {
          await _stopOtherPlayers();
          await _player.stop();
          await _player.resume();
          _VoicePlayerLifecycleHandler.instance.markActive(this);
          _clearPlaybackError();
          return;
        } catch (_) {}
        try {
          final reapplied = await _applySource(widget.source);
          if (reapplied && mounted) {
            await _player.resume();
            _VoicePlayerLifecycleHandler.instance.markActive(this);
            _clearPlaybackError();
            return;
          }
        } catch (_) {}
        _primedSource = null;
        if (mounted) {
          setState(() {
            _stage = _VoicePlaybackStage.loading;
            _position = Duration.zero;
          });
        }
      }
    } else if (mounted) {
      // Source isn't primed yet — surface buffering state instead of leaving
      // the user staring at a disabled-but-silent button on large files.
      setState(() => _stage = _VoicePlaybackStage.loading);
    }

    if (widget.preferDeviceFile) {
      final directLocal = await _tryPlayFromDeviceFile(widget.source);
      if (directLocal) {
        return;
      }
    }

    final remotePlayed = await _tryPlayFromUrl(widget.source);
    if (remotePlayed) {
      return;
    }

    final encodedPlayed = await _tryPlayFromUrl(Uri.encodeFull(widget.source));
    if (encodedPlayed) {
      return;
    }

    final localPlayed = await _tryPlayFromDownloadedFile(widget.source);
    if (localPlayed) {
      return;
    }

    if (mounted) {
      _primedSource = null;
      setState(() => _stage = _VoicePlaybackStage.error);
    }
    _setPlaybackError('Audio cannot be played on this device');
  }

  String _timeLabelForUi() {
    if (!_hasKnownDuration) {
      return '';
    }
    // Keep the same remaining-time readout across play/pause so the label
    // doesn't snap back to the full duration when the user pauses. Only when
    // playback hasn't started yet (or has just completed/reset to zero) do we
    // show the full duration as the "initial" label.
    if (_position > Duration.zero &&
        (_stage == _VoicePlaybackStage.playing ||
            _stage == _VoicePlaybackStage.paused)) {
      var remaining = _duration - _position;
      if (remaining < Duration.zero) {
        remaining = Duration.zero;
      }
      return _formatDuration(remaining);
    }
    return _formatDuration(_duration);
  }

  Future<void> _primeSource() async {
    if (!mounted || widget.source.isEmpty) {
      return;
    }
    // Same URL is already prepared — never call setSource again. Re-priming
    // when duration was still unknown caused duplicate prepare/HTTP cycles and
    // made the UI jump back to "loading" after play.
    if (_primedSource == widget.source) {
      return;
    }
    if (_stage == _VoicePlaybackStage.playing) {
      return;
    }
    final src = widget.source;
    final token = ++_primeToken;
    if (mounted) {
      setState(() {
        _stage = _VoicePlaybackStage.loading;
        _playbackError = null;
      });
    }
    _startLoadingFallbackTimer(token);
    try {
      final primed = await _applySource(src);
      if (!primed) {
        if (mounted && token == _primeToken) {
          _cancelLoadingFallbackTimer();
          setState(() => _stage = _VoicePlaybackStage.error);
        }
        return;
      }
      if (!mounted || widget.source != src || token != _primeToken) {
        return;
      }
      _primedSource = src;
      // Try once now — for healthy sources with proper metadata this returns
      // the duration straight away.
      Duration? d;
      try {
        d = await _player.getDuration();
      } catch (_) {
        d = null;
      }
      if (!mounted || widget.source != src || token != _primeToken) {
        return;
      }
      if (d != null && d > Duration.zero) {
        setState(() => _duration = d!);
        _markReady();
        return;
      }
      // Duration not yet available — keep the loader visible and wait for the
      // [onDurationChanged] stream listener (or the fallback timer) to drive
      // the transition. The bubble must NOT report ready while duration is
      // still 00:00.
    } catch (_) {
      if (mounted && token == _primeToken) {
        _cancelLoadingFallbackTimer();
        _primedSource = null;
        setState(() => _stage = _VoicePlaybackStage.error);
      }
    }
  }

  /// Centralizes the loading → ready transition so every entry point (initial
  /// prime, late duration-stream event, fallback timer) honours queued
  /// auto-play in exactly the same way.
  void _markReady() {
    if (!mounted) {
      return;
    }
    _cancelLoadingFallbackTimer();
    setState(() {
      _stage = _VoicePlaybackStage.ready;
      _playbackError = null;
    });
    if (_autoPlayWhenReady) {
      _autoPlayWhenReady = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_onPlayPauseTap());
        }
      });
    }
  }

  /// After [_maxLoadingWindow] without duration metadata, the source is still
  /// prepared and playable. We enable controls but keep the duration slot on a
  /// spinner until a real duration arrives (no `00:00` placeholder).
  void _startLoadingFallbackTimer(int token) {
    _cancelLoadingFallbackTimer();
    _loadingFallbackTimer = Timer(_maxLoadingWindow, () {
      if (!mounted || token != _primeToken) {
        return;
      }
      if (_stage != _VoicePlaybackStage.loading) {
        return;
      }
      if (_primedSource == widget.source) {
        _markReady();
      } else {
        setState(() => _stage = _VoicePlaybackStage.error);
      }
    });
  }

  void _cancelLoadingFallbackTimer() {
    _loadingFallbackTimer?.cancel();
    _loadingFallbackTimer = null;
  }

  /// Applies the source to the underlying player without starting playback.
  /// Returns true on success, false when the source cannot be resolved.
  Future<bool> _applySource(String src) async {
    if (widget.preferDeviceFile) {
      final file = File(src);
      if (!await file.exists()) {
        return false;
      }
      await _player.setSourceDeviceFile(file.path);
      return true;
    }
    final uri = Uri.tryParse(src);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (isNetwork) {
      await _player.setSourceUrl(src);
      return true;
    }
    final file = File(src);
    if (!await file.exists()) {
      return false;
    }
    await _player.setSourceDeviceFile(file.path);
    return true;
  }

  String _formatDuration(Duration duration) {
    final safe = duration < Duration.zero ? Duration.zero : duration;
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<bool> _tryPlayFromUrl(String url) async {
    try {
      await _stopOtherPlayers();
      await _player.stop();
      await _player.setSourceUrl(url);
      _primedSource = widget.source;
      await _player.resume();
      _VoicePlayerLifecycleHandler.instance.markActive(this);
      _clearPlaybackError();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryPlayFromDownloadedFile(String originalUrl) async {
    try {
      final cachedPath = _downloadedAudioCache[originalUrl];
      if (cachedPath != null && await File(cachedPath).exists()) {
        await _stopOtherPlayers();
        await _player.stop();
        await _player.setSourceDeviceFile(cachedPath);
        _primedSource = widget.source;
        await _player.resume();
        _VoicePlayerLifecycleHandler.instance.markActive(this);
        _clearPlaybackError();
        return true;
      }

      final uri = Uri.parse(originalUrl);
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final extension = _extractExtension(uri.path);
      final tempPath =
          '${Directory.systemTemp.path}/voice-${originalUrl.hashCode}$extension';
      final file = File(tempPath);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      _downloadedAudioCache[originalUrl] = file.path;

      await _stopOtherPlayers();
      await _player.stop();
      await _player.setSourceDeviceFile(file.path);
      _primedSource = widget.source;
      await _player.resume();
      _VoicePlayerLifecycleHandler.instance.markActive(this);
      _clearPlaybackError();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryPlayFromDeviceFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return false;
      }
      await _stopOtherPlayers();
      await _player.stop();
      await _player.setSourceDeviceFile(file.path);
      _primedSource = widget.source;
      await _player.resume();
      _VoicePlayerLifecycleHandler.instance.markActive(this);
      _clearPlaybackError();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _stopOtherPlayers() async {
    await _VoicePlayerLifecycleHandler.instance.stopOthers(this);
  }

  String _extractExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) {
      return '.audio';
    }
    return path.substring(dotIndex);
  }

  void _setPlaybackError(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _playbackError = message);
  }

  void _clearPlaybackError() {
    if (!mounted) {
      return;
    }
    setState(() => _playbackError = null);
  }
}

/// Tracks every live [MessengerVoicePlayer] so we can:
///   * stop all playback when the host app is detached/terminated, and
///   * pause playback when the app is sent to the background.
///
/// Also serves as the single source of truth for "which player is currently
/// active" so starting a new clip pauses any other clip without relying on a
/// stale static [AudioPlayer] reference.
class _VoicePlayerLifecycleHandler with WidgetsBindingObserver {
  _VoicePlayerLifecycleHandler._();

  static final _VoicePlayerLifecycleHandler instance =
      _VoicePlayerLifecycleHandler._();

  final Set<_MessengerVoicePlayerState> _players =
      <_MessengerVoicePlayerState>{};
  _MessengerVoicePlayerState? _active;
  bool _registered = false;

  void register(_MessengerVoicePlayerState state) {
    _players.add(state);
    if (!_registered) {
      WidgetsBinding.instance.addObserver(this);
      _registered = true;
    }
  }

  void unregister(_MessengerVoicePlayerState state) {
    _players.remove(state);
    if (identical(_active, state)) {
      _active = null;
    }
    if (_players.isEmpty && _registered) {
      WidgetsBinding.instance.removeObserver(this);
      _registered = false;
    }
  }

  void markActive(_MessengerVoicePlayerState state) {
    _active = state;
  }

  Future<void> stopOthers(_MessengerVoicePlayerState requester) async {
    final active = _active;
    if (active == null || identical(active, requester)) {
      return;
    }
    try {
      await active._player.stop();
    } catch (_) {}
    if (active.mounted) {
      // Surface the stopped state to the other bubble so its play icon resets.
      active._handlePlayerState(PlayerState.stopped);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        for (final player in _players.toList(growable: false)) {
          unawaited(player._pauseForLifecycle());
        }
        break;
      case AppLifecycleState.detached:
        for (final player in _players.toList(growable: false)) {
          unawaited(player._stopForLifecycle());
        }
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }
}
