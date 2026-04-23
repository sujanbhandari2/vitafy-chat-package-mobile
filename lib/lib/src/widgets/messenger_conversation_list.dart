import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messenger_conversation.dart';
import '../models/messenger_search_visibility.dart';
import '../models/messenger_user.dart';
import '../theme/messenger_theme.dart';
import 'messenger_avatar.dart';
import 'messenger_conversation_tile.dart';

class MessengerConversationList extends StatefulWidget {
  const MessengerConversationList({
    super.key,
    required this.currentUserName,
    required this.conversations,
    required this.users,
    required this.selectedConversationId,
    required this.openingDirectUserId,
    required this.onRefresh,
    required this.onLogout,
    required this.onOpenDirectChat,
    required this.onSelectConversation,
    this.searchVisibility = MessengerSearchVisibility.auto,
    this.searchThreshold = 10,
    this.searchHintText = 'Search',
    this.emptyUsersMessage = 'No users available right now.',
    this.emptyConversationsMessage = 'No conversations available yet.',
    this.emptyUsersBuilder,
    this.emptyConversationsBuilder,
    this.showStartChatFab = true,
    this.isMobile = false,
  });

  final String currentUserName;
  final List<MessengerConversation> conversations;
  final List<MessengerUser> users;
  final String? selectedConversationId;
  final String openingDirectUserId;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final FutureOr<void> Function(MessengerUser user) onOpenDirectChat;
  final FutureOr<void> Function(String conversationId) onSelectConversation;
  final MessengerSearchVisibility searchVisibility;
  final int searchThreshold;
  final String searchHintText;
  final String emptyUsersMessage;
  final String emptyConversationsMessage;
  final WidgetBuilder? emptyUsersBuilder;
  final WidgetBuilder? emptyConversationsBuilder;
  final bool showStartChatFab;
  final bool isMobile;

  @override
  State<MessengerConversationList> createState() =>
      _MessengerConversationListState();
}

