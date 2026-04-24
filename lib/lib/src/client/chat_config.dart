import 'chat_logger.dart';

class ChatServiceConfig {
  const ChatServiceConfig({
    required this.apiBaseUrl,
    required this.socketUrl,
    this.socketPath = '/socket.io/',
    this.socketTransports = const ['polling', 'websocket'],
    this.chatApiPath = '/api/v1/chat',
    this.uploadPath = '/api/upload/file',
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 20),
    this.defaultHeaders = const {'Content-Type': 'application/json'},
    this.apiLogger,
    this.socketLogger,
  });

  final String apiBaseUrl;
  final String socketUrl;
  final String socketPath;
  final List<String> socketTransports;
  final String chatApiPath;
  final String uploadPath;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final Map<String, String> defaultHeaders;
  final ChatLogger? apiLogger;
  final ChatLogger? socketLogger;

  ChatServiceConfig copyWith({
    String? apiBaseUrl,
    String? socketUrl,
    String? socketPath,
    List<String>? socketTransports,
    String? chatApiPath,
    String? uploadPath,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Map<String, String>? defaultHeaders,
    ChatLogger? apiLogger,
    ChatLogger? socketLogger,
  }) {
    return ChatServiceConfig(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      socketUrl: socketUrl ?? this.socketUrl,
      socketPath: socketPath ?? this.socketPath,
      socketTransports: socketTransports ?? this.socketTransports,
      chatApiPath: chatApiPath ?? this.chatApiPath,
      uploadPath: uploadPath ?? this.uploadPath,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      defaultHeaders: defaultHeaders ?? this.defaultHeaders,
      apiLogger: apiLogger ?? this.apiLogger,
      socketLogger: socketLogger ?? this.socketLogger,
    );
  }
}
