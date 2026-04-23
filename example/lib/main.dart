import 'dart:async';

import 'package:flutter/material.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  runApp(const MessengerExampleApp());
}

class MessengerExampleApp extends StatelessWidget {
  const MessengerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Messenger UI Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2B6E62),
        ),
        useMaterial3: true,
      ),
      home: const MessengerExampleScreen(),
    );
  }
}

class MessengerExampleScreen extends StatefulWidget {
  const MessengerExampleScreen({super.key});

  @override
  State<MessengerExampleScreen> createState() => _MessengerExampleScreenState();
}

class _MessengerExampleScreenState extends State<MessengerExampleScreen> {
  final MessengerUser _currentUser = const MessengerUser(
    id: 'me',
    username: 'You',
    roleLabel: 'Patient',
    isOnline: true,
  );

  late final List<MessengerUser> _users;
  late List<MessengerConversation> _conversations;
  final Map<String, List<MessengerChatMessage>> _messagesByConversation = {};

  String? _selectedConversationId;
  bool _isSending = false;
  bool _isRecording = false;

  final TextEditingController _composerController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();

  int _messageCounter = 100;

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  @override
  void dispose() {
    _composerController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  void _seedData() {
    final now = DateTime.now();
    _users = [
      _currentUser,
      const MessengerUser(
        id: 'dr_steph',
        username: 'Dr. Steph',
        roleLabel: 'Care team',
        isOnline: true,
      ),
      const MessengerUser(
        id: 'coach_mike',
        username: 'Coach Mike',
        roleLabel: 'Wellness coach',
        isOnline: false,
      ),
      const MessengerUser(
        id: 'support',
        username: 'Support',
        roleLabel: 'Care concierge',
        isOnline: true,
      ),
    ];

    _conversations = [
      MessengerConversation(
        id: 'care_team',
        title: 'Care Team',
        subtitle: 'Your lab results are in.',
        avatarLabel: 'CT',
        createdAt: now.subtract(const Duration(days: 1)),
        isGlobal: true,
        unreadCount: 1,
        isOnline: true,
      ),
      MessengerConversation(
        id: 'dr_steph',
        title: 'Dr. Steph',
        subtitle: 'How are you feeling today?',
        avatarLabel: 'DS',
        createdAt: now.subtract(const Duration(hours: 6)),
        isOnline: true,
      ),
      MessengerConversation(
        id: 'coach_mike',
        title: 'Coach Mike',
        subtitle: 'Want a 10-minute walk challenge?',
        avatarLabel: 'CM',
        createdAt: now.subtract(const Duration(hours: 3)),
        isOnline: false,
      ),
    ];

    _messagesByConversation['care_team'] = [
      MessengerChatMessage(
        id: 'm1',
        senderId: 'support',
        senderLabel: 'Support',
        type: MessengerMessageType.text,
        content: 'Hi! Your lab results are ready. Want a quick summary?',
        createdAt: now.subtract(const Duration(minutes: 45)),
        deliveryStatus: MessengerDeliveryStatus.seen,
      ),
      MessengerChatMessage(
        id: 'm2',
        senderId: 'me',
        senderLabel: 'You',
        type: MessengerMessageType.text,
        content: 'Yes please. The highlights would be great.',
        createdAt: now.subtract(const Duration(minutes: 40)),
        deliveryStatus: MessengerDeliveryStatus.seen,
      ),
    ];

    _messagesByConversation['dr_steph'] = [
      MessengerChatMessage(
        id: 'm3',
        senderId: 'dr_steph',
        senderLabel: 'Dr. Steph',
        type: MessengerMessageType.text,
        content: 'How are you feeling today? Any new symptoms?',
        createdAt: now.subtract(const Duration(minutes: 30)),
        deliveryStatus: MessengerDeliveryStatus.seen,
        reactions: const [
          MessengerMessageReaction(userId: 'me', reactionType: '👍'),
        ],
      ),
      MessengerChatMessage(
        id: 'm4',
        senderId: 'me',
        senderLabel: 'You',
        type: MessengerMessageType.text,
        content: 'Feeling better overall. Slight headache in the afternoon.',
        createdAt: now.subtract(const Duration(minutes: 26)),
        deliveryStatus: MessengerDeliveryStatus.delivered,
      ),
    ];

    _messagesByConversation['coach_mike'] = [
      MessengerChatMessage(
        id: 'm5',
        senderId: 'coach_mike',
        senderLabel: 'Coach Mike',
        type: MessengerMessageType.text,
        content: 'Want a 10-minute walk challenge after lunch?',
        createdAt: now.subtract(const Duration(minutes: 18)),
        deliveryStatus: MessengerDeliveryStatus.seen,
      ),
    ];

    _selectedConversationId = _conversations.first.id;
  }

  List<MessengerChatMessage> get _activeMessages {
    if (_selectedConversationId == null) {
      return const [];
    }
    return _messagesByConversation[_selectedConversationId] ?? const [];
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectConversation(String conversationId) async {
    setState(() {
      _selectedConversationId = conversationId;
    });
  }

  Future<void> _openDirectChat(MessengerUser user) async {
    final existing = _conversations.where((c) => c.id == user.id).toList();
    if (existing.isEmpty) {
      final newConversation = MessengerConversation(
        id: user.id,
        title: user.username,
        subtitle: 'Start a conversation',
        avatarLabel: user.username.isNotEmpty
            ? user.username.characters.first.toUpperCase()
            : 'U',
        createdAt: DateTime.now(),
        isOnline: user.isOnline,
      );

      setState(() {
        _conversations = [newConversation, ..._conversations];
        _messagesByConversation[user.id] = [];
        _selectedConversationId = user.id;
      });
      return;
    }

    setState(() {
      _selectedConversationId = user.id;
    });
  }

  void _appendMessage(String conversationId, MessengerChatMessage message) {
    final existing = _messagesByConversation[conversationId] ?? const [];
    final updated = List<MessengerChatMessage>.from(existing)..add(message);
    updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _messagesByConversation[conversationId] = updated;
    _updateConversationSubtitle(conversationId, message.content);
  }

  void _updateConversationSubtitle(String conversationId, String subtitle) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) {
      return;
    }

    final conversation = _conversations[index];
    final updatedConversation = MessengerConversation(
      id: conversation.id,
      title: conversation.title,
      subtitle: subtitle,
      avatarLabel: conversation.avatarLabel,
      createdAt: conversation.createdAt,
      isGlobal: conversation.isGlobal,
      unreadCount: conversation.unreadCount,
      avatarUrl: conversation.avatarUrl,
      isOnline: conversation.isOnline,
    );

    final updatedList = List<MessengerConversation>.from(_conversations);
    updatedList[index] = updatedConversation;
    _conversations = updatedList;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScrollController.hasClients) {
        return;
      }
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  MessengerChatMessage _copyMessage(
    MessengerChatMessage message, {
    String? senderId,
    String? senderLabel,
    MessengerMessageType? type,
    String? content,
    DateTime? createdAt,
    bool? isDeleted,
    MessengerDeliveryStatus? deliveryStatus,
    List<MessengerMessageReaction>? reactions,
    bool? isUploading,
    double? uploadProgress,
    String? senderAvatarUrl,
  }) {
    return MessengerChatMessage(
      id: message.id,
      senderId: senderId ?? message.senderId,
      senderLabel: senderLabel ?? message.senderLabel,
      type: type ?? message.type,
      content: content ?? message.content,
      createdAt: createdAt ?? message.createdAt,
      isDeleted: isDeleted ?? message.isDeleted,
      deliveryStatus: deliveryStatus ?? message.deliveryStatus,
      reactions: reactions ?? message.reactions,
      isUploading: isUploading ?? message.isUploading,
      uploadProgress: uploadProgress ?? message.uploadProgress,
      senderAvatarUrl: senderAvatarUrl ?? message.senderAvatarUrl,
    );
  }

