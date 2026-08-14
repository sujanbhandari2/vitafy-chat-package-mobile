import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messenger_conversation.dart';
import '../models/messenger_inbox_people.dart';
import '../models/messenger_user.dart';
import '../theme/messenger_theme.dart';
import 'messenger_avatar.dart';
import 'messenger_conversation_list_item.dart';

/// Optional associated-people strip below the conversation thread header.
class MessengerThreadAssociatedPeoplePanel extends StatelessWidget {
  const MessengerThreadAssociatedPeoplePanel({
    super.key,
    required this.conversation,
    required this.allPeople,
    required this.currentUserId,
    this.currentPlatformUserId,
    this.openingDirectUserId = '',
    this.onOpenAssociatedPerson,
    this.sectionHeaderBuilder,
    this.itemBuilder,
    this.emptyMessage =
        'No more associated people available to start a chat with.',
  });

  final MessengerConversation? conversation;
  final List<MessengerUser> allPeople;
  final String currentUserId;
  final String? currentPlatformUserId;
  final String openingDirectUserId;
  final FutureOr<void> Function(MessengerUser user)? onOpenAssociatedPerson;
  final Widget Function(BuildContext context, int associatedPeopleCount)?
      sectionHeaderBuilder;
  final Widget Function(BuildContext context, MessengerAvailablePersonData data)?
      itemBuilder;
  final String emptyMessage;

  List<MessengerUser> get _associatedPeople =>
      messengerAssociatedPeopleForThread(
        allPeople: allPeople,
        conversation: conversation,
        currentUserId: currentUserId,
        currentPlatformUserId: currentPlatformUserId,
      );

  @override
  Widget build(BuildContext context) {
    final people = _associatedPeople;
    final theme = MessengerTheme.of(context);
    final headerBuilder = sectionHeaderBuilder;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (headerBuilder != null) ...[
              headerBuilder(context, people.length),
              const SizedBox(height: 8),
            ],
            if (people.isEmpty)
              _AssociatedPeopleEmpty(message: emptyMessage)
            else
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: people.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return _buildPersonItem(context, people[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonItem(BuildContext context, MessengerUser user) {
    final isOpening =
        openingDirectUserId.trim().isNotEmpty &&
            openingDirectUserId.trim() == user.id.trim();
    final onOpen = onOpenAssociatedPerson;
    final data = MessengerAvailablePersonData(
      user: user,
      isOpening: isOpening,
      onTap: onOpen == null
          ? () {}
          : () {
              if (isOpening) {
                return;
              }
              final result = onOpen(user);
              if (result is Future<void>) {
                unawaited(result);
              }
            },
    );

    final builder = itemBuilder;
    if (builder != null) {
      return SizedBox(width: 92, child: builder(context, data));
    }

    return _DefaultAssociatedPersonChip(data: data);
  }
}

class _DefaultAssociatedPersonChip extends StatelessWidget {
  const _DefaultAssociatedPersonChip({required this.data});

  final MessengerAvailablePersonData data;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final displayName =
        conversationListItemDisplayName(data.user.username);
    final initials = conversationListItemInitials(data.user.username);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.isOpening ? null : data.onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  MessengerAvatar(
                    label: initials,
                    imageUrl: data.user.avatarUrl,
                    compact: true,
                    size: 42,
                    showOnlineIndicator: true,
                    isOnline: data.user.isOnline,
                  ),
                  if (data.isOpening)
                    const SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.subtleText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssociatedPeopleEmpty extends StatelessWidget {
  const _AssociatedPeopleEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: theme.mutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
