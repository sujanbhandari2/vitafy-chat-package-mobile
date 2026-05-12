import 'package:dio/dio.dart';

import 'chat_auth.dart';
import 'chat_api.dart';
import 'chat_config.dart';
import 'chat_connection_state.dart';
import 'chat_dio.dart';
import 'chat_repository.dart';
import 'chat_repository_impl.dart';
import 'chat_socket_api.dart';
import 'models/conversation.dart';
import 'socket_client.dart';

class ChatService {
  ChatService({
    required ChatServiceConfig config,
    Dio? dio,
    SocketClient? socketClient,
    ChatRepository? repository,
  })  : _config = config,
        _dio = dio ?? createChatDio(config),
        _socketClient = socketClient ??
            SocketClient(
              config: config,
              socketUrl: config.socketUrl,
            ) {
    _api = ChatApi(_dio, config);
    _socketApi = ChatSocketApi(_socketClient);
    _repository = repository ?? BackendChatRepositoryImpl(_api, _socketApi);
    _directConversationResolver = ChatDirectConversationResolver(_repository);
  }

  final ChatServiceConfig _config;
  final Dio _dio;
  final SocketClient _socketClient;
  late final ChatApi _api;
  late final ChatSocketApi _socketApi;
  late final ChatRepository _repository;
  late final ChatDirectConversationResolver _directConversationResolver;

  ChatServiceConfig get config => _config;
  Dio get dio => _dio;
  SocketClient get socketClient => _socketClient;
  ChatApi get api => _api;
  ChatSocketApi get socketApi => _socketApi;
  ChatRepository get repository => _repository;
  ChatDirectConversationResolver get directConversationResolver =>
      _directConversationResolver;

  Stream<ChatConnectionState> get connectionState =>
      _socketClient.connectionState;

  Future<void> dispose() async {
    await _socketClient.close();
  }
}

/// Result of resolving a direct conversation for two chat users.
class ChatDirectConversationResolution {
  const ChatDirectConversationResolution({
    required this.conversation,
    required this.created,
  });

  final Conversation conversation;
  final bool created;
}

/// Resolves an existing direct conversation or creates one when missing.
class ChatDirectConversationResolver {
  const ChatDirectConversationResolver(this._repository);

  final ChatRepository _repository;

  Future<ChatDirectConversationResolution> resolve({
    required ChatAuth auth,
    required String currentUserId,
    required String peerUserId,
    List<Conversation>? seedConversations,
  }) async {
    final selfId = currentUserId.trim();
    final targetId = peerUserId.trim();
    if (selfId.isEmpty || targetId.isEmpty) {
      throw ArgumentError(
        'currentUserId and peerUserId must both be non-empty.',
      );
    }
    if (selfId == targetId) {
      throw ArgumentError('currentUserId and peerUserId must be different.');
    }

    final conversations = seedConversations ??
        await _repository.getConversations(auth, forUserId: selfId);
    final existing = _findDirectConversation(
      conversations: conversations,
      currentUserId: selfId,
      peerUserId: targetId,
    );
    if (existing != null) {
      return ChatDirectConversationResolution(
        conversation: existing,
        created: false,
      );
    }

    final created = await _repository.createConversation(
      auth,
      type: 'DIRECT',
      participantIds: [selfId, targetId],
    );
    return ChatDirectConversationResolution(
      conversation: created,
      created: true,
    );
  }

  static Conversation? _findDirectConversation({
    required List<Conversation> conversations,
    required String currentUserId,
    required String peerUserId,
  }) {
    for (final conversation in conversations) {
      if (!_isDirectConversation(conversation)) {
        continue;
      }
      final participantIds =
          conversation.participants.map((p) => p.userId.trim()).toSet();
      if (participantIds.contains(currentUserId) &&
          participantIds.contains(peerUserId)) {
        return conversation;
      }
    }
    return null;
  }

  static bool _isDirectConversation(Conversation conversation) {
    return conversation.type.trim().toUpperCase() == 'DIRECT';
  }
}
