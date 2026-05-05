import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    this.onMarkSeen,
    this.enableReactions = true,
    this.reactionOptions = const ['👍', '❤️', '😂', '😮', '😢', '🙏'],
  });

  final MessengerChatMessage message;
  final bool isMine;
  final String? currentUserId;
  final bool canDelete;
  final ValueChanged<String>? onReact;
  final Future<void> Function(String messageId, String reactionType)?
      onRemoveReaction;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkSeen;
  final bool enableReactions;
  final List<String> reactionOptions;

  @override
  State<MessengerMessageBubble> createState() => _MessengerMessageBubbleState();
}

class _MessengerMessageBubbleState extends State<MessengerMessageBubble> {
  bool _showInlineReactions = false;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final bubbleColor = widget.isMine ? theme.bubbleMine : theme.bubbleOther;
    final textColor =
        widget.isMine ? theme.bubbleMineText : theme.bubbleOtherText;
    final timeColor =
        widget.isMine ? theme.bubbleMineTime : theme.bubbleOtherTime;
    final canShowInlineReactions =
        widget.enableReactions && widget.onReact != null;

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
              child: TapRegion(
                onTapOutside: (_) {
                  if (_showInlineReactions && mounted) {
                    setState(() => _showInlineReactions = false);
                  }
                },
                child: GestureDetector(
                  onLongPress: () async {
                    if (canShowInlineReactions) {
                      if (!mounted) {
                        return;
                      }
                      setState(() => _showInlineReactions = true);
                      return;
                    }
                    await _showActions(context);
                  },
                  child: Column(
                    crossAxisAlignment: widget.isMine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (_showInlineReactions && canShowInlineReactions) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: theme.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...widget.reactionOptions.map(
                                (reaction) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () {
                                        widget.onReact?.call(reaction);
                                        if (mounted) {
                                          setState(
                                            () => _showInlineReactions = false,
                                          );
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          reaction,
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _MessageContent(
                              message: widget.message,
                              textColor: textColor,
                              mutedColor: timeColor,
                            ),
                            const SizedBox(height: 4),
                            Row(
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
                                    status: widget.message.deliveryStatus,
                                  ),
                                ],
                              ],
                            ),
                            if (widget.message.isUploading ||
                                widget.message.uploadProgress != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: LinearProgressIndicator(
                                  minHeight: 3,
                                  value: widget.message.uploadProgress,
                                  backgroundColor:
                                      timeColor.withValues(alpha: 0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    timeColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.message.reactions.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: widget.message.reactions.map(
                            (reaction) {
                              final canRemove =
                                  widget.onRemoveReaction != null &&
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

  Future<void> _showActions(BuildContext context) async {
    final hasAnyAction = widget.onDelete != null && widget.canDelete;
    if (!hasAnyAction) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (widget.canDelete && widget.onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onDelete?.call();
                },
              ),
          ],
        ),
      ),
    );
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

class _DeliveryTick extends StatelessWidget {
  const _DeliveryTick({required this.status});

  final MessengerDeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    if (status == MessengerDeliveryStatus.none) {
      return const SizedBox.shrink();
    }

    final icon =
        status == MessengerDeliveryStatus.sent ? Icons.done : Icons.done_all;
    final color = status == MessengerDeliveryStatus.seen
        ? theme.primary
        : theme.mutedText;

    return Icon(icon, size: 14, color: color);
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.textColor,
    required this.mutedColor,
  });

  final MessengerChatMessage message;
  final Color textColor;
  final Color mutedColor;

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
        child: ClipRRect(
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
                    final value =
                        expected == null ? null : loaded / expected.toDouble();
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
      );
    }

    if (message.type == MessengerMessageType.video) {
      return _MediaAssetTile(
        icon: Icons.videocam_rounded,
        label: _labelForContent(message.content, fallback: 'Video'),
        textColor: textColor,
        mutedColor: mutedColor,
      );
    }

    if (message.type == MessengerMessageType.file) {
      return _MediaAssetTile(
        icon: Icons.insert_drive_file_rounded,
        label: _labelForContent(message.content, fallback: 'File'),
        textColor: textColor,
        mutedColor: mutedColor,
      );
    }

    if (message.type == MessengerMessageType.voice) {
      final uri = Uri.tryParse(message.content);
      final isNetwork =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      return MessengerVoicePlayer(
        source: message.content,
        preferDeviceFile: !isNetwork,
        iconColor: textColor,
        waveformActiveColor: textColor,
        waveformInactiveColor: textColor.withValues(alpha: 0.35),
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
      builder: (dialogContext) {
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

class _MessengerVoicePlayerState extends State<MessengerVoicePlayer> {
  static final Map<String, String> _downloadedAudioCache = <String, String>{};
  static AudioPlayer? _activePlayer;

  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _primedSource;
  String? _playbackError;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;

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
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playerState = state;
        if (state == PlayerState.playing) {
          _playbackError = null;
        }
      });
    });
    _durationSub = _player.onDurationChanged.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() => _duration = duration);
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
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_primeSourceDuration());
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
    try {
      await _player.stop();
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() {
      _duration = Duration.zero;
      _position = Duration.zero;
      _playerState = PlayerState.stopped;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_primeSourceDuration());
    });
  }

  @override
  void dispose() {
    if (_activePlayer == _player) {
      _activePlayer = null;
    }
    _stateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final canResume = _playerState == PlayerState.paused;
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () =>
                  _togglePlayback(isPlaying: isPlaying, canResume: canResume),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.iconColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: widget.iconColor,
                  size: 18,
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
                  final isActive = progress >= threshold;
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
            Text(
              _timeLabelForUi(),
              style: TextStyle(
                color: widget.iconColor.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
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

  Future<void> _togglePlayback({
    required bool isPlaying,
    required bool canResume,
  }) async {
    if (isPlaying) {
      try {
        await _player.pause();
      } catch (_) {
        _setPlaybackError('Unable to pause audio');
      }
      return;
    }

    if (canResume) {
      try {
        await _stopOtherPlayers();
        await _player.resume();
      } catch (_) {
        _setPlaybackError('Unable to resume audio');
      }
      return;
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

    _setPlaybackError('Audio cannot be played on this device');
  }

  String _timeLabelForUi() {
    if (_duration <= Duration.zero) {
      return '--:--';
    }
    if (_playerState == PlayerState.playing) {
      var remaining = _duration - _position;
      if (remaining < Duration.zero) {
        remaining = Duration.zero;
      }
      return _formatDuration(remaining);
    }
    return _formatDuration(_duration);
  }

  Future<void> _primeSourceDuration() async {
    if (!mounted || widget.source.isEmpty) {
      return;
    }
    if (_primedSource == widget.source) {
      return;
    }
    if (_playerState == PlayerState.playing) {
      return;
    }
    final src = widget.source;
    try {
      if (widget.preferDeviceFile) {
        final file = File(src);
        if (await file.exists()) {
          await _player.setSourceDeviceFile(file.path);
        } else {
          return;
        }
      } else {
        final uri = Uri.tryParse(src);
        final isNetwork =
            uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
        if (isNetwork) {
          await _player.setSourceUrl(src);
        } else {
          final file = File(src);
          if (await file.exists()) {
            await _player.setSourceDeviceFile(file.path);
          } else {
            return;
          }
        }
      }
      if (!mounted || widget.source != src) {
        return;
      }
      final d = await _player.getDuration();
      if (!mounted || widget.source != src) {
        return;
      }
      _primedSource = src;
      if (d != null && d > Duration.zero) {
        setState(() => _duration = d);
      }
    } catch (_) {
      // Duration will arrive from streams when playback starts.
    }
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
      await _player.resume();
      _activePlayer = _player;
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
        await _player.resume();
        _activePlayer = _player;
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
      await _player.resume();
      _activePlayer = _player;
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
      await _player.resume();
      _activePlayer = _player;
      _clearPlaybackError();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _stopOtherPlayers() async {
    final active = _activePlayer;
    if (active == null || active == _player) {
      return;
    }
    try {
      await active.stop();
    } catch (_) {}
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
