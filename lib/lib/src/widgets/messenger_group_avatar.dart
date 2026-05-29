import 'package:flutter/material.dart';

import '../models/messenger_user.dart';

class MessengerGroupAvatar extends StatelessWidget {
  const MessengerGroupAvatar({
    super.key,
    required this.users,
    required this.fallbackLabel,
    this.size = 34,
  });

  final List<MessengerUser> users;
  final String fallbackLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final circleSize = size;
    final backCircleOffset = circleSize * 0.88;
    final firstUser = users.isEmpty ? null : users.first;
    final firstLabel = _firstInitial(firstUser?.username ?? fallbackLabel);
    final remainingCount = users.isEmpty ? 1 : (users.length - 1).clamp(1, 99);

    return SizedBox(
      key: const ValueKey('groupConversationAvatar'),
      width: circleSize + backCircleOffset,
      height: circleSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: backCircleOffset,
            child: _GroupAvatarCircle(
              label: '+$remainingCount',
              size: circleSize,
            ),
          ),
          _GroupAvatarCircle(
            label: firstLabel,
            imageUrl: firstUser?.avatarUrl,
            size: circleSize,
          ),
        ],
      ),
    );
  }
}

class _GroupAvatarCircle extends StatelessWidget {
  const _GroupAvatarCircle({
    required this.label,
    required this.size,
    this.imageUrl,
  });

  final String label;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      maxLines: 1,
      style: TextStyle(
        color: Colors.white,
        fontSize: size <= 34 ? 12 : 13,
        fontWeight: FontWeight.w700,
      ),
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF3F3F46),
        border: Border.all(color: Colors.white, width: 2),
      ),
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
  }
}

String _firstInitial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'G';
  }
  return trimmed[0].toUpperCase();
}
