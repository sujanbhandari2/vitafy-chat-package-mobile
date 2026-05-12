import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:health_messenger_ui/lib/health_messenger_push.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

import 'dummy/associated_user_response.dart';
import 'dummy/dummy_associated_users.dart';
import 'example_models.dart';

bool _hasExampleBootstrapConfig(ExampleBootstrapFormData data) {
  return data.apiBaseUrl.trim().isNotEmpty &&
      data.socketUrl.trim().isNotEmpty &&
      data.apiKey.trim().isNotEmpty &&
      data.externalTenantId.trim().isNotEmpty &&
      data.externalUserId.trim().isNotEmpty &&
      data.externalUserRole.trim().isNotEmpty &&
      data.email.trim().isNotEmpty;
}

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
  _ExampleChatPageState()
      : _socketPrettyChatLogger = SocketPrettyLogger(
          verboseData: kDebugMode,
        ).asChatLogger();

  /// When true, [MessengerChatShell.users] / suggested people use [kDummyAssociatedUsers].
  /// Set false to use live `getUsers` rows ([TenantUser]) instead.
  static const bool _useDummyAssociatedUsers = true;

  final TextEditingController _composerController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  MessengerComposerReplyDraft? _composerReplyDraft;

  /// Spring-style lines to the console; [ChatServiceConfig.socketLogger] sink.
  final ChatLogger _socketPrettyChatLogger;

  StreamSubscription<ChatSocketEvent>? _socketSubscription;
  ChatSession? _session;
  ChatClient? get _client => _session?.client;
  ChatAuth? _sessionAuth;
  ChatTenantScope? _tenantScope;
  TenantUser? _currentUser;

  List<TenantUser> _users = const [];
  List<Conversation> _conversations = const [];
  final Map<String, List<ChatMessage>> _messagesByConversation = {};
  final Map<String, Set<String>> _typingUserIdsByConversation = {};

  String? _selectedConversationId;
  String _statusText = 'Bootstrapping package flow...';
  bool _isBootstrapping = false;
  bool _isSocketConnected = false;
  bool _isRefreshing = false;
  bool _isSending = false;
  bool _isRecording = false;
  int _pendingReactionRequests = 0;
  bool _isLoggingOut = false;
  final bool _featureDeleteMessage = true;
  String? _loadingConversationId;
  Timer? _slowConversationHintTimer;

  StreamSubscription<MessengerPushEvent>? _pushEventsSubscription;
  MessengerPushFirebaseBinding? _pushFirebaseBinding;
  bool _pushIntegrationReady = false;

  /// Shown on [MessengerSuggestedPeoplePanel] rows while opening a direct chat.
  String _suggestedPeopleOpeningUserId = '';
  String _suggestedPeopleSearchQuery = '';

  /// Until [ChatSession.bootstrap] completes, badge listenable has no inbox.
  final ValueNotifier<Map<String, int>> _preBootstrapUnread =
      ValueNotifier<Map<String, int>>(const <String, int>{});

  /// Placeholder [ConversationOrderSnapshot] before session exists.
  final ValueNotifier<ConversationOrderSnapshot> _preBootstrapOrder =
      ValueNotifier<ConversationOrderSnapshot>(
    ConversationOrderSnapshot(
      apiRank: Map<String, int>.unmodifiable(<String, int>{}),
      promotedAt: Map<String, DateTime>.unmodifiable(<String, DateTime>{}),
    ),
  );

  static const String _draftDirectPrefix = '__pending_direct__:';

  bool _isDraftConversationId(String? id) {
    final t = id?.trim() ?? '';
    return t.startsWith(_draftDirectPrefix);
  }

  String? _draftPeerChatUserId(String? draftId) {
    if (!_isDraftConversationId(draftId)) {
      return null;
    }
    return draftId!.trim().substring(_draftDirectPrefix.length);
  }

  String _draftConversationIdForPeer(String peerChatUserId) {
    return '$_draftDirectPrefix${peerChatUserId.trim()}';
  }

  @override
  void initState() {
    super.initState();
    if (_hasExampleBootstrapConfig(widget.initialData)) {
      _isBootstrapping = true;
    }
    unawaited(_bootstrapPackageFlow());
  }

  @override
  void dispose() {
    _slowConversationHintTimer?.cancel();
    _preBootstrapUnread.dispose();
    _preBootstrapOrder.dispose();
    _composerController.dispose();
    _composerFocusNode.dispose();
    _messagesScrollController.dispose();
    unawaited(_disposeActiveClient());
    super.dispose();
  }

  List<MessengerChatMessage> get _activeMessages {
    final conversationId = _selectedConversationId;
    if (conversationId == null) {
      return const [];
    }
    if (_isDraftConversationId(conversationId)) {
      return const [];
    }
    final source = _messagesByConversation[conversationId] ?? const [];
    return source.map(_mapMessage).toList();
  }

  List<MessengerConversation> _mapConversations(
    Map<String, int> unreadMap,
    ConversationOrderSnapshot orderSnapshot,
  ) {
    return _conversations
        .map((c) => _mapConversation(c, unreadMap, orderSnapshot))
        .toList(growable: false);
  }

  List<MessengerUser> get _uiUsers {
    if (_useDummyAssociatedUsers) {
      final current = _currentUser;
      final selfEmail = current?.email.trim().toLowerCase() ?? '';
      final selfProviderId = current?.providerUserId?.trim() ?? '';
      final mapped = kDummyAssociatedUsers
          .where((a) {
            final email = a.email.trim().toLowerCase();
            if (selfEmail.isNotEmpty && email == selfEmail) {
              return false;
            }
            if (selfProviderId.isNotEmpty && a.userId.trim() == selfProviderId) {
              return false;
            }
            return true;
          })
          .map(_messengerUserFromAssociated)
          .toList(growable: false);
      final sorted = [...mapped]..sort((left, right) {
          if (left.isOnline != right.isOnline) {
            return left.isOnline ? -1 : 1;
          }
          return left.username
              .toLowerCase()
              .compareTo(right.username.toLowerCase());
        });
      return sorted;
    }

    final currentUserId = _currentUser?.id;
    final mapped = _users
        .where((user) => user.id != currentUserId)
        .map(_mapUser)
        .toList(growable: false);
    final sorted = [...mapped]..sort((left, right) {
        if (left.isOnline != right.isOnline) {
          return left.isOnline ? -1 : 1;
        }
        return left.username
            .toLowerCase()
            .compareTo(right.username.toLowerCase());
      });
    return sorted;
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
      unawaited(_resyncNativePushConfig());
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

  /// Wires [HealthMessengerPush], native delivered-ACK snapshot, and foreground
  /// [FirebaseMessaging] when Firebase is configured. Fails soft (logs only)
  /// when `google-services.json` / `GoogleService-Info.plist` are missing.
  Future<void> _setupPushAfterBootstrap(ChatSession session) async {
    if (!mounted) {
      return;
    }
    await _teardownPushIntegration(updateUi: false);
    final sessionAuth = session.sessionAuth;
    if (sessionAuth == null) {
      return;
    }
    try {
      // [main] already calls Firebase.initializeApp(); if it failed (no
      // google-services.json / values.xml), do not retry here — that only
      // duplicates the same PlatformException and noisy logs.
      if (Firebase.apps.isEmpty) {
        if (mounted) {
          setState(() => _pushIntegrationReady = false);
        }
        _appendLog(
          'Push bridge skipped (Firebase not initialized). '
          'Add Firebase Android/iOS config or use Firebase.initializeApp(options: …) in main.',
        );
        return;
      }
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _appendLog(
        'FCM permission',
        data: {'authorizationStatus': '${settings.authorizationStatus}'},
      );

      final push = HealthMessengerPush.instance;
      await push.startListening();
      await _pushEventsSubscription?.cancel();
      _pushEventsSubscription = push.events.listen(_onMessengerPushEvent);

      await push.syncNativePushConfig(
        config: session.client.config,
        auth: sessionAuth,
      );

      await _pushFirebaseBinding?.detach();
      final binding = MessengerPushFirebaseBinding(
        gate: const MessengerPushGate(),
      );
      binding.onFcmToken = (token) async {
        final preview =
            token.length > 24 ? '${token.substring(0, 24)}…' : token;
        _appendLog('FCM device token', data: {'preview': preview});
      };
      await binding.attachForeground(
        chatClient: session.client,
        chatAuth: sessionAuth,
      );
      _pushFirebaseBinding = binding;

      unawaited(push.drainNativeAckQueue());

      if (mounted) {
        setState(() => _pushIntegrationReady = true);
      }
      _appendLog('Push bridge ready (native sync + foreground listener)');
    } catch (e, st) {
      if (mounted) {
        setState(() => _pushIntegrationReady = false);
      } else {
        _pushIntegrationReady = false;
      }
      _appendLog(
        'Push bridge not active (add Firebase config to enable)',
        data: {
          'error': e.toString().split('\n').first,
        },
      );
      debugPrintStack(stackTrace: st, maxFrames: 12);
    }
  }

  void _onMessengerPushEvent(MessengerPushEvent event) {
    if (!mounted) {
      return;
    }
    switch (event.kind) {
      case MessengerPushEventKind.incomingChatMessage:
        _appendLog(
          'Native push (chat)',
          data: {
            'conversationId': event.conversationId,
            'messageId': event.messageId,
            'nativeAckSucceeded': event.nativeAckSucceeded,
          },
        );
        final convId = event.conversationId;
        final msgId = event.messageId;
        if (convId != null &&
            msgId != null &&
            convId.isNotEmpty &&
            msgId.isNotEmpty) {
          unawaited(_refreshConversationAfterRemoteHint(convId));
        }
        break;
      case MessengerPushEventKind.fcmTokenRefresh:
        _appendLog(
          'FCM token refresh (native)',
          data: {'token': event.token},
        );
        break;
      case MessengerPushEventKind.unknown:
        _appendLog('Push event', data: event.raw);
        break;
    }
  }

  Future<void> _refreshConversationAfterRemoteHint(
      String conversationId) async {
    final client = _client;
    final auth = _sessionAuth;
    if (client == null || auth == null) {
      return;
    }
    try {
      final page = await client.getMessages(auth, conversationId);
      final items = [...page.items]
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
      if (!mounted) {
        return;
      }
      setState(() {
        _messagesByConversation[conversationId] = items;
      });
      _appendLog(
        'Messages refreshed after push',
        data: {'conversationId': conversationId},
      );
    } catch (e) {
      _appendLog(
        'Refresh after push failed',
        data: {'error': e.toString()},
      );
    }
  }

  Future<void> _resyncNativePushConfig() async {
    final session = _session;
    final auth = _sessionAuth;
    if (session == null || auth == null || !_pushIntegrationReady) {
      return;
    }
    try {
      await HealthMessengerPush.instance.syncNativePushConfig(
        config: session.client.config,
        auth: auth,
      );
      unawaited(HealthMessengerPush.instance.drainNativeAckQueue());
    } catch (_) {}
  }

  Future<void> _teardownPushIntegration({bool updateUi = true}) async {
    await _pushEventsSubscription?.cancel();
    _pushEventsSubscription = null;
    await _pushFirebaseBinding?.detach();
    _pushFirebaseBinding = null;
    await HealthMessengerPush.instance.stopListening();
    _pushIntegrationReady = false;
    if (updateUi && mounted) {
      setState(() {});
    }
  }

  Future<void> _bootstrapPackageFlow() async {
    final initialData = widget.initialData;
    final apiBaseUrl = initialData.apiBaseUrl.trim();
    final socketUrl = initialData.socketUrl.trim();
    final apiKey = initialData.apiKey.trim();
    final externalTenantId = initialData.externalTenantId.trim();
    final externalUserId = initialData.externalUserId.trim();
    final externalUserRole = initialData.externalUserRole.trim();
    final email = initialData.email.trim();
    final name = initialData.name.trim();
    final profile = initialData.profile?.trim();

    if (apiBaseUrl.isEmpty ||
        socketUrl.isEmpty ||
        apiKey.isEmpty ||
        externalTenantId.isEmpty ||
        externalUserId.isEmpty ||
        externalUserRole.isEmpty ||
        email.isEmpty) {
      if (mounted) {
        setState(() {
          _statusText = 'Bootstrap config is incomplete.';
          _isBootstrapping = false;
        });
      }
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
          // Flutter mobile is more reliable with websocket-only for this gateway.
          socketTransports: const ['websocket'],
          apiLogger: (message, {data}) =>
              _appendLog('API $message', data: data),
          socketLogger: _socketPrettyChatLogger,
        ),
      );
      bootstrappingSession = session;

      final apiAuth = ChatAuth(apiKey: apiKey);
      final bootstrapResult = await session.bootstrap(
        apiAuth: apiAuth,
        externalTenantId: externalTenantId,
        externalUserId: externalUserId,
        externalUserRole: externalUserRole,
        email: email,
        name: name.isEmpty ? null : name,
        profile: profile != null && profile.isNotEmpty ? profile : null,
        // Socket polling+upgrade can take several seconds; show tenant + REST data first.
        awaitSocketConnect: false,
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
        _sessionAuth = sessionAuth;
        _tenantScope = tenantScope;
        _currentUser = registeredUser;
        _isSocketConnected = false;
        _messagesByConversation.clear();
        _typingUserIdsByConversation.clear();
        _selectedConversationId = null;
        _suggestedPeopleOpeningUserId = '';
        _suggestedPeopleSearchQuery = '';
      });
      bootstrappingSession = null;

      final socketConnected = bootstrapResult.socketConnected;
      final socketDeferred = bootstrapResult.socketConnectPending;
      if (!socketDeferred &&
          !socketConnected &&
          bootstrapResult.connectError != null) {
        _appendLog(
          'Socket connect failed, continuing in REST-only mode',
          data: {'error': bootstrapResult.connectError.toString()},
        );
      } else if (socketDeferred) {
        _appendLog('Socket connect started in background');
      }

      if (mounted) {
        setState(() {
          _isSocketConnected = socketConnected;
        });
      }

      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }

      await _refreshAll(selectFirstConversation: true);

      if (!mounted) {
        return;
      }

      setState(() {
        if (socketDeferred) {
          _statusText =
              'Signed in as ${registeredUser.displayName} · tenant ${tenantScope.tenantId} · connecting realtime…';
        } else if (socketConnected) {
          _statusText =
              'Connected as ${registeredUser.displayName} in tenant ${tenantScope.tenantId}.';
        } else {
          _statusText =
              'Connected to tenant data as ${registeredUser.displayName} (read-only until socket reconnects).';
        }
      });
      _appendLog(
        'Bootstrap complete',
        data: {
          'tenantId': tenantScope.tenantId,
          'chatUserId': registeredUser.id,
        },
      );
      await _setupPushAfterBootstrap(session);
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
    final client = _client;
    final auth = _sessionAuth;
    if (client == null || auth == null) {
      return;
    }

    final chatUserId = _currentUser?.id.trim();
    if (chatUserId == null || chatUserId.isEmpty) {
      return;
    }

    setState(() {
      _isRefreshing = true;
      _statusText = 'Refreshing package data...';
    });

    try {
      // In dummy-users mode the suggested-people panel renders entirely from
      // [kDummyAssociatedUsers]; the live `getUsers` fetch is only needed for
      // sender-name / avatar lookups on tenant messages, so do it in the
      // background instead of blocking the list pane.
      final usersFuture = _useDummyAssociatedUsers
          ? Future<List<TenantUser>>.value(const <TenantUser>[])
          : client.getUsers(auth);

      final results = await Future.wait<Object?>([
        usersFuture,
        client.getConversations(
          auth,
          forUserId: chatUserId,
        ),
      ]);

      if (!mounted) {
        return;
      }

      final users = results[0]! as List<TenantUser>;
      final conversations = results[1]! as List<Conversation>;

      final selectedCurrentUser =
          users.where((user) => user.id == _currentUser?.id).firstOrNull;

      setState(() {
        if (!_useDummyAssociatedUsers) {
          _users = users;
        }
        _currentUser = selectedCurrentUser ?? _currentUser ?? users.firstOrNull;
        _conversations = conversations;
        if (_selectedConversationId != null &&
            !_isDraftConversationId(_selectedConversationId) &&
            !_conversations.any(
              (conversation) => conversation.id == _selectedConversationId,
            )) {
          _selectedConversationId = null;
        }
        // Suggested people + conversations are now in state, so clear the
        // list-pane spinner immediately. Message loading and the lazy
        // `getUsers` fetch below run in the background so the shell can
        // render the people list right away.
        _isRefreshing = false;
        _statusText = _isSocketConnected
            ? 'Data refreshed from the package client.'
            : 'Data refreshed (REST-only, socket disconnected).';
      });

      _session?.inbox.seedFromConversations(conversations);

      final selectedConversationId = _selectedConversationId;
      if (selectedConversationId != null &&
          !_isDraftConversationId(selectedConversationId)) {
        unawaited(_loadMessages(selectedConversationId));
      } else if (selectFirstConversation && _conversations.isNotEmpty) {
        unawaited(
          _selectConversation(_conversations.first.id, tryReconnect: false),
        );
      }

      if (_useDummyAssociatedUsers) {
        unawaited(_fetchTenantUsersInBackground(client, auth));
      }
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
      if (mounted && _isRefreshing) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _fetchTenantUsersInBackground(
    ChatClient client,
    ChatAuth auth,
  ) async {
    try {
      final users = await client.getUsers(auth);
      if (!mounted) {
        return;
      }
      final selectedCurrentUser =
          users.where((user) => user.id == _currentUser?.id).firstOrNull;
      setState(() {
        _users = users;
        _currentUser = selectedCurrentUser ?? _currentUser;
      });
    } catch (error, stackTrace) {
      _appendLog(
        'Background tenant users fetch failed',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
    }
  }

  Future<void> _refreshConversations() async {
    final client = _client;
    final auth = _sessionAuth;
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
          !_isDraftConversationId(_selectedConversationId) &&
          !_conversations.any(
            (conversation) => conversation.id == _selectedConversationId,
          )) {
        _selectedConversationId = null;
      }
    });
    _session?.inbox.seedFromConversations(conversations);
  }

  Future<void> _selectConversation(
    String conversationId, {
    bool tryReconnect = true,
  }) async {
    conversationId = conversationId.trim();
    if (conversationId.isEmpty) {
      return;
    }

    final session = _session;
    final client = _client;
    if (session == null || client == null) {
      return;
    }

    _slowConversationHintTimer?.cancel();
    setState(() {
      _selectedConversationId = conversationId;
      _loadingConversationId = conversationId;
      _composerReplyDraft = null;
      _statusText = 'Loading conversation $conversationId...';
    });
    _slowConversationHintTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted || _loadingConversationId != conversationId) {
        return;
      }
      setState(() {
        _statusText = 'Still loading conversation $conversationId...';
      });
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
        _loadingConversationId = null;
        _statusText = 'Could not open conversation: $error';
      });
      _showSnack('Could not open conversation.');
    } finally {
      _slowConversationHintTimer?.cancel();
      if (mounted && _loadingConversationId == conversationId) {
        setState(() {
          _loadingConversationId = null;
        });
      }
    }
  }

  Future<void> _loadMessages(String conversationId) async {
    conversationId = conversationId.trim();
    if (conversationId.isEmpty || _isDraftConversationId(conversationId)) {
      return;
    }

    final client = _client;
    final auth = _sessionAuth;
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
      if (_loadingConversationId == conversationId) {
        _loadingConversationId = null;
      }
    });
  }

  /// Same shape as bootstrap / `POST …/chat/users` (matches web widget first row).
  ChatUserRegistrationBody _registrationBodyForSignedInUser() {
    final d = widget.initialData;
    return ChatUserRegistrationBody.resolve(
      externalTenantId: d.externalTenantId,
      externalUserId: d.externalUserId,
      externalUserRole: d.externalUserRole,
      email: d.email,
      name: d.name,
      profile: d.profile,
    );
  }

  /// Builds a [ChatUserRegistrationBody] for a suggested person from [kDummyAssociatedUsers].
  ChatUserRegistrationBody? _registrationBodyForDummyAssociatedPeer(
    MessengerUser user,
  ) {
    final uid = user.id.trim();
    AssociatedUserResponse? match;
    for (final a in kDummyAssociatedUsers) {
      if (a.userId.trim() == uid) {
        match = a;
        break;
      }
    }
    if (match == null) {
      return null;
    }
    final tenant = widget.initialData.externalTenantId.trim();
    final roleRaw = (match.chatUserRole ?? match.type).trim().toLowerCase();
    final role =
        roleRaw.isNotEmpty ? roleRaw : kChatUserDefaultExternalRole;
    return ChatUserRegistrationBody(
      externalTenantId: tenant,
      externalUserId: match.userId.trim(),
      externalUserRole: role,
      email: match.email.trim().isNotEmpty ? match.email.trim() : null,
      name: match.name.trim().isNotEmpty ? match.name.trim() : null,
      profile: match.profilePicture.trim().isNotEmpty
          ? match.profilePicture.trim()
          : null,
    );
  }

  Future<void> _openDirectChat(MessengerUser user) async {
    final currentUser = _currentUser;
    final session = _session;
    final client = _client;
    final auth = _sessionAuth;
    if (session == null || currentUser == null) {
      _showSnack('Bootstrap the package flow first.');
      return;
    }
    if (client == null || auth == null) {
      _showSnack('Session auth is not ready yet.');
      return;
    }

    if (mounted) {
      setState(() => _suggestedPeopleOpeningUserId = user.id.trim());
    }
    try {
      final existing = _findDirectConversation(currentUser.id, user.id);
      if (existing != null) {
        await _selectConversation(existing.id);
        return;
      }

      // Dummy directory uses host `userId` strings, not numeric ChatUser ids —
      // mirror vitafy-generic-chat-embed: `POST …/users/start-conversation`.
      if (_useDummyAssociatedUsers) {
        final selfBody = _registrationBodyForSignedInUser();
        final peerBody = _registrationBodyForDummyAssociatedPeer(user);
        if (peerBody == null) {
          _showSnack('Unknown suggested person; refresh and try again.');
          return;
        }
        try {
          _appendLog(
            'Opening direct via startConversation',
            data: {
              'peerExternalUserId': peerBody.externalUserId,
            },
          );
          final created = await client.startConversation(
            auth,
            users: [selfBody, peerBody],
          );
          await _refreshConversations();
          await _selectConversation(created.id);
        } catch (error, stackTrace) {
          _appendLog(
            'startConversation failed',
            data: {
              'error': error.toString(),
              'stackTrace': stackTrace.toString(),
            },
          );
          _showSnack('Could not start conversation (see logs).');
        }
        return;
      }

      final resolved = await client.resolveDirectConversation(
        auth,
        currentUserId: currentUser.id,
        peerUserId: user.id,
        seedConversations: _conversations,
      );
      await _refreshConversations();
      await _selectConversation(resolved.conversation.id);
    } finally {
      if (mounted) {
        setState(() => _suggestedPeopleOpeningUserId = '');
      }
    }
  }

  Future<String?> _materializeDraftDirectConversation(String draftId) async {
    final client = _client;
    final auth = _sessionAuth;
    final currentUser = _currentUser;
    final session = _session;
    final peerId = _draftPeerChatUserId(draftId);
    if (client == null ||
        auth == null ||
        currentUser == null ||
        session == null ||
        peerId == null ||
        peerId.isEmpty) {
      return null;
    }

    try {
      final created = await client.createConversation(
        auth,
        type: 'DIRECT',
        participantIds: [
          currentUser.id.trim(),
          peerId.trim(),
        ],
      );

      if (!mounted) {
        return null;
      }

      await _refreshConversations();

      if (!mounted) {
        return null;
      }

      setState(() {
        _selectedConversationId = created.id;
        _messagesByConversation.remove(draftId);
      });

      try {
        await session.joinConversation(created.id);
      } catch (error, stackTrace) {
        _appendLog(
          'Join conversation failed',
          data: {
            'conversationId': created.id,
            'error': error.toString(),
            'stackTrace': stackTrace.toString(),
          },
        );
      }

      return created.id;
    } catch (error, stackTrace) {
      _appendLog(
        'Create direct conversation failed',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      _showSnack('Could not create direct conversation.');
      return null;
    }
  }

  Future<String?> _prepareOutgoingConversationForShell(
    String conversationId,
  ) async {
    if (!_isDraftConversationId(conversationId)) {
      return conversationId;
    }
    return _materializeDraftDirectConversation(conversationId);
  }

  void _onMobileThreadClosed(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    final session = _session;
    if (session != null && !_isDraftConversationId(id)) {
      unawaited(
        session.leaveConversation(id).catchError((Object error) {
          _appendLog(
            'Leave conversation on mobile thread close failed',
            data: {
              'conversationId': id,
              'error': error.toString(),
            },
          );
        }),
      );
    }
    if (_isDraftConversationId(id)) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_selectedConversationId == id) {
          _selectedConversationId = null;
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final client = _client;
    var conversationId = _selectedConversationId;
    final text = _composerController.text.trim();
    if (client == null || conversationId == null || text.isEmpty) {
      return;
    }

    final replyId = _composerReplyDraft?.targetMessageId.trim() ?? '';
    final replyToMessageId = replyId.isEmpty ? null : replyId;

    setState(() {
      _isSending = true;
    });
    try {
      final connected = await _ensureSocketConnected();
      if (!connected) {
        return;
      }

      if (_isDraftConversationId(conversationId)) {
        final realId =
            await _materializeDraftDirectConversation(conversationId);
        if (realId == null || !mounted) {
          return;
        }
        conversationId = realId;
      }

      final created = await client.sendMessage(
        conversationId: conversationId,
        type: MessageType.text,
        content: text,
        replyToMessageId: replyToMessageId,
      );
      _composerController.clear();
      if (mounted) {
        setState(() {
          _composerReplyDraft = null;
        });
      }
      _upsertMessage(conversationId, created);
      _session?.inbox.bumpConversation(conversationId);

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

    if (mounted) {
      setState(() => _pendingReactionRequests++);
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
    } finally {
      if (mounted) {
        setState(() => _pendingReactionRequests--);
      }
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

    if (mounted) {
      setState(() => _pendingReactionRequests++);
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
    } finally {
      if (mounted) {
        setState(() => _pendingReactionRequests--);
      }
    }
  }

  Future<void> _handleDelete(String messageId) async {
    final client = _client;
    final auth = _sessionAuth;
    final currentUser = _currentUser;
    final conversationId = _selectedConversationId;
    if (client == null ||
        auth == null ||
        currentUser == null ||
        conversationId == null ||
        _isDraftConversationId(conversationId)) {
      return;
    }

    try {
      final result = await client.deleteMessage(
        auth,
        conversationId: conversationId,
        messageId: messageId,
        userId: currentUser.id,
      );
      final effectiveDeletedAt = result.deletedAt ?? DateTime.now().toUtc();
      _applyMessageDeleted(
        conversationId: result.conversationId,
        messageId: result.messageId,
        deletedAt: effectiveDeletedAt,
      );
    } catch (error, stackTrace) {
      _appendLog(
        'Delete message failed',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      _showSnack('Failed to delete message');
    }
  }

  Future<void> _logoutToConfiguration() async {
    if (mounted) {
      setState(() => _isLoggingOut = true);
    }
    try {
      await _disposeActiveClient();
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _sessionAuth = null;
      _tenantScope = null;
      _currentUser = null;
      _isSocketConnected = false;
      _users = const [];
      _conversations = const [];
      _messagesByConversation.clear();
      _typingUserIdsByConversation.clear();
      _selectedConversationId = null;
      _suggestedPeopleOpeningUserId = '';
      _suggestedPeopleSearchQuery = '';
      _statusText = 'Logged out.';
    });
    _appendLog('Disconnected client session, returning to configuration');

    Navigator.of(context).pop(true);
  }

  Future<void> _disposeActiveClient() async {
    await _teardownPushIntegration(updateUi: false);
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
        unawaited(_resyncNativePushConfig());
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
      case ChatSocketEventType.messageDeleted:
        final deletedMessage = event.deletedMessage;
        if (deletedMessage != null) {
          _applyDeletedMessage(deletedMessage);
        }
        break;
      case ChatSocketEventType.messageEdited:
        final editedMessage = event.editedMessage;
        if (editedMessage != null) {
          _applyEditedMessage(editedMessage);
        }
        break;
      case ChatSocketEventType.conversationCreated:
        final createdConversation = event.conversationCreated;
        if (createdConversation != null) {
          _applyConversationCreated(createdConversation);
        }
        break;
      case ChatSocketEventType.conversationMessage:
        final conversationMessage = event.conversationMessage;
        if (conversationMessage != null) {
          _upsertMessage(
            conversationMessage.conversationId,
            conversationMessage.message,
          );
        }
        break;
      case ChatSocketEventType.unreadCountUpdated:
        break;
      case ChatSocketEventType.userBadgeUpdated:
        final badgeUpdated = event.userBadgeUpdated;
        if (badgeUpdated != null) {
          _appendLog(
            'User badge updated',
            data: {
              'usersWithUnreadMessages': badgeUpdated.usersWithUnreadMessages,
              if (badgeUpdated.totalUnreadMessages != null)
                'totalUnreadMessages': badgeUpdated.totalUnreadMessages,
            },
          );
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
      next[index] = _coalesceDeletedMessageOnUpsert(next[index], message);
    }
    next.sort((left, right) => left.createdAt.compareTo(right.createdAt));

    if (!mounted) {
      return;
    }

    setState(() {
      _messagesByConversation[conversationId] = next;
    });
  }

  void _upsertConversation(Conversation conversation) {
    final next = List<Conversation>.from(_conversations);
    final index = next.indexWhere((item) => item.id == conversation.id);
    if (index == -1) {
      next.insert(0, conversation);
    } else {
      next[index] = conversation;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _conversations = next;
    });
  }

  void _applyDeletedMessage(DeletedMessageEvent deletedMessage) {
    _applyMessageDeleted(
      conversationId: deletedMessage.conversationId,
      messageId: deletedMessage.messageId,
      deletedAt: deletedMessage.deletedAt,
    );
  }

  void _applyMessageDeleted({
    required String conversationId,
    required String messageId,
    required DateTime deletedAt,
  }) {
    final cid = conversationId.trim();
    final mid = messageId.trim();
    if (cid.isEmpty || mid.isEmpty) {
      return;
    }

    ChatMessage markDeleted(ChatMessage message) {
      if (message.id != mid) {
        return message;
      }
      final normalizedDeletedAt = deletedAt.toUtc();
      if (message.deletedAt == normalizedDeletedAt &&
          message.content.trim() == '[deleted]') {
        return message;
      }
      return message.copyWith(
        deletedAt: normalizedDeletedAt,
        content: '[deleted]',
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      final thread = _messagesByConversation[cid] ?? const <ChatMessage>[];
      final hasThread = thread.isNotEmpty;
      if (hasThread) {
        _messagesByConversation[cid] =
            thread.map(markDeleted).toList(growable: false);
      }

      _conversations = _conversations.map((conversation) {
        if (conversation.id != cid) {
          return conversation;
        }
        final latest = conversation.latestMessage;
        if (latest == null || latest.id != mid) {
          return conversation;
        }
        return Conversation(
          id: conversation.id,
          tenantId: conversation.tenantId,
          type: conversation.type,
          title: conversation.title,
          createdBy: conversation.createdBy,
          createdAt: conversation.createdAt,
          updatedAt: conversation.updatedAt,
          participants: conversation.participants,
          unreadCount: conversation.unreadCount,
          latestMessage: markDeleted(latest),
        );
      }).toList(growable: false);
    });
  }

  ChatMessage _coalesceDeletedMessageOnUpsert(
    ChatMessage existing,
    ChatMessage incoming,
  ) {
    if (!existing.isDeleted || incoming.isDeleted) {
      return incoming;
    }
    final inferredDeleted = incoming.content.trim() == '[deleted]';
    if (inferredDeleted) {
      return incoming.copyWith(
        deletedAt: existing.deletedAt,
        content: '[deleted]',
      );
    }
    return incoming.copyWith(
      deletedAt: existing.deletedAt,
      content: '[deleted]',
    );
  }

  void _applyEditedMessage(MessageEditedEvent editedMessage) {
    _upsertMessage(editedMessage.conversationId, editedMessage.message);
  }

  void _applyConversationCreated(ConversationCreatedEvent createdConversation) {
    _upsertConversation(createdConversation.conversation);
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
                    accessToken: user.accessToken,
                    tokenType: user.tokenType,
                    providerUserId: user.providerUserId,
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
              unreadCount: conversation.unreadCount,
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
              latestMessage: conversation.latestMessage,
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

  /// Maps host-style associated users into shell rows.
  ///
  /// Uses [AssociatedUserResponse.userId] as [MessengerUser.id]; `openDirectChat`
  /// passes that value as `peerUserId`. If your chat API expects another field
  /// (e.g. [AssociatedUserResponse.id] or [AssociatedUserResponse.chatUid]), change this mapper only.
  MessengerUser _messengerUserFromAssociated(AssociatedUserResponse a) {
    final pic = a.profilePicture.trim();
    return MessengerUser(
      id: a.userId.trim(),
      username: a.name.trim().isNotEmpty ? a.name.trim() : a.email.trim(),
      roleLabel: (a.chatUserRole ?? a.type).trim(),
      isOnline: false,
      avatarUrl: pic.isEmpty ? null : pic,
    );
  }

  MessengerUser _mapParticipantUser(ConversationParticipantUser user) {
    return MessengerUser(
      id: user.id,
      username: user.username,
      roleLabel: user.role.label,
      isOnline: user.isOnline,
      avatarUrl: user.avatarUrl,
    );
  }

  MessengerConversation _mapConversation(
    Conversation conversation,
    Map<String, int> unreadMap,
    ConversationOrderSnapshot orderSnapshot,
  ) {
    final title = _conversationTitle(conversation);
    final messages = _messagesByConversation[conversation.id] ?? const [];
    final localLatest = messages.isEmpty ? null : messages.last;
    final restLatest = conversation.latestMessage;
    final previewSource = _newestChatMessage(localLatest, restLatest);
    final subtitle = previewSource == null
        ? '${conversation.type} conversation'
        : _messagePreview(previewSource);
    final activityCandidate =
        _newestDateTime(localLatest?.createdAt, restLatest?.createdAt);
    final lastActivityAt = activityCandidate != null &&
            activityCandidate.isAfter(conversation.updatedAt)
        ? activityCandidate
        : conversation.updatedAt;
    final others = conversation.participants
        .where((participant) => participant.user.id != _currentUser?.id)
        .toList();

    return MessengerConversation(
      id: conversation.id,
      title: title,
      subtitle: subtitle,
      avatarLabel: _initials(title),
      createdAt: conversation.createdAt,
      lastActivityAt: lastActivityAt,
      isGlobal: conversation.isGlobal,
      unreadCount: unreadMap[conversation.id] ?? 0,
      avatarUrl: others.length == 1 ? others.first.user.avatarUrl : null,
      isOnline: others.any((participant) => participant.user.isOnline),
      peerUsers: others
          .map((p) => _mapParticipantUser(p.user))
          .toList(growable: false),
      apiRank: orderSnapshot.apiRank[conversation.id],
      promotedAt: orderSnapshot.promotedAt[conversation.id],
    );
  }

  MessengerChatMessage _mapMessage(ChatMessage message) {
    final body = message.content.trim();
    final attachmentUrl =
        message.attachments.isEmpty ? '' : message.attachments.first.url.trim();

    late final String content;
    late final String? caption;

    switch (message.type) {
      case MessageType.image:
      case MessageType.voice:
      case MessageType.video:
      case MessageType.file:
        if (attachmentUrl.isNotEmpty) {
          content = attachmentUrl;
          caption = body.isEmpty ? null : body;
        } else {
          content = body.isEmpty ? _messagePreview(message) : body;
          caption = null;
        }
        break;
      case MessageType.text:
      case MessageType.link:
      case MessageType.other:
        content = body.isEmpty ? _messagePreview(message) : body;
        caption = null;
        break;
    }

    return MessengerChatMessage(
      id: message.id,
      senderId: message.senderId,
      senderLabel: _senderName(message),
      type: _mapUiMessageType(message.type),
      content: content,
      caption: caption,
      createdAt: message.createdAt,
      isDeleted: message.isDeleted,
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
      quotedReply: _quotedReplyFromChat(message),
    );
  }

  MessengerQuotedMessage? _quotedReplyFromChat(ChatMessage message) {
    final r = message.replyTo;
    if (r == null) {
      return null;
    }
    final id = r.id.trim();
    if (id.isEmpty) {
      return null;
    }
    return MessengerQuotedMessage(
      messageId: id,
      senderLabel: _replyToSenderLabel(r),
      preview: _replyToPreview(r),
      messageType: _mapUiMessageType(r.type),
    );
  }

  String _replyToSenderLabel(ReplyToMessage r) {
    final senderName = r.sender?.name?.trim() ?? '';
    if (senderName.isNotEmpty) {
      return senderName;
    }
    final user = _users.where((item) => item.id == r.senderId).firstOrNull;
    if (user != null) {
      return user.displayName;
    }
    for (final conversation in _conversations) {
      final participant = conversation.participants
          .where((item) => item.user.id == r.senderId)
          .firstOrNull;
      if (participant != null) {
        return participant.user.username;
      }
    }
    return r.senderId == _currentUser?.id ? 'You' : 'Unknown user';
  }

  String _replyToPreview(ReplyToMessage r) {
    final c = r.content.trim();
    if (c.isNotEmpty) {
      return c.length > 80 ? '${c.substring(0, 79)}…' : c;
    }
    switch (r.type) {
      case MessageType.image:
        return 'Photo';
      case MessageType.video:
        return 'Video';
      case MessageType.voice:
        return 'Voice message';
      case MessageType.file:
        return 'File';
      case MessageType.text:
      case MessageType.link:
      case MessageType.other:
        return 'Message';
    }
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
      if (others.length <= 2) {
        return others.join(', ');
      }
      return '${others[0]}, ${others[1]}…';
    }

    return conversation.type.toUpperCase();
  }

  MessengerMessageType _mapUiMessageType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return MessengerMessageType.image;
      case MessageType.voice:
        return MessengerMessageType.voice;
      case MessageType.video:
        return MessengerMessageType.video;
      case MessageType.file:
        return MessengerMessageType.file;
      case MessageType.text:
      case MessageType.link:
      case MessageType.other:
        return MessengerMessageType.text;
    }
  }

  MessageType _mapBackendMessageType(MessengerMessageType type) {
    switch (type) {
      case MessengerMessageType.image:
        return MessageType.image;
      case MessengerMessageType.voice:
        return MessageType.voice;
      case MessengerMessageType.video:
        return MessageType.video;
      case MessengerMessageType.file:
        return MessageType.file;
      case MessengerMessageType.text:
        return MessageType.text;
    }
  }

  ChatMessage _mapUiMessageToBackend(
    String conversationId,
    MessengerChatMessage message,
  ) {
    final backendType = _mapBackendMessageType(message.type);
    final hasAttachment = backendType != MessageType.text;
    return ChatMessage(
      id: message.id,
      conversationId: conversationId,
      tenantId: _tenantScope?.tenantId ?? '',
      senderId: message.senderId,
      type: backendType,
      content: hasAttachment ? (message.caption ?? '') : message.content,
      attachments: hasAttachment
          ? [
              ChatAttachment(
                url: message.content,
                fileName: message.content.split('/').last,
                kind: backendType.apiValue.toLowerCase(),
              ),
            ]
          : const [],
      replyToMessageId: null,
      replyTo: null,
      translatedMessage: null,
      transcribedMessage: null,
      editedAt: null,
      deletedAt: null,
      createdAt: message.createdAt,
      reactions: const [],
      deliveredReceipts: const [],
      readReceipts: const [],
      deliveryStatus: null,
      sender: ChatMessageSender(
        id: message.senderId,
        name: message.senderLabel,
      ),
    );
  }

  MessengerDeliveryStatus _deliveryStatusFor(ChatMessage message) {
    final id = _currentUser?.id ?? '';
    if (id.isEmpty) {
      return MessengerDeliveryStatus.none;
    }
    return messengerDeliveryStatusFor(message, currentUserId: id);
  }

  String _messagePreview(ChatMessage message) {
    if (message.isDeleted) {
      return '[deleted]';
    }
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

  /// Prefer the chronologically newer row when both REST and loaded-thread
  /// messages exist (partial pagination can make `messages.last` older than
  /// [Conversation.latestMessage]).
  ChatMessage? _newestChatMessage(ChatMessage? a, ChatMessage? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a.createdAt.isBefore(b.createdAt) ? b : a;
  }

  DateTime? _newestDateTime(DateTime? a, DateTime? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a.isBefore(b) ? b : a;
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
    if (_isDraftConversationId(conversationId)) {
      return;
    }
    if (!_isSocketConnected || _client == null) {
      return;
    }
    try {
      await _client!.startTyping(conversationId);
    } catch (_) {}
  }

  Future<void> _onTypingStop(String conversationId) async {
    if (_isDraftConversationId(conversationId)) {
      return;
    }
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

  bool _canDeleteMessage(MessengerChatMessage message) {
    if (!_featureDeleteMessage || message.isDeleted) {
      return false;
    }
    return message.senderId == _currentUser?.id;
  }

  bool get _showExampleFullScreenLoader => _isLoggingOut;

  String get _exampleFullScreenLoaderMessage => 'Signing out…';

  Widget _buildExampleGlobalLoader(ColorScheme scheme) {
    if (!_showExampleFullScreenLoader) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: AbsorbPointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.78),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _exampleFullScreenLoaderMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.88),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserName = _currentUser?.displayName ?? 'Example user';
    final scheme = Theme.of(context).colorScheme;

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
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Tenant: ${_tenantScope?.tenantId ?? 'pending'}  |  '
                    'Push: ${_pushIntegrationReady ? 'on' : 'off'}  |  '
                    '$_statusText',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
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
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _session?.inbox.unreadByConversation ??
                            _preBootstrapUnread,
                        _session?.inbox.conversationOrder ?? _preBootstrapOrder,
                      ]),
                      builder: (context, child) {
                        final unreadMap =
                            (_session?.inbox.unreadByConversation ??
                                    _preBootstrapUnread)
                                .value;
                        final orderSnapshot =
                            (_session?.inbox.conversationOrder ??
                                    _preBootstrapOrder)
                                .value;
                        return MessengerChatShell(
                          composerReplyDraft: _composerReplyDraft,
                          onComposerReplyDraftChanged: (draft) => setState(
                            () => _composerReplyDraft = draft,
                          ),
                          composerFocusNode: _composerFocusNode,
                          currentUserId: _currentUser?.id ?? '',
                          currentUserName: currentUserName,
                          isListPaneRefreshing:
                              _isRefreshing || _isBootstrapping,
                          conversations: _mapConversations(
                            unreadMap,
                            orderSnapshot,
                          ),
                          users: _uiUsers,
                          selectedConversationId: _selectedConversationId,
                          messages: _activeMessages,
                          composerController: _composerController,
                          messagesScrollController: _messagesScrollController,
                          isSending: _isSending,
                          isRecording: _isRecording,
                          isConversationLoading:
                              _loadingConversationId == _selectedConversationId,
                          loadingConversationId: _loadingConversationId,
                          threadFetchLoadingMode:
                              MessengerThreadFetchLoadingMode
                                  .keepMessagesVisible,
                          onRefresh: () => _refreshAll(),
                          onLogout: () => unawaited(_logoutToConfiguration()),
                          onSelectConversation: _selectConversation,
                          onOpenDirectChat: _openDirectChat,
                          suggestedPeopleBuilder: (context, users, openDirectChat) =>
                              MessengerSuggestedPeoplePanel(
                            users: users,
                            openingUserId: _suggestedPeopleOpeningUserId,
                            onUserSelected: openDirectChat,
                            onPullToRefresh: () => _refreshAll(),
                            showSearchField: true,
                            searchQuery: _suggestedPeopleSearchQuery,
                            onSearchQueryChanged: (query) => setState(
                              () => _suggestedPeopleSearchQuery = query,
                            ),
                            noSearchResultsText:
                                'No people match "$_suggestedPeopleSearchQuery".',
                          ),
                          prepareOutgoingConversation:
                              _prepareOutgoingConversationForShell,
                          onMobileThreadClosed: _onMobileThreadClosed,
                          onSend: () => unawaited(_sendMessage()),
                          onPickImage: () {},
                          onPickAudio: () {},
                          onToggleRecording: () {
                            setState(() {
                              _isRecording = !_isRecording;
                            });
                          },
                          onPickCamera: () {},
                          onPickDocument: () {},
                          onPickVideo: () {},
                          enablePackageMediaSending: true,
                          mediaChatClient: _client,
                          mediaChatAuth: _sessionAuth,
                          mediaSenderId: _currentUser?.id,
                          onMediaSendStart: (_) {
                            setState(() {
                              _statusText = 'Uploading media...';
                            });
                          },
                          onMediaSendProgress: (messageId, progress) {
                            setState(() {
                              _statusText =
                                  'Uploading media ${(progress * 100).toStringAsFixed(0)}%';
                            });
                          },
                          onMediaSendError: (_, error) {
                            setState(() {
                              _statusText = 'Media send failed: $error';
                            });
                            _showSnack('Media send failed: $error');
                          },
                          onMediaMessageSent: (_) {
                            setState(() {
                              _statusText = 'Media sent through package flow.';
                            });
                          },
                          onMediaMessageSentForConversation:
                              (conversationId, message) {
                            _upsertMessage(
                              conversationId,
                              _mapUiMessageToBackend(conversationId, message),
                            );
                            _session?.inbox.bumpConversation(conversationId);
                            setState(() {
                              _statusText =
                                  'Media sent through package flow and list updated.';
                            });
                          },
                          onReact: _reactToMessage,
                          onRemoveReaction: _removeReactionFromMessage,
                          onDelete: _handleDelete,
                          onMarkSeen: null,
                          canDeleteMessage: _canDeleteMessage,
                          searchVisibility: MessengerSearchVisibility.always,
                          searchInputTextStyle: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          searchHintTextStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13.5,
                          ),
                          searchFieldBackgroundColor: const Color(0xFFF8FAFC),
                          searchFieldContentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          searchIconColor: const Color(0xFF64748B),
                          searchFieldBorderRadius: 12,
                          emptyConversationsMessage:
                              'No conversations yet. Use the people list to create one through the package flow.',
                          emptyUsersMessage:
                              'No users found for this tenant. Register another user from a second device or profile to test direct chat creation.',
                          remoteTypingUsers: _remoteTypingUsersForShell(),
                          onTypingStart: _onTypingStart,
                          onTypingStop: _onTypingStop,
                          enableReactions: true,
                          composerInputTextStyle: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          composerHintTextStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13.5,
                            fontStyle: FontStyle.italic,
                          ),
                          composerFieldBackgroundColor: const Color(0xFFF8FAFC),
                          composerFieldContentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          userListPadding:
                              const EdgeInsets.symmetric(vertical: 4),
                          userListItemSpacing: 8,
                          userListItemStyle: const MessengerUserListItemStyle(
                            margin: EdgeInsets.symmetric(horizontal: 2),
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            borderRadius: 14,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            _buildExampleGlobalLoader(scheme),
          ],
        ),
      ),
    );
  }
}
