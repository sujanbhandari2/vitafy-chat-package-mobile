import 'package:flutter/material.dart';

import '../theme/messenger_theme.dart';

class MessengerAvatar extends StatelessWidget {
  const MessengerAvatar({
    super.key,
    required this.label,
    this.imageUrl,
    this.size = 42,
    this.compact = false,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.presenceDotColor,
    this.showUnreadIndicator = false,
    this.unreadIndicatorColor,
  });

  final String label;
  final String? imageUrl;
  final double size;
  final bool compact;
  final bool showOnlineIndicator;
  final bool isOnline;

  /// When set, used for the bottom-right dot instead of [isOnline] /
  /// [MessengerThemeData.onlineIndicator] vs [MessengerThemeData.offlineIndicator].
  final Color? presenceDotColor;

  /// Unread badge (top-right), separate from online presence (bottom-right).
  final bool showUnreadIndicator;
  final Color? unreadIndicatorColor;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final base = theme.primary;

    final labelWidget = Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: compact ? 12.5 : 14,
      ),
    );

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: compact ? base.withValues(alpha: 0.9) : base,
      ),
      alignment: Alignment.center,
      child: imageUrl == null
          ? labelWidget
          : ClipOval(
              child: _DecodedNetworkAvatar(
                imageUrl: imageUrl!,
                size: size,
                fallback: Center(child: labelWidget),
              ),
            ),
    );

    if (!showOnlineIndicator && !showUnreadIndicator) {
      return avatar;
    }

    final onlineDotColor = presenceDotColor ??
        (isOnline ? theme.onlineIndicator : theme.offlineIndicator);
    final unreadDotColor = unreadIndicatorColor ?? theme.primary;
    final dotSize = size * 0.26;

    Widget dot(Color color) {
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (showUnreadIndicator)
          Positioned(
            right: -1,
            top: -1,
            child: dot(unreadDotColor),
          ),
        if (showOnlineIndicator)
          Positioned(
            right: -1,
            bottom: -1,
            child: dot(onlineDotColor),
          ),
      ],
    );
  }
}

/// Loads a remote avatar at display size so large originals are not fully
/// decoded into memory for a small circular chip.
class _DecodedNetworkAvatar extends StatelessWidget {
  const _DecodedNetworkAvatar({
    required this.imageUrl,
    required this.size,
    required this.fallback,
  });

  final String imageUrl;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final pixelSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Image.network(
      imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      // Decode near display resolution — avoids multi-megapixel bitmaps for
      // 26–48px chips and cuts perceived load/hang time after download.
      cacheWidth: pixelSize,
      cacheHeight: pixelSize,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return fallback;
      },
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
