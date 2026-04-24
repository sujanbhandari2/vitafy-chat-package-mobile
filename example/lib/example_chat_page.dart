import 'dart:async';

import 'package:flutter/material.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

import 'example_models.dart';

class ExampleChatPage extends StatefulWidget {
  const ExampleChatPage({
    super.key,
    this.initialData = const ExampleBootstrapFormData.initial(),
  });

  final ExampleBootstrapFormData initialData;

  @override
  State<ExampleChatPage> createState() => _ExampleChatPageState();
}

class _ExampleChatPageState extends State<ExampleChatPage> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();

  StreamSubscription<ChatSocketEvent>? _socketSubscription;
  ChatSession? _session;
  ChatClient? get _client => _session?.client;
  ChatAuth? _apiAuth;
  ChatAuth? _sessionAuth;
  ChatTenantScope? _tenantScope;
  TenantUser? _currentUser;

  List<TenantUser> _users = const [];
  List<Conversation> _conversations = const [];
  final Map<String, List<ChatMessage>> _messagesByConversation = {};
  final Map<String, int> _unreadByConversation = {};
  final Map<String, Set<String>> _typingUserIdsByConversation = {};

  String? _selectedConversationId;
  String _statusText = 'Bootstrapping package flow...';
  bool _isBootstrapping = false;
  bool _isSocketConnected = false;
  bool _isRefreshing = false;
  bool _isSending = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapPackageFlow());
  }

  @override
  void dispose() {
    _composerController.dispose();
    _messagesScrollController.dispose();
    unawaited(_disposeActiveClient());
    super.dispose();
  }

  List<MessengerChatMessage> get _activeMessages {
    final conversationId = _selectedConversationId;
    if (conversationId == null) {
      return const [];
    }
    final source = _messagesByConversation[conversationId] ?? const [];
    return source.map(_mapMessage).toList();
  }

  List<MessengerConversation> get _uiConversations {
    return _conversations.map(_mapConversation).toList();
  }

  List<MessengerUser> get _uiUsers {
    final currentUserId = _currentUser?.id;
    return _users
        .where((user) => user.id != currentUserId)
        .map(_mapUser)
        .toList();
  }

  Future<bool> _ensureSocketConnected() async {
    final client = _client;
    final sessionAuth = _sessionAuth;
    if (client == null || sessionAuth == null) {
      return false;
    }
    if (_isSocketConnected) {
      return true;
    }

    if (mounted) {
      setState(() {
        _statusText = 'Reconnecting socket...';
      });
    }

    try {
      await _session!.reconnectSocket();
      if (!mounted) {
        return true;
      }
      setState(() {
        _isSocketConnected = true;
        _statusText = 'Socket reconnected.';
      });
      return true;
    } catch (error, stackTrace) {
      _appendLog(
        'Socket reconnect failed',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      if (!mounted) {
        return false;
      }
      setState(() {
        _isSocketConnected = false;
        _statusText = 'Socket reconnect failed: $error';
      });
      _showSnack('Socket is not connected. Check socket URL and try again.');
      return false;
    }
  }

  Future<void> _bootstrapPackageFlow() async {
    final initialData = widget.initialData;
    final apiBaseUrl = initialData.apiBaseUrl.trim();
    final socketUrl = initialData.socketUrl.trim();
    final apiKey = initialData.apiKey.trim();
    final providerId = initialData.providerId.trim();
    final providerUserId = initialData.providerUserId.trim();
    final email = initialData.email.trim();
    final name = initialData.name.trim();

    if (apiBaseUrl.isEmpty ||
        socketUrl.isEmpty ||
        apiKey.isEmpty ||
        providerId.isEmpty ||
        providerUserId.isEmpty ||
        email.isEmpty) {
      setState(() {
        _statusText = 'Bootstrap config is incomplete.';
      });
      _appendLog('Bootstrap skipped: missing required configuration');
      return;
    }

    setState(() {
      _isBootstrapping = true;
      _statusText = 'Bootstrapping package flow...';
    });
    _appendLog('Starting package flow bootstrap');

    await _disposeActiveClient();

    ChatSession? bootstrappingSession;
    try {
      final session = ChatSession(
        config: ChatServiceConfig(
          apiBaseUrl: apiBaseUrl,
          socketUrl: socketUrl,
          socketTransports: const ['websocket'],
          apiLogger: (message, {data}) =>
              _appendLog('API $message', data: data),
          socketLogger: (message, {data}) =>
              _appendLog('SOCKET $message', data: data),
        ),
      );
      bootstrappingSession = session;

      final apiAuth = ChatAuth(apiKey: apiKey);
      final bootstrapResult = await session.bootstrap(
        apiAuth: apiAuth,
        providerId: providerId,
        providerUserId: providerUserId,
        email: email,
        name: name.isEmpty ? null : name,
      );
      final tenantScope = session.tenantScope!;
      final registeredUser = session.currentUser!;
      final sessionAuth = session.sessionAuth!;

      if (!mounted) {
        await session.dispose();
        return;
      }

      _listenToSocketEvents(session.client);
      setState(() {
        _session = session;
        _apiAuth = apiAuth;
        _sessionAuth = sessionAuth;
        _tenantScope = tenantScope;
        _currentUser = registeredUser;
        _isSocketConnected = false;
        _messagesByConversation.clear();
        _unreadByConversation.clear();
        _typingUserIdsByConversation.clear();
        _selectedConversationId = null;
      });
      bootstrappingSession = null;

      final socketConnected = bootstrapResult.socketConnected;
      if (!socketConnected && bootstrapResult.connectError != null) {
        _appendLog(
          'Socket connect failed, continuing in REST-only mode',
          data: {'error': bootstrapResult.connectError.toString()},
        );
      }

      if (mounted) {
        setState(() {
          _isSocketConnected = socketConnected;
        });
      }

      await _refreshAll(selectFirstConversation: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = socketConnected
            ? 'Connected as ${registeredUser.displayName} in tenant ${tenantScope.tenantId}.'
            : 'Connected to tenant data as ${registeredUser.displayName} (read-only until socket reconnects).';
      });
      _appendLog(
        'Bootstrap complete',
        data: {
          'tenantId': tenantScope.tenantId,
          'chatUserId': registeredUser.id,
        },
      );
    } catch (error, stackTrace) {
      _appendLog(
        'Bootstrap failed',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Bootstrap failed: $error';
        _isSocketConnected = false;
      });
      _showSnack('Bootstrap failed. Check console logs for details.');
    } finally {
      if (bootstrappingSession != null) {
        await bootstrappingSession.dispose();
      }
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }
    }
  }

  Future<void> _refreshAll({bool selectFirstConversation = false}) async {
    if (_client == null || _apiAuth == null) {
      return;
    }

    setState(() {
      _isRefreshing = true;
      _statusText = 'Refreshing package data...';
    });

    try {
      await _refreshUsers();
      await _refreshConversations();

      final selectedConversationId = _selectedConversationId;
      if (selectedConversationId != null) {
        await _loadMessages(selectedConversationId);
      } else if (selectFirstConversation && _conversations.isNotEmpty) {
        await _selectConversation(_conversations.first.id, tryReconnect: false);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = _isSocketConnected
            ? 'Data refreshed from the package client.'
            : 'Data refreshed (REST-only, socket disconnected).';
      });
    } catch (error, stackTrace) {
      _appendLog(
        'Refresh failed',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = 'Refresh failed: $error';
      });
      _showSnack('Refresh failed.');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refreshUsers() async {
    final client = _client;
    final auth = _apiAuth;
    if (client == null || auth == null) {
      return;
    }

    final users = await client.getUsers(auth);
    if (!mounted) {
      return;
    }

    final selectedCurrentUser =
        users.where((user) => user.id == _currentUser?.id).firstOrNull;

    setState(() {
      _users = users;
      _currentUser = selectedCurrentUser ?? _currentUser ?? users.firstOrNull;
    });
  }

  Future<void> _refreshConversations() async {
    final client = _client;
    final auth = _apiAuth;
    final currentUser = _currentUser;
    if (client == null || auth == null || currentUser == null) {
      return;
    }

    final conversations = await client.getConversations(
      auth,
      forUserId: currentUser.id,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _conversations = conversations;
      if (_selectedConversationId != null &&
          !_conversations.any(
            (conversation) => conversation.id == _selectedConversationId,
          )) {
        _selectedConversationId = null;
      }
    });
  }

  Future<void> _selectConversation(
    String conversationId, {
    bool tryReconnect = true,
  }) async {
    final session = _session;
    final client = _client;
    if (session == null || client == null) {
      return;
    }

    final previousConversationId = _selectedConversationId;
    if (previousConversationId != null &&
        previousConversationId != conversationId) {
      try {
        await session.leaveConversation(previousConversationId);
      } catch (error) {
        _appendLog(
          'Leave conversation failed',
          data: {
            'conversationId': previousConversationId,
            'error': error.toString(),
          },
        );
      }
    }

    setState(() {
      _selectedConversationId = conversationId;
      _unreadByConversation.remove(conversationId);
      _statusText = 'Loading conversation $conversationId...';
    });

    try {
      await _loadMessages(conversationId);

      var connected = _isSocketConnected;
      if (!connected && tryReconnect) {
        connected = await _ensureSocketConnected();
      }
      if (!connected) {
        if (mounted) {
          setState(() {
            _statusText =
                'Opened conversation $conversationId (REST-only, socket disconnected).';
          });
        }
        return;
      }

      await session.joinConversation(conversationId);

      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Joined conversation $conversationId.';
      });
      await _markVisibleMessagesAsRead(conversationId);
    } catch (error, stackTrace) {
      _appendLog(
        'Select conversation failed',
        data: {
          'conversationId': conversationId,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = 'Could not open conversation: $error';
      });
      _showSnack('Could not open conversation.');
    }
  }

  Future<void> _loadMessages(String conversationId) async {
    final client = _client;
    final auth = _apiAuth;
    if (client == null || auth == null) {
      return;
    }

    final page = await client.getMessages(auth, conversationId);
    final items = [...page.items]
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));

    if (!mounted) {
      return;
    }

    setState(() {
      _messagesByConversation[conversationId] = items;
    });
    _scrollToBottom();
  }

  Future<void> _openDirectChat(MessengerUser user) async {
    final client = _client;
    final auth = _apiAuth;
    final currentUser = _currentUser;
    if (client == null || auth == null || currentUser == null) {
      _showSnack('Bootstrap the package flow first.');
      return;
    }

    final existing = _findDirectConversation(currentUser.id, user.id);
    if (existing != null) {
      await _selectConversation(existing.id);
      return;
    }

    try {
      setState(() {
        _statusText = 'Creating direct conversation with ${user.username}...';
      });

      final created = await client.createConversation(
        auth,
        type: 'DIRECT',
        participantIds: [currentUser.id, user.id],
      );

      await _refreshConversations();
      await _selectConversation(created.id);
    } catch (error, stackTrace) {
      _appendLog(
        'Create direct conversation failed',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      _showSnack('Could not create direct conversation.');
    }
  }

  Future<void> _sendMessage() async {
    final client = _client;
    final conversationId = _selectedConversationId;
    final text = _composerController.text.trim();
    if (client == null || conversationId == null || text.isEmpty) {
      return;
    }

    final connected = await _ensureSocketConnected();
    if (!connected) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final created = await client.sendMessage(
        conversationId: conversationId,
        type: MessageType.text,
        content: text,
      );
      _composerController.clear();
      _upsertMessage(conversationId, created);
      _scrollToBottom();

      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Message sent through the socket flow.';
      });
    } catch (error, stackTrace) {
      _appendLog(
        'Send message failed',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      _showSnack('Could not send the message.');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _reactToMessage(String messageId, String reactionType) async {
    final client = _client;
    final conversationId = _selectedConversationId;
    if (client == null || conversationId == null) {
      return;
    }

    try {
      final reaction = await client.reactToMessage(
        conversationId: conversationId,
        messageId: messageId,
        reactionType: reactionType,
      );
      _applyReaction(conversationId, reaction);
    } catch (error, stackTrace) {
      _appendLog(
        'Add reaction failed',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      _showSnack('Could not add the reaction.');
    }
  }

  Future<void> _removeReactionFromMessage(
    String messageId,
    String reactionType,
  ) async {
    final client = _client;
    final conversationId = _selectedConversationId;
    final currentUser = _currentUser;
    if (client == null || conversationId == null || currentUser == null) {
      return;
    }

    try {
      final removed = await client.removeReaction(
        conversationId: conversationId,
        messageId: messageId,
      );
      if (removed) {
        _applyReactionRemoval(
          conversationId,
          RemovedReactionEvent(
            messageId: messageId,
            conversationId: conversationId,
            userId: currentUser.id,
          ),
        );
      } else {
        _showSnack('No reaction was removed.');
      }
    } catch (error, stackTrace) {
      _appendLog(
        'Remove reaction failed',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      _showSnack('Could not remove the reaction.');
    }
  }

  Future<void> _markSeen(String messageId) async {
    final client = _client;
    final conversationId = _selectedConversationId;
    if (client == null || conversationId == null || !_isSocketConnected) {
      return;
    }

    try {
      final delivered = await client.markAsDelivered(
        conversationId: conversationId,
        messageId: messageId,
      );
      final read = await client.markAsRead(
        conversationId: conversationId,
        messageId: messageId,
      );
      _applyDeliveredReceipt(conversationId, delivered);
      _applyReadReceipt(conversationId, read);
    } catch (error, stackTrace) {
      _appendLog(
        'Mark read failed',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
    }
  }

  Future<void> _markVisibleMessagesAsRead(String conversationId) async {
    final currentUserId = _currentUser?.id;
    if (currentUserId == null) {
      return;
    }

    final messages = _messagesByConversation[conversationId] ?? const [];
    for (final message
        in messages.where((item) => item.senderId != currentUserId)) {
      await _markSeen(message.id);
    }
  }

  Future<void> _logoutToConfiguration() async {
    await _disposeActiveClient();
    if (!mounted) {
      return;
    }

    setState(() {
      _apiAuth = null;
      _sessionAuth = null;
      _tenantScope = null;
      _currentUser = null;
      _isSocketConnected = false;
      _users = const [];
      _conversations = const [];
      _messagesByConversation.clear();
      _unreadByConversation.clear();
      _typingUserIdsByConversation.clear();
      _selectedConversationId = null;
      _statusText = 'Logged out.';
    });
    _appendLog('Disconnected client session, returning to configuration');

    Navigator.of(context).pop(true);
  }

  Future<void> _disposeActiveClient() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    final session = _session;
    _session = null;
    _isSocketConnected = false;
    if (session != null) {
      await session.dispose();
    }
  }

  void _listenToSocketEvents(ChatClient client) {
    _socketSubscription?.cancel();
    _socketSubscription = client.events.listen(
      _handleSocketEvent,
      onError: (Object error, StackTrace stackTrace) {
        _appendLog(
          'Socket stream error',
          data: {
            'error': error.toString(),
            'stackTrace': stackTrace.toString(),
          },
        );
      },
    );
  }

  void _handleSocketEvent(ChatSocketEvent event) {
    if (!mounted) {
      return;
    }

    switch (event.type) {
      case ChatSocketEventType.connected:
        setState(() {
          _isSocketConnected = true;
          _statusText = 'Socket connected.';
        });
        break;
      case ChatSocketEventType.disconnected:
        setState(() {
          _isSocketConnected = false;
          _statusText = 'Socket disconnected.';
        });
        break;
      case ChatSocketEventType.error:
        setState(() {
          _isSocketConnected = false;
          _statusText = event.error ?? 'Socket error';
        });
        break;
      case ChatSocketEventType.messageReceived:
        final message = event.message;
        if (message != null) {
          _upsertMessage(message.conversationId, message);
          if (_selectedConversationId == message.conversationId &&
              message.senderId != _currentUser?.id) {
            unawaited(_markSeen(message.id));
          }
        }
        break;
      case ChatSocketEventType.messageReacted:
        final reaction = event.reaction;
        if (reaction != null && reaction.conversationId != null) {
          _applyReaction(reaction.conversationId!, reaction);
        }
        break;
      case ChatSocketEventType.reactionRemoved:
        final removedReaction = event.removedReaction;
        if (removedReaction != null) {
          _applyReactionRemoval(
            removedReaction.conversationId,
            removedReaction,
          );
        }
        break;
      case ChatSocketEventType.messageDelivered:
        final delivered = event.delivered;
        if (delivered != null && delivered.conversationId != null) {
          _applyDeliveredReceipt(delivered.conversationId!, delivered);
        }
        break;
      case ChatSocketEventType.messageRead:
        final receipt = event.receipt;
        if (receipt != null && receipt.conversationId != null) {
          _applyReadReceipt(receipt.conversationId!, receipt);
        }
        break;
      case ChatSocketEventType.userTyping:
        final typing = event.typing;
        if (typing != null &&
            typing.userId.isNotEmpty &&
            typing.conversationId.isNotEmpty) {
          setState(() {
            final set = _typingUserIdsByConversation.putIfAbsent(
              typing.conversationId,
              () => <String>{},
            );
            set.add(typing.userId);
          });
        }
        break;
      case ChatSocketEventType.userStoppedTyping:
        final typing = event.typing;
        if (typing != null &&
            typing.userId.isNotEmpty &&
            typing.conversationId.isNotEmpty) {
          setState(() {
            final set = _typingUserIdsByConversation[typing.conversationId];
            set?.remove(typing.userId);
          });
        }
        break;
      case ChatSocketEventType.userOnline:
        final presence = event.presence;
        if (presence != null) {
          _applyPresenceUpdate(presence.userId, true);
        }
        break;
      case ChatSocketEventType.userOffline:
        final presence = event.presence;
        if (presence != null) {
          _applyPresenceUpdate(presence.userId, false);
        }
        break;
    }
  }

  void _upsertMessage(String conversationId, ChatMessage message) {
    final existing = _messagesByConversation[conversationId] ?? const [];
    final next = List<ChatMessage>.from(existing);
    final index = next.indexWhere((item) => item.id == message.id);
    if (index == -1) {
      next.add(message);
    } else {
      next[index] = message;
    }
    next.sort((left, right) => left.createdAt.compareTo(right.createdAt));

    if (!mounted) {
      return;
    }

    setState(() {
      _messagesByConversation[conversationId] = next;
      if (_selectedConversationId != conversationId &&
          message.senderId != _currentUser?.id) {
        _unreadByConversation.update(
          conversationId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    });

    if (_selectedConversationId == conversationId) {
      _scrollToBottom();
    }
  }

  void _applyReaction(String conversationId, MessageReaction reaction) {
    final messages = _messagesByConversation[conversationId];
    if (messages == null) {
      return;
    }

    final index = messages.indexWhere((item) => item.id == reaction.messageId);
    if (index == -1) {
      return;
    }

    final target = messages[index];
    final nextReactions = List<MessageReaction>.from(target.reactions)
      ..removeWhere((item) => item.userId == reaction.userId)
      ..add(reaction);

    final nextMessages = List<ChatMessage>.from(messages);
    nextMessages[index] = target.copyWith(reactions: nextReactions);

    setState(() {
      _messagesByConversation[conversationId] = nextMessages;
    });
  }

  void _applyReactionRemoval(
    String conversationId,
    RemovedReactionEvent event,
  ) {
    final messages = _messagesByConversation[conversationId];
    if (messages == null) {
      return;
    }

    final index = messages.indexWhere((item) => item.id == event.messageId);
    if (index == -1) {
      return;
    }

    final target = messages[index];
    final nextReactions = List<MessageReaction>.from(target.reactions)
      ..removeWhere((item) => item.userId == event.userId);

    final nextMessages = List<ChatMessage>.from(messages);
    nextMessages[index] = target.copyWith(reactions: nextReactions);

    setState(() {
      _messagesByConversation[conversationId] = nextMessages;
    });
  }

  void _applyDeliveredReceipt(String conversationId, DeliveredReceipt receipt) {
    final messages = _messagesByConversation[conversationId];
    if (messages == null) {
      return;
    }

    final index = messages.indexWhere((item) => item.id == receipt.messageId);
    if (index == -1) {
      return;
    }

    final target = messages[index];
    final nextReceipts = List<DeliveredReceipt>.from(target.deliveredReceipts)
      ..removeWhere((item) => item.userId == receipt.userId)
      ..add(receipt);

    final nextMessages = List<ChatMessage>.from(messages);
    nextMessages[index] = target.copyWith(deliveredReceipts: nextReceipts);

    setState(() {
      _messagesByConversation[conversationId] = nextMessages;
    });
  }

  void _applyReadReceipt(String conversationId, ReadReceipt receipt) {
    final messages = _messagesByConversation[conversationId];
    if (messages == null) {
      return;
    }

    final index = messages.indexWhere((item) => item.id == receipt.messageId);
    if (index == -1) {
      return;
    }

    final target = messages[index];
    final nextReceipts = List<ReadReceipt>.from(target.readReceipts)
      ..removeWhere((item) => item.userId == receipt.userId)
      ..add(receipt);

    final nextMessages = List<ChatMessage>.from(messages);
    nextMessages[index] = target.copyWith(readReceipts: nextReceipts);

    setState(() {
      _messagesByConversation[conversationId] = nextMessages;
    });
  }

  void _applyPresenceUpdate(String userId, bool isOnline) {
    setState(() {
      _users = _users
          .map(
            (user) => user.id == userId
                ? TenantUser(
                    id: user.id,
                    tenantId: user.tenantId,
                    name: user.name,
                    email: user.email,
                    role: user.role,
                    isOnline: isOnline,
                    createdAt: user.createdAt,
                    avatarUrl: user.avatarUrl,
                    status: user.status,
                  )
                : user,
          )
          .toList();

      _conversations = _conversations
          .map(
            (conversation) => Conversation(
              id: conversation.id,
              tenantId: conversation.tenantId,
              type: conversation.type,
              title: conversation.title,
              createdBy: conversation.createdBy,
              createdAt: conversation.createdAt,
              updatedAt: conversation.updatedAt,
              participants: conversation.participants
                  .map(
                    (participant) => participant.user.id == userId
                        ? ConversationParticipant(
                            id: participant.id,
                            userId: participant.userId,
                            conversationId: participant.conversationId,
                            user: ConversationParticipantUser(
                              id: participant.user.id,
                              username: participant.user.username,
                              role: participant.user.role,
                              email: participant.user.email,
                              avatarUrl: participant.user.avatarUrl,
                              status: participant.user.status,
                              isOnline: isOnline,
                            ),
                          )
                        : participant,
                  )
                  .toList(),
            ),
          )
          .toList();
    });
  }

  Conversation? _findDirectConversation(
    String currentUserId,
    String otherUserId,
  ) {
    for (final conversation in _conversations) {
      if (conversation.type.toUpperCase() != 'DIRECT') {
        continue;
      }
      final ids = conversation.participants.map((item) => item.user.id).toSet();
      if (ids.contains(currentUserId) && ids.contains(otherUserId)) {
        return conversation;
      }
    }
    return null;
  }

  MessengerUser _mapUser(TenantUser user) {
    return MessengerUser(
      id: user.id,
      username: user.displayName,
      roleLabel: user.role.label,
      isOnline: user.isOnline,
      avatarUrl: user.avatarUrl,
    );
  }

  MessengerConversation _mapConversation(Conversation conversation) {
    final title = _conversationTitle(conversation);
    final messages = _messagesByConversation[conversation.id] ?? const [];
    final latestMessage = messages.isEmpty ? null : messages.last;
    final subtitle = latestMessage == null
        ? '${conversation.type} conversation'
        : _messagePreview(latestMessage);
    final others = conversation.participants
        .where((participant) => participant.user.id != _currentUser?.id)
        .toList();

    return MessengerConversation(
      id: conversation.id,
      title: title,
      subtitle: subtitle,
      avatarLabel: _initials(title),
      createdAt: conversation.updatedAt,
      isGlobal: conversation.isGlobal,
      unreadCount: _unreadByConversation[conversation.id] ?? 0,
      avatarUrl: others.length == 1 ? others.first.user.avatarUrl : null,
      isOnline: others.any((participant) => participant.user.isOnline),
    );
  }

  MessengerChatMessage _mapMessage(ChatMessage message) {
    return MessengerChatMessage(
      id: message.id,
      senderId: message.senderId,
      senderLabel: _senderName(message),
      type: _mapUiMessageType(message.type),
      content: _messagePreview(message),
      createdAt: message.createdAt,
      deliveryStatus: _deliveryStatusFor(message),
      reactions: message.reactions
          .map(
            (reaction) => MessengerMessageReaction(
              userId: reaction.userId,
              reactionType: reaction.reactionType,
            ),
          )
          .toList(),
      senderAvatarUrl: _avatarForUser(message.senderId),
    );
  }

  String _conversationTitle(Conversation conversation) {
    final explicitTitle = conversation.title?.trim() ?? '';
    if (explicitTitle.isNotEmpty) {
      return explicitTitle;
    }

    final others = conversation.participants
        .where((participant) => participant.user.id != _currentUser?.id)
        .map((participant) => participant.user.username)
        .where((name) => name.trim().isNotEmpty)
        .toList();

    if (others.isNotEmpty) {
      return others.join(', ');
    }

    return conversation.type.toUpperCase();
  }

  MessengerMessageType _mapUiMessageType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return MessengerMessageType.image;
      case MessageType.voice:
        return MessengerMessageType.voice;
      case MessageType.text:
      case MessageType.video:
      case MessageType.file:
      case MessageType.link:
      case MessageType.other:
        return MessengerMessageType.text;
    }
  }

  MessengerDeliveryStatus _deliveryStatusFor(ChatMessage message) {
    if (message.senderId != _currentUser?.id) {
      return MessengerDeliveryStatus.none;
    }
    if (message.readReceipts.isNotEmpty) {
      return MessengerDeliveryStatus.seen;
    }
    if (message.deliveredReceipts.isNotEmpty) {
      return MessengerDeliveryStatus.delivered;
    }
    return MessengerDeliveryStatus.sent;
  }

  String _messagePreview(ChatMessage message) {
    final content = message.content.trim();
    if (content.isNotEmpty) {
      return content;
    }
    if (message.attachments.isNotEmpty) {
      switch (message.type) {
        case MessageType.image:
          return '[Image attachment]';
        case MessageType.voice:
          return '[Voice attachment]';
        case MessageType.video:
          return '[Video attachment]';
        case MessageType.file:
          return '[File attachment]';
        case MessageType.link:
          return '[Link attachment]';
        case MessageType.other:
        case MessageType.text:
          return '[Attachment]';
      }
    }
    return '[Empty message]';
  }

  String _senderName(ChatMessage message) {
    final senderName = message.sender?.name?.trim() ?? '';
    if (senderName.isNotEmpty) {
      return senderName;
    }

    final user =
        _users.where((item) => item.id == message.senderId).firstOrNull;
    if (user != null) {
      return user.displayName;
    }

    for (final conversation in _conversations) {
      final participant = conversation.participants
          .where((item) => item.user.id == message.senderId)
          .firstOrNull;
      if (participant != null) {
        return participant.user.username;
      }
    }

    return message.senderId == _currentUser?.id ? 'You' : 'Unknown user';
  }

  String? _avatarForUser(String userId) {
    final user = _users.where((item) => item.id == userId).firstOrNull;
    return user?.avatarUrl;
  }

  String _nameForUser(String userId) {
    return _users.where((item) => item.id == userId).firstOrNull?.displayName ??
        userId;
  }

  List<MessengerTypingUser> _remoteTypingUsersForShell() {
    final conversationId = _selectedConversationId;
    if (conversationId == null) {
      return const [];
    }
    final ids = _typingUserIdsByConversation[conversationId];
    if (ids == null || ids.isEmpty) {
      return const [];
    }
    return ids
        .map(
          (id) => MessengerTypingUser(
            userId: id,
            displayLabel: _nameForUser(id),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _onTypingStart(String conversationId) async {
    if (!_isSocketConnected || _client == null) {
      return;
    }
    try {
      await _client!.startTyping(conversationId);
    } catch (_) {}
  }

  Future<void> _onTypingStop(String conversationId) async {
    if (!_isSocketConnected || _client == null) {
      return;
    }
    try {
      await _client!.stopTyping(conversationId);
    } catch (_) {}
  }

  String _initials(String text) {
    final parts = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'CH';
    }
    if (parts.length == 1) {
      final part = parts.first;
      return part.substring(0, part.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  void _appendLog(String message, {Object? data}) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final suffix = data == null ? '' : ' :: $data';
    debugPrint('[$hh:$mm:$ss] $message$suffix');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScrollController.hasClients) {
        return;
      }
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  bool _canDeleteMessage(MessengerChatMessage _) => false;

  @override
  Widget build(BuildContext context) {
    final currentUserName = _currentUser?.displayName ?? 'Example user';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messenger Chat'),
        actions: [
          IconButton(
            onPressed: _isRefreshing || _isBootstrapping
                ? null
                : () {
                    if (_client == null) {
                      unawaited(_bootstrapPackageFlow());
                      return;
                    }
                    unawaited(_refreshAll());
                    if (!_isSocketConnected) {
                      unawaited(_ensureSocketConnected());
                    }
                  },
            tooltip: _client == null ? 'Connect' : 'Refresh',
            icon: Icon(
              _client == null ? Icons.play_arrow_rounded : Icons.sync_rounded,
            ),
          ),
          IconButton(
            onPressed: _client == null || _isBootstrapping
                ? null
                : () => unawaited(_logoutToConfiguration()),
            tooltip: 'Disconnect',
            icon: const Icon(Icons.link_off_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Container(
            //   width: double.infinity,
            //   padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            //   decoration: const BoxDecoration(
            //     gradient: LinearGradient(
            //       colors: [Color(0xFFF0F7F5), Color(0xFFFFFFFF)],
            //       begin: Alignment.topLeft,
            //       end: Alignment.bottomRight,
            //     ),
            //   ),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Wrap(
            //         spacing: 8,
            //         runSpacing: 8,
            //         children: [
            //           _statusChip(
            //             'Tenant',
            //             _tenantScope?.tenantId ?? 'pending',
            //           ),
            //           _statusChip(
            //             'Chat user',
            //             _currentUser?.id ?? 'pending',
            //           ),
            //           _statusChip(
            //             'Socket',
            //             _sessionAuth == null
            //                 ? 'pending'
            //                 : (_isSocketConnected
            //                     ? 'connected'
            //                     : 'disconnected'),
            //           ),
            //           _statusChip(
            //             'Conversations',
            //             '${_conversations.length}',
            //           ),
            //           _statusChip(
            //             'Users',
            //             '${_uiUsers.length}',
            //           ),
            //         ],
            //       ),
            //       const SizedBox(height: 10),
            //       Text(
            //         _statusText,
            //         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            //               color: const Color(0xFF334155),
            //               fontWeight: FontWeight.w600,
            //             ),
            //       ),
            //       if (_isBootstrapping) ...[
            //         const SizedBox(height: 12),
            //         const LinearProgressIndicator(
            //           minHeight: 4,
            //         ),
            //       ],
            //       const SizedBox(height: 12),
            //       Text(
            //         'Transport logs are printed to the console.',
            //         style: Theme.of(context).textTheme.bodySmall?.copyWith(
            //               color: const Color(0xFF64748B),
            //               fontWeight: FontWeight.w600,
            //             ),
            //       ),
            //     ],
            //   ),
            // ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: MessengerChatShell(
                  currentUserId: _currentUser?.id ?? '',
                  currentUserName: currentUserName,
                  conversations: _uiConversations,
                  users: _uiUsers,
                  selectedConversationId: _selectedConversationId,
                  messages: _activeMessages,
                  composerController: _composerController,
                  messagesScrollController: _messagesScrollController,
                  isSending: _isSending,
                  isRecording: _isRecording,
                  onRefresh: () => unawaited(_refreshAll()),
                  onLogout: () => unawaited(_logoutToConfiguration()),
                  onSelectConversation: _selectConversation,
                  onOpenDirectChat: _openDirectChat,
                  onSend: () => unawaited(_sendMessage()),
                  onPickImage: () => _showSnack(
                    'Use client.uploadFiles(...) in your real app integration.',
                  ),
                  onPickAudio: () => _showSnack(
                    'Voice/file upload goes through client.uploadFiles(...) and sendRestMessage(...).',
                  ),
                  onToggleRecording: () {
                    setState(() {
                      _isRecording = !_isRecording;
                    });
                  },
                  onPickCamera: () => _showSnack(
                    'Camera capture should upload first, then post the message.',
                  ),
                  onPickDocument: () => _showSnack(
                    'Document attachments use the package REST upload flow.',
                  ),
                  onPickVideo: () => _showSnack(
                    'Video attachments use the package REST upload flow.',
                  ),
                  onReact: _reactToMessage,
                  onRemoveReaction: _removeReactionFromMessage,
                  onDelete: null,
                  onMarkSeen: _markSeen,
                  canDeleteMessage: _canDeleteMessage,
                  searchVisibility: MessengerSearchVisibility.always,
                  emptyConversationsMessage:
                      'No conversations yet. Use the people list to create one through the package flow.',
                  emptyUsersMessage:
                      'No users found for this tenant. Register another user from a second device or profile to test direct chat creation.',
                  remoteTypingUsers: _remoteTypingUsersForShell(),
                  onTypingStart: _onTypingStart,
                  onTypingStop: _onTypingStop,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE2F2EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F4C43),
        ),
      ),
    );
  }
}