  Future<void> _sendMessage() async {
    final conversationId = _selectedConversationId;
    final text = _composerController.text.trim();
    if (conversationId == null || text.isEmpty) {
      return;
    }

    final sentMessage = MessengerChatMessage(
      id: 'm${_messageCounter++}',
      senderId: _currentUser.id,
      senderLabel: _currentUser.username,
      type: MessengerMessageType.text,
      content: text,
      createdAt: DateTime.now(),
      deliveryStatus: MessengerDeliveryStatus.sent,
    );

    setState(() {
      _isSending = true;
      _appendMessage(conversationId, sentMessage);
      _composerController.clear();
    });
    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) {
      return;
    }

    setState(() {
      _isSending = false;
    });

    _updateMessageStatus(
      conversationId,
      sentMessage.id,
      MessengerDeliveryStatus.delivered,
    );

    unawaited(_queueAutoReply(conversationId));
  }

  void _updateMessageStatus(
    String conversationId,
    String messageId,
    MessengerDeliveryStatus status,
  ) {
    final messages = _messagesByConversation[conversationId];
    if (messages == null) {
      return;
    }

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      return;
    }

    final updated = List<MessengerChatMessage>.from(messages);
    updated[index] = _copyMessage(
      updated[index],
      deliveryStatus: status,
    );

    setState(() {
      _messagesByConversation[conversationId] = updated;
    });
  }

  Future<void> _queueAutoReply(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }

    final reply = _autoReplyFor(conversationId);
    if (reply == null) {
      return;
    }

    final replyMessage = MessengerChatMessage(
      id: 'm${_messageCounter++}',
      senderId: reply.senderId,
      senderLabel: reply.senderLabel,
      type: MessengerMessageType.text,
      content: reply.content,
      createdAt: DateTime.now(),
      deliveryStatus: MessengerDeliveryStatus.delivered,
    );

    setState(() {
      _appendMessage(conversationId, replyMessage);
    });
    _scrollToBottom();
  }

  _AutoReply? _autoReplyFor(String conversationId) {
    switch (conversationId) {
      case 'care_team':
        return const _AutoReply(
          senderId: 'support',
          senderLabel: 'Support',
          content: 'Summary: everything looks stable. We can review details if you want.',
        );
      case 'dr_steph':
        return const _AutoReply(
          senderId: 'dr_steph',
          senderLabel: 'Dr. Steph',
          content: 'Thanks for the update. Keep tracking it and let me know if it worsens.',
        );
      case 'coach_mike':
        return const _AutoReply(
          senderId: 'coach_mike',
          senderLabel: 'Coach Mike',
          content: 'Nice! A short walk still counts. Let’s aim for 10 minutes tomorrow.',
        );
    }
    return null;
  }

  Future<void> _reactToMessage(String messageId, String reactionType) async {
    final conversationId = _selectedConversationId;
    if (conversationId == null) {
      return;
    }

    final messages = _messagesByConversation[conversationId];
    if (messages == null) {
      return;
    }

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      return;
    }

    final current = messages[index];
    final reactions = List<MessengerMessageReaction>.from(current.reactions)
      ..add(
        MessengerMessageReaction(
          userId: _currentUser.id,
          reactionType: reactionType,
        ),
      );

    final updated = List<MessengerChatMessage>.from(messages);
    updated[index] = _copyMessage(current, reactions: reactions);

    setState(() {
      _messagesByConversation[conversationId] = updated;
    });
  }

  Future<void> _removeReactionFromMessage(
    String messageId,
    String reactionType,
  ) async {
    final conversationId = _selectedConversationId;
    if (conversationId == null) {
      return;
    }

    final messages = _messagesByConversation[conversationId];
    if (messages == null) {
      return;
    }

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      return;
    }

    final current = messages[index];
    final reactions = List<MessengerMessageReaction>.from(current.reactions);
    final removeIndex = reactions.indexWhere(
      (r) =>
          r.userId == _currentUser.id && r.reactionType == reactionType,
    );
    if (removeIndex == -1) {
      return;
    }
    reactions.removeAt(removeIndex);

    final updated = List<MessengerChatMessage>.from(messages);
    updated[index] = _copyMessage(current, reactions: reactions);

    setState(() {
      _messagesByConversation[conversationId] = updated;
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    final conversationId = _selectedConversationId;
    if (conversationId == null) {
      return;
    }

    final messages = _messagesByConversation[conversationId];
    if (messages == null) {
      return;
    }

    final updated = messages.where((m) => m.id != messageId).toList();
    setState(() {
      _messagesByConversation[conversationId] = updated;
    });
  }

  Future<void> _markSeen(String messageId) async {
    final conversationId = _selectedConversationId;
    if (conversationId == null) {
      return;
    }

    _updateMessageStatus(conversationId, messageId, MessengerDeliveryStatus.seen);
  }

  bool _canDeleteMessage(MessengerChatMessage message) {
    return message.senderId == _currentUser.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: MessengerChatShell(
          currentUserId: _currentUser.id,
          currentUserName: _currentUser.username,
          conversations: _conversations,
          users: _users,
          selectedConversationId: _selectedConversationId,
          messages: _activeMessages,
          composerController: _composerController,
          messagesScrollController: _messagesScrollController,
          isSending: _isSending,
          isRecording: _isRecording,
          onRefresh: () => _showSnack('Refreshed'),
          onLogout: () => _showSnack('Logged out'),
          onSelectConversation: _selectConversation,
          onOpenDirectChat: _openDirectChat,
          onSend: _sendMessage,
          onPickImage: () => _showSnack('Pick image tapped'),
          onPickAudio: () => _showSnack('Pick audio tapped'),
          onToggleRecording: () {
            setState(() => _isRecording = !_isRecording);
          },
          onPickCamera: () => _showSnack('Pick camera tapped'),
          onPickDocument: () => _showSnack('Pick document tapped'),
          onPickVideo: () => _showSnack('Pick video tapped'),
          onReact: _reactToMessage,
          onRemoveReaction: _removeReactionFromMessage,
          onDelete: _deleteMessage,
          onMarkSeen: _markSeen,
          canDeleteMessage: _canDeleteMessage,
        ),
      ),
    );
  }
}

class _AutoReply {
  const _AutoReply({
    required this.senderId,
    required this.senderLabel,
    required this.content,
  });

  final String senderId;
  final String senderLabel;
  final String content;
}
