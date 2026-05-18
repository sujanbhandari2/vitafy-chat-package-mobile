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
              child: Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: labelWidget),
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
