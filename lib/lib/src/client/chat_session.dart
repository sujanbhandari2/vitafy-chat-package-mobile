import 'dart:async';

import 'package:dio/dio.dart';

import 'chat_auth.dart';
import 'chat_client.dart';
import 'chat_config.dart';
import 'chat_connection_state.dart';
import 'chat_repository.dart';
import 'models/tenant_user.dart';

/// High-level lifecycle: bootstrap, socket reconnect, and replaying room joins.
class ChatSession {
  ChatSession({
    required ChatServiceConfig config,
    Dio? dio,
  }) : _client = ChatClient(config: config, dio: dio) {
    _connectionSubscription = _client.connectionState.listen(
      _onConnectionState,
    );
  }

  final ChatClient _client;
  StreamSubscription<ChatConnectionState>? _connectionSubscription;

  final Set<String> _joinedConversationIds = <String>{};

  ChatClient get client => _client;
  ChatServiceConfig get config => _client.config;

  ChatTenantScope? _tenantScope;
  TenantUser? _currentUser;
  ChatAuth? _sessionAuth;

  ChatTenantScope? get tenantScope => _tenantScope;
  TenantUser? get currentUser => _currentUser;
  ChatAuth? get sessionAuth => _sessionAuth;

  void _onConnectionState(ChatConnectionState state) {
    if (state == ChatConnectionState.connected) {
      unawaited(_replayJoins());
    }
  }

  Future<void> _replayJoins() async {
    final ids = List<String>.from(_joinedConversationIds);
    for (final id in ids) {
      try {
        await _client.joinConversation(id);
      } catch (_) {
        // Room may be invalid after long disconnect; host can re-select.
      }
    }
  }

  /// Registers the chat user, then attempts socket connect. REST steps succeed
  /// even when [connect] fails; check [ChatSessionBootstrapResult.socketConnected].
  Future<ChatSessionBootstrapResult> bootstrap({
    required ChatAuth apiAuth,
    required String providerId,
    required String providerUserId,
    required String email,
    String? name,
  }) async {
    _tenantScope = await _client.getTenantScope(apiAuth);
    _currentUser = await _client.registerOrGetUser(
      apiAuth,
      providerId: providerId,
      providerUserId: providerUserId,
      email: email,
      name: name,
    );
    _sessionAuth = ChatAuth(
      apiKey: apiAuth.apiKey,
      chatUserId: _currentUser!.id,
    );

    var socketConnected = false;
    Object? connectError;
    try {
      await _client.connect(_sessionAuth!);
      socketConnected = true;
    } catch (e) {
      connectError = e;
    }

    return ChatSessionBootstrapResult(
      socketConnected: socketConnected,
      connectError: connectError,
    );
  }

  Future<void> reconnectSocket() async {
    final auth = _sessionAuth;
    if (auth == null) {
      throw StateError('ChatSession.bootstrap must complete before reconnect');
    }
    await _client.connect(auth);
  }

  Future<void> joinConversation(String conversationId) async {
    _joinedConversationIds.add(conversationId);
    await _client.joinConversation(conversationId);
  }

  Future<void> leaveConversation(String conversationId) async {
    _joinedConversationIds.remove(conversationId);
    await _client.leaveConversation(conversationId);
  }

  Future<void> dispose() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _joinedConversationIds.clear();
    await _client.dispose();
  }
}

class ChatSessionBootstrapResult {
  const ChatSessionBootstrapResult({
    required this.socketConnected,
    this.connectError,
  });

  final bool socketConnected;
  final Object? connectError;
}
