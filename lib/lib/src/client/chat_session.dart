import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

import 'chat_auth.dart';
import 'chat_client.dart';
import 'chat_config.dart';
import 'chat_exceptions.dart';
import 'chat_repository.dart';
import 'inbox/chat_inbox_controller.dart';
import 'models/tenant_user.dart';
import 'presence/presence_config.dart';
import 'presence/presence_controller.dart';
import 'presence/presence_snapshot.dart';
import 'presence/remote_presence_store.dart';

/// High-level lifecycle: bootstrap, socket reconnect, and inbox room policy.
class ChatSession {
  ChatSession({
    required ChatServiceConfig config,
    Dio? dio,
    PresenceConfig? presenceConfig,
  })  : _client = ChatClient(config: config, dio: dio),
        _presenceConfig = presenceConfig ?? const PresenceConfig();

  final ChatClient _client;
  final PresenceConfig _presenceConfig;

  ChatInboxController? _inbox;
  PresenceController? _presenceController;
  RemotePresenceStore? _remotePresenceStore;
  StreamSubscription<ChatSocketEvent>? _remotePresenceSubscription;

  ChatClient get client => _client;
  ChatServiceConfig get config => _client.config;

  ChatTenantScope? _tenantScope;
  TenantUser? _currentUser;
  ChatAuth? _sessionAuth;

  ChatTenantScope? get tenantScope => _tenantScope;
  TenantUser? get currentUser => _currentUser;
  ChatAuth? get sessionAuth => _sessionAuth;

  /// Snapshot of the local user's own presence intent/state.
  ///
  /// Available after [bootstrap].
  ValueListenable<PresenceSnapshot> get ownPresence {
    final p = _presenceController;
    if (p == null) {
      throw StateError(
        'ChatSession.ownPresence is only available after bootstrap.',
      );
    }
    return p.presence;
  }

  /// Other users' online/offline status based on socket presence events.
  ///
  /// Available after [bootstrap].
  RemotePresenceStore get remotePresence {
    final s = _remotePresenceStore;
    if (s == null) {
      throw StateError(
        'ChatSession.remotePresence is only available after bootstrap.',
      );
    }
    return s;
  }

  /// Forward host app lifecycle transitions into the SDK presence state machine.
  ///
  /// Hosts typically do this by mounting [`MessengerPresenceScope`].
  void handleAppLifecycleState(AppLifecycleState state) {
    _presenceController?.handleLifecycleState(state);
  }

  /// Inbox unread + receipt policy; available after [bootstrap].
  ChatInboxController get inbox {
    final i = _inbox;
    if (i == null) {
      throw StateError(
        'ChatSession.bootstrap must complete before using inbox.',
      );
    }
    return i;
  }

