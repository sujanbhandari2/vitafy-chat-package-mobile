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
    this.socketAckTimeout = const Duration(seconds: 8),
    this.maxIdempotentRetries = 0,
    this.idempotentRetryBaseDelay = const Duration(milliseconds: 400),
    this.requestIdHeaderName,
    this.requestIdGenerator,
    this.verboseNetworkLogging = false,
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
  final Duration socketAckTimeout;
  final int maxIdempotentRetries;
  final Duration idempotentRetryBaseDelay;
  final String? requestIdHeaderName;
  final String Function()? requestIdGenerator;
  final bool verboseNetworkLogging;
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
    Duration? socketAckTimeout,
    int? maxIdempotentRetries,
    Duration? idempotentRetryBaseDelay,
    String? requestIdHeaderName,
    String Function()? requestIdGenerator,
    bool? verboseNetworkLogging,
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
      socketAckTimeout: socketAckTimeout ?? this.socketAckTimeout,
      maxIdempotentRetries: maxIdempotentRetries ?? this.maxIdempotentRetries,
      idempotentRetryBaseDelay:
          idempotentRetryBaseDelay ?? this.idempotentRetryBaseDelay,
      requestIdHeaderName: requestIdHeaderName ?? this.requestIdHeaderName,
      requestIdGenerator: requestIdGenerator ?? this.requestIdGenerator,
      verboseNetworkLogging:
          verboseNetworkLogging ?? this.verboseNetworkLogging,
      defaultHeaders: defaultHeaders ?? this.defaultHeaders,
      apiLogger: apiLogger ?? this.apiLogger,
      socketLogger: socketLogger ?? this.socketLogger,
    );
  }
}
