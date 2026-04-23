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
  });

  final String label;
  final String? imageUrl;
  final double size;
  final bool compact;
  final bool showOnlineIndicator;
  final bool isOnline;

  static const List<Color> _palette = [
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFF0EA5E9),
    Color(0xFF059669),
    Color(0xFFEA580C),
    Color(0xFFDB2777),
    Color(0xFF4F46E5),
  ];

  @override
  Widget build(BuildContext context) {
    final base = _pickColor(label);
    final theme = MessengerTheme.of(context);

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
        gradient: compact
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [base.withValues(alpha: 0.9), base],
              ),
        color: compact ? base.withValues(alpha: 0.85) : null,
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

    if (!showOnlineIndicator) {
      return avatar;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(
              color: isOnline ? theme.onlineIndicator : theme.offlineIndicator,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Color _pickColor(String value) {
    final sum = value.codeUnits.fold<int>(0, (prev, unit) => prev + unit);
    return _palette[sum % _palette.length];
  }
}