  /// Registers the chat user, then connects the socket.
  ///
  /// REST steps succeed before the socket runs. When [awaitSocketConnect] is
  /// `false`, the socket handshake runs in the background; use
  /// [ChatClient.connectionState] / socket events for readiness and treat
  /// [ChatSessionBootstrapResult.socketConnectPending] as true.
  Future<ChatSessionBootstrapResult> bootstrap({
    required ChatAuth apiAuth,
    String? externalTenantId,
    String? externalUserId,
    @Deprecated('Use externalTenantId') String? providerId,
    @Deprecated('Use externalUserId') String? providerUserId,
    String? externalUserRole,
    String? email,
    String? name,
    String? profile,
    bool awaitSocketConnect = true,
  }) async {
    await _inbox?.dispose();
    _inbox = null;

    _tenantScope = await _client.getTenantScope(apiAuth);
    _currentUser = await _client.registerOrGetUser(
      apiAuth,
      externalTenantId: externalTenantId,
      externalUserId: externalUserId,
      providerId: providerId,
      providerUserId: providerUserId,
      externalUserRole: externalUserRole,
      email: email,
      name: name,
      profile: profile,
    );
    final accessToken = (_currentUser!.accessToken ?? '').trim();
    if (accessToken.isEmpty) {
      throw const ChatUnexpectedResponseException(
        message:
            'POST /chat/users did not return accessToken; cannot authenticate chat REST or socket.',
      );
    }
    final chatUserId = _currentUser!.id.trim();
    if (chatUserId.isEmpty || !RegExp(r'^\d+$').hasMatch(chatUserId)) {
      throw ChatUnexpectedResponseException(
        message:
            'POST /chat/users did not return a numeric ChatUser id; got "${_currentUser!.id}". '
            'Socket auth.auth.userId must match JWT claim chatUserId (see WIDGET_CLIENT_PARITY.md).',
      );
    }
    _sessionAuth = ChatAuth(
      apiKey: apiAuth.apiKey,
      chatUserId: chatUserId,
      accessToken: accessToken,
    );

    _inbox = ChatInboxController(
      client: _client,
      currentUserId: _currentUser!.id,
    );

    _remotePresenceStore = RemotePresenceStore(
      currentUserId: _currentUser!.id,
    );
    _remotePresenceSubscription = _client.events.listen(
      (event) {
        final presence = event.presence;
        if (presence == null) {
          return;
        }
        switch (event.type) {
          case ChatSocketEventType.userOnline:
            _remotePresenceStore?.applyUserOnline(presence);
            break;
          case ChatSocketEventType.userOffline:
            _remotePresenceStore?.applyUserOffline(presence);
            break;
          default:
            break;
        }
      },
      onError: (_) {},
    );

    _presenceController = PresenceController(
      config: _presenceConfig,
      // The connection listener is the canonical truth for reconnect.
      connectionStateStream: _client.connectionState,
      reconnectSocket: reconnectSocket,
      disconnectSocket: _client.disconnect,
      emitGoingOffline: (reason) async {
        _client.emitGoingOffline(
          userId: _currentUser!.id,
          reason: reason,
        );
      },
      now: DateTime.now,
    );

    var socketConnected = false;
    Object? connectError;
    var socketConnectPending = false;

    if (awaitSocketConnect) {
      try {
        await _client.connect(_sessionAuth!);
        socketConnected = true;
      } catch (e) {
        connectError = e;
      }
    } else {
      socketConnectPending = true;
      unawaited(
        _client.connect(_sessionAuth!).onError((_, __) {}),
      );
    }

    _presenceController?.onSessionReady(socketConnected: socketConnected);

    return ChatSessionBootstrapResult(
      socketConnected: socketConnected,
      connectError: connectError,
      socketConnectPending: socketConnectPending,
    );
  }

  Future<void> reconnectSocket() async {
    final auth = _sessionAuth;
    if (auth == null) {
      throw StateError('ChatSession.bootstrap must complete before reconnect');
    }
    await _client.connect(auth);
  }

  /// Activates [conversationId]: leaves the previous room and joins the socket room.
  ///
  /// [markConversationRead] runs when the host sets [ChatInboxController.setThreadVisible]
  /// to `true` for the open thread (see [MessengerChatShell.onThreadVisibilityChanged]).
  Future<void> joinConversation(String conversationId) async {
    await inbox.setActiveConversation(conversationId);
  }

  /// Reports whether the message thread is visible (open on screen).
  Future<void> setThreadVisible(bool visible) {
    return inbox.setThreadVisible(visible);
  }

  Future<void> leaveConversation(String conversationId) async {
    final id = conversationId.trim();
    if (id.isEmpty) {
      return;
    }
    if (_inbox?.activeConversationId == id) {
      await _inbox!.setActiveConversation(null);
    } else {
      await _client.leaveConversation(id);
    }
  }

  /// Best-effort local offline transition (and then disconnect).
  ///
  /// Hosts should typically call this instead of directly calling [dispose].
  Future<void> logout() async {
    await _presenceController?.goOffline('logout');
    await dispose();
  }

  Future<void> dispose() async {
    await _presenceController?.goOffline('dispose');
    _presenceController?.dispose();
    _presenceController = null;

    await _remotePresenceSubscription?.cancel();
    _remotePresenceSubscription = null;
    _remotePresenceStore?.dispose();
    _remotePresenceStore = null;

    await _inbox?.dispose();
    _inbox = null;
    await _client.dispose();
  }
}

class ChatSessionBootstrapResult {
  const ChatSessionBootstrapResult({
    required this.socketConnected,
    this.connectError,
    this.socketConnectPending = false,
  });

  /// Whether the socket was connected when [ChatSession.bootstrap] returned.
  final bool socketConnected;

  /// Set when [ChatSession.bootstrap] was asked to await the handshake; then
  /// holds the error from [ChatClient.connect], if any.
  final Object? connectError;

  /// True when the socket connect was started but not awaited (see
  /// [ChatSession.bootstrap] `awaitSocketConnect: false`).
  final bool socketConnectPending;
}