class _MessengerConversationListState extends State<MessengerConversationList> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChange);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChange() {
    if (!mounted) {
      return;
    }
    setState(() => _query = _searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final showSearch = _shouldShowSearch();
    final filteredConversations = _filterConversations(widget.conversations);

    final listContent = Column(
      children: [
        const SizedBox(height: 2),
        Row(
          children: [
            TextButton(
              onPressed: widget.onRefresh,
              child: Text(
                'Edit',
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Expanded(
              child: Text(
                'Chats',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
            IconButton(
              onPressed: () => _openDirectPicker(context),
              icon: Icon(Icons.edit_square, color: theme.primary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Container(
        //   padding: const EdgeInsets.all(3),
        //   decoration: BoxDecoration(
        //     color: const Color(0xFFEDEDED),
        //     borderRadius: BorderRadius.circular(999),
        //   ),
        //   child: Row(
        //     children: [
        //       Expanded(
        //         child: Container(
        //           height: 30,
        //           alignment: Alignment.center,
        //           decoration: BoxDecoration(
        //             color: theme.surface,
        //             borderRadius: BorderRadius.circular(999),
        //           ),
        //           child: Text(
        //             'Contacts',
        //             style: TextStyle(
        //               color: theme.subtleText,
        //               fontSize: 12,
        //               fontWeight: FontWeight.w600,
        //             ),
        //           ),
        //         ),
        //       ),
        //       const Expanded(
        //         child: SizedBox(
        //           height: 30,
        //           child: Center(
        //             child: Text(
        //               'Everyone',
        //               style: TextStyle(
        //                 color: Color(0xFF111827),
        //                 fontSize: 12,
        //                 fontWeight: FontWeight.w700,
        //               ),
        //             ),
        //           ),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        const SizedBox(height: 10),
        if (showSearch) ...[
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: theme.searchBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: theme.mutedText, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: widget.searchHintText,
                      hintStyle: TextStyle(color: theme.mutedText),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () => _searchController.clear(),
                    child: Icon(Icons.close_rounded, color: theme.mutedText),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: filteredConversations.isEmpty
              ? _buildEmptyConversations(context)
              : ListView.separated(
                  itemCount: filteredConversations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final conversation = filteredConversations[index];

                    return MessengerConversationTile(
                      conversation: conversation,
                      isSelected:
                          conversation.id == widget.selectedConversationId,
                      onTap: () => widget.onSelectConversation(conversation.id),
                    );
                  },
                ),
        ),
        if (widget.isMobile)
          _MobileBottomBar(
            currentUserName: widget.currentUserName,
            onLogout: widget.onLogout,
          )
        else ...[
          const SizedBox(height: 8),
          Row(
            children: [
              MessengerAvatar(
                label: _initials(widget.currentUserName),
                compact: true,
                size: 30,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _displayName(widget.currentUserName),
                  style: TextStyle(
                    color: theme.subtleText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onLogout,
                child: const Text('Logout'),
              ),
            ],
          ),
        ],
      ],
    );

    final content = widget.isMobile
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: listContent,
          )
        : Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: listContent,
          );

    if (!widget.showStartChatFab) {
      return content;
    }

    return Stack(
      children: [
        content,
        Positioned(
          right: widget.isMobile ? 16 : 20,
          bottom: widget.isMobile ? 24 : 18,
          child: FloatingActionButton(
            heroTag: widget.isMobile ? 'startChatMobile' : 'startChatDesktop',
            onPressed: () => _openDirectPicker(context),
            backgroundColor: theme.primary,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _openDirectPicker(BuildContext context) async {
    final sortedUsers = [...widget.users]..sort((a, b) {
        if (a.isOnline == b.isOnline) {
          return a.username.toLowerCase().compareTo(b.username.toLowerCase());
        }
        return a.isOnline ? -1 : 1;
      });

    String query = '';
    final searchController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setState) {
          final filteredUsers = query.isEmpty
              ? sortedUsers
              : sortedUsers
                  .where(
                    (user) =>
                        user.username.toLowerCase().contains(query) ||
                        user.roleLabel.toLowerCase().contains(query),
                  )
                  .toList(growable: false);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start New Chat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: MessengerTheme.of(context).searchBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: MessengerTheme.of(context).mutedText,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: (value) => setState(() {
                              query = value.trim().toLowerCase();
                            }),
                            decoration: InputDecoration(
                              hintText: widget.searchHintText,
                              hintStyle: TextStyle(
                                color: MessengerTheme.of(context).mutedText,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              searchController.clear();
                              setState(() => query = '');
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: MessengerTheme.of(context).mutedText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (filteredUsers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: widget.emptyUsersBuilder?.call(sheetContext) ??
                          Text(
                            widget.emptyUsersMessage,
                            style: TextStyle(
                              color: MessengerTheme.of(context).subtleText,
                            ),
                          ),
                    )
                  else
                    ...filteredUsers.map(
                      (user) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DirectUserTile(
                          user: user,
                          isOpening: widget.openingDirectUserId == user.id,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            widget.onOpenDirectChat(user);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _shouldShowSearch() {
    switch (widget.searchVisibility) {
      case MessengerSearchVisibility.always:
        return true;
      case MessengerSearchVisibility.never:
        return false;
      case MessengerSearchVisibility.auto:
        return widget.users.length > widget.searchThreshold;
    }
  }

  List<MessengerConversation> _filterConversations(
    List<MessengerConversation> conversations,
  ) {
    if (_query.isEmpty) {
      return conversations;
    }
    final queryLower = _query.toLowerCase();
    return conversations
        .where(
          (conversation) =>
              conversation.title.toLowerCase().contains(queryLower) ||
              conversation.subtitle.toLowerCase().contains(queryLower),
        )
        .toList(growable: false);
  }

  Widget _buildEmptyConversations(BuildContext context) {
    if (widget.emptyConversationsBuilder != null) {
      return widget.emptyConversationsBuilder!(context);
    }
    return Center(
      child: Text(
        widget.emptyConversationsMessage,
        style: TextStyle(
          color: MessengerTheme.of(context).subtleText,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DirectUserTile extends StatelessWidget {
  const _DirectUserTile({
    required this.user,
    required this.isOpening,
    required this.onTap,
  });

  final MessengerUser user;
  final bool isOpening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          MessengerAvatar(
            label: _initials(user.username),
            imageUrl: user.avatarUrl,
            compact: true,
            size: 34,
            showOnlineIndicator: true,
            isOnline: user.isOnline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName(user.username),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${user.roleLabel}${user.roleLabel.isNotEmpty ? ' • ' : ''}${user.isOnline ? 'Online' : 'Offline'}',
                  style: TextStyle(
                    color: theme.subtleText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: isOpening ? null : onTap,
            style: FilledButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(isOpening ? '...' : 'Chat'),
          ),
        ],
      ),
    );
  }
}

class _MobileBottomBar extends StatelessWidget {
  const _MobileBottomBar({
    required this.currentUserName,
    required this.onLogout,
  });

  final String currentUserName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Icon(Icons.chat_bubble, color: theme.primary, size: 22),
          ),
          Expanded(
            child:
                Icon(Icons.groups_outlined, color: theme.mutedText, size: 23),
          ),
          Expanded(
            child: MessengerAvatar(
              label: _initials(currentUserName),
              compact: true,
              size: 24,
            ),
          ),
          Expanded(
            child: IconButton(
              onPressed: onLogout,
              icon: Icon(Icons.logout_rounded, color: theme.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}

String _displayName(String username) {
  return username
      .split(RegExp(r'[_-]'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _initials(String username) {
  final chunks = _displayName(
    username,
  ).split(' ').where((part) => part.isNotEmpty).toList();
  if (chunks.isEmpty) {
    return 'U';
  }

  final first = chunks.first[0];
  final second = chunks.length > 1
      ? chunks[1][0]
      : (chunks.first.length > 1 ? chunks.first[1] : '');
  return '$first$second';
}
