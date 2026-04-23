import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/messenger_conversation.dart';
import 'messenger_avatar.dart';
import '../theme/messenger_theme.dart';

class MessengerConversationTile extends StatelessWidget {
  const MessengerConversationTile({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
  });

  final MessengerConversation conversation;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final now = DateTime.now();
    final date = conversation.createdAt;
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final timestamp = isToday
        ? DateFormat('h:mm a').format(date)
        : DateFormat('M/d/yy').format(date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primary.withValues(alpha: 0.12)
              : theme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                MessengerAvatar(
                  label: conversation.avatarLabel,
                  imageUrl: conversation.avatarUrl,
                  compact: true,
                  size: 44,
                  showOnlineIndicator: conversation.isOnline != null,
                  isOnline: conversation.isOnline ?? false,
                ),
                if (conversation.unreadCount > 0)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: theme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          conversation.title,
                          style: TextStyle(
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timestamp,
                        style: TextStyle(
                          color: theme.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.subtitle,
                    style: TextStyle(
                      color: conversation.unreadCount > 0
                          ? const Color(0xFF374151)
                          : theme.subtleText,
                      fontSize: 12.8,
                      fontWeight: conversation.unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
