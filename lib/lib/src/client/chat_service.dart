import 'package:dio/dio.dart';

import 'chat_api.dart';
import 'chat_config.dart';
import 'chat_dio.dart';
import 'chat_repository.dart';
import 'chat_repository_impl.dart';
import 'chat_socket_api.dart';
import 'socket_client.dart';

class ChatService {
  ChatService({
    required ChatServiceConfig config,
    Dio? dio,
    SocketClient? socketClient,
  })  : _config = config,
        _dio = dio ?? createChatDio(config),
        _socketClient = socketClient ??
            SocketClient(
              config: config,
              socketUrl: config.socketUrl,
            ) {
    _api = ChatApi(_dio, config);
    _socketApi = ChatSocketApi(_socketClient);
    _repository = BackendChatRepositoryImpl(_api, _socketApi);
  }

  final ChatServiceConfig _config;
  final Dio _dio;
  final SocketClient _socketClient;
  late final ChatApi _api;
  late final ChatSocketApi _socketApi;
  late final BackendChatRepositoryImpl _repository;

  ChatServiceConfig get config => _config;
  Dio get dio => _dio;
  SocketClient get socketClient => _socketClient;
  ChatApi get api => _api;
  ChatSocketApi get socketApi => _socketApi;
  ChatRepository get repository => _repository;

  Future<void> dispose() async {
    await _socketClient.close();
  }
}
