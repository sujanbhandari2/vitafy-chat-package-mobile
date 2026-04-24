import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../models/messenger_message.dart';
import '../theme/messenger_theme.dart';
import 'messenger_avatar.dart';

class MessengerMessageBubble extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final bubbleColor = isMine ? theme.bubbleMine : theme.bubbleOther;
    final textColor = isMine ? theme.bubbleMineText : theme.bubbleOtherText;
    final timeColor = isMine ? theme.bubbleMineTime : theme.bubbleOtherTime;

    return Semantics(
      container: true,
      label: 'Message from ${message.senderLabel}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            MessengerAvatar(
              label: _initials(message.senderLabel),
              imageUrl: message.senderAvatarUrl,
              size: 26,
              compact: true,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showActions(context),
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                      border: isMine ? Border.all(color: theme.border) : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _MessageContent(
                          message: message,
                          textColor: textColor,
                          mutedColor: timeColor,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('h:mm a').format(message.createdAt),
                              style: TextStyle(
                                color: timeColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 4),
                              _DeliveryTick(status: message.deliveryStatus),
                            ],
                          ],
                        ),
                        if (message.isUploading ||
                            message.uploadProgress != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              value: message.uploadProgress,
                              backgroundColor: timeColor.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                timeColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: message.reactions
                          .map(
                            (reaction) {
                              final canRemove = onRemoveReaction != null &&
                                  currentUserId != null &&
                                  reaction.userId == currentUserId;
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
                                  onTap: () => onRemoveReaction!(
                                    message.id,
                                    reaction.reactionType,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  child: chip,
                                ),
                              );
                            },
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final hasAnyAction = (enableReactions && onReact != null) ||
        onMarkSeen != null ||
        onDelete != null;
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
            if (enableReactions && onReact != null)
              ...reactionOptions.map(
                (reaction) => ListTile(
                  leading: Text(reaction, style: const TextStyle(fontSize: 18)),
                  title: Text('React with $reaction'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onReact?.call(reaction);
                  },
                ),
              ),
            if (!isMine && onMarkSeen != null)
              ListTile(
                leading: const Icon(Icons.done_all_rounded),
                title: const Text('Mark as seen'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onMarkSeen?.call();
                },
              ),
            if (canDelete && onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onDelete?.call();
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

    if (message.type == MessengerMessageType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
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
        ),
      );
    }

    if (message.type == MessengerMessageType.voice) {
      return MessengerVoicePlayer(
        url: message.content,
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
}

class MessengerVoicePlayer extends StatefulWidget {
  const MessengerVoicePlayer({
    super.key,
    required this.url,
    required this.iconColor,
    required this.waveformActiveColor,
    required this.waveformInactiveColor,
  });

  final String url;
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
              _formatDuration(
                  _duration == Duration.zero ? _position : _duration),
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

    final remotePlayed = await _tryPlayFromUrl(widget.url);
    if (remotePlayed) {
      return;
    }

    final encodedPlayed = await _tryPlayFromUrl(Uri.encodeFull(widget.url));
    if (encodedPlayed) {
      return;
    }

    final localPlayed = await _tryPlayFromDownloadedFile(widget.url);
    if (localPlayed) {
      return;
    }

    _setPlaybackError('Audio cannot be played on this device');
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
