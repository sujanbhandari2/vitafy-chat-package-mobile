import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'chat_auth.dart';
import 'chat_config.dart';
import 'chat_connection_state.dart';
import 'chat_exceptions.dart';
import 'chat_logger.dart';
import 'socket_pretty_logger.dart';

class SocketClient {
  SocketClient({
    required this.socketUrl,
    required ChatServiceConfig config,
  }) : _config = config;

  final String socketUrl;
  final ChatServiceConfig _config;

  io.Socket? _socket;
  ChatAuth? _auth;

  final _eventsController = StreamController<SocketEvent>.broadcast();
  Stream<SocketEvent> get events => _eventsController.stream;

  final _connectionStateController =
      StreamController<ChatConnectionState>.broadcast();
  Stream<ChatConnectionState> get connectionState =>
      _connectionStateController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void _socketLog(
    SocketLogKind kind,
    String message, {
    Map<String, Object?>? data,
    SocketLogLevel? level,
  }) {
    final logger = _config.socketLogger;
    if (logger == null) {
      return;
    }
    final merged = <String, dynamic>{'kind': kind.name};
    if (level != null) {
      merged['level'] = level.name;
    }
    if (data != null) {
      merged.addAll(
        data.map((String k, Object? v) => MapEntry(k, v)),
      );
    }
    logger(message, data: merged);
  }

  void _emitConnection(ChatConnectionState state) {
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(state);
    }
  }

  Future<void> connect(ChatAuth auth) async {
    if (_socket != null &&
        _socket!.connected &&
        _auth?.apiKey == auth.apiKey &&
        _auth?.chatUserId == auth.chatUserId &&
        _auth?.accessToken == auth.accessToken) {
      return;
    }

    disconnect();
    _auth = auth;
    final effectiveSocketUrl = _normalizeSocketUrl(socketUrl);
    final effectiveSocketPath = _normalizeSocketPath(_config.socketPath);
    final transports = _config.socketTransports.isEmpty
        ? const ['polling', 'websocket']
        : _config.socketTransports;

    _socketLog(
      SocketLogKind.connectRequest,
      'Socket connect requested',
      data: {
        ..._sanitizedAuth(auth),
        'url': effectiveSocketUrl,
        'path': effectiveSocketPath,
        'transports': transports,
      },
    );

    _emitConnection(ChatConnectionState.connecting);

    final socket = io.io(
      effectiveSocketUrl,
      io.OptionBuilder()
          .setTransports(transports)
          .setPath(effectiveSocketPath)
          .setAuth(auth.toSocketAuth())
          .setExtraHeaders(auth.toApiHeaders())
          .enableForceNew()
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(2147483647)
          .setReconnectionDelay(750)
          .setReconnectionDelayMax(10000)
          .build(),
    );
    final connectedCompleter = Completer<void>();

    socket.onConnect((_) {
      _socketLog(
        SocketLogKind.connected,
        'Socket connected',
        data: {'id': socket.id, ..._sanitizedAuth(auth)},
      );
      _emitConnection(ChatConnectionState.connected);
      _eventsController.add(const SocketEvent(type: SocketEventType.connected));
      if (!connectedCompleter.isCompleted) {
        connectedCompleter.complete();
      }
    });

    socket.on('reconnect_attempt', (dynamic data) {
      _socketLog(
        SocketLogKind.reconnectAttempt,
        'Socket reconnect attempt',
        data: {
          if (data != null) 'payload': data,
        },
      );
      _emitConnection(ChatConnectionState.reconnecting);
    });
    socket.on('reconnect', (dynamic data) {
      _socketLog(
        SocketLogKind.reconnect,
        'Socket reconnected',
        data: {
          if (data != null) 'payload': data,
        },
      );
      _emitConnection(ChatConnectionState.connected);
    });
    socket.on('reconnect_failed', (dynamic data) {
      _socketLog(
        SocketLogKind.reconnectFailed,
        'Socket reconnect failed',
        data: {
          if (data != null) 'payload': data,
        },
        level: SocketLogLevel.warn,
      );
      _emitConnection(ChatConnectionState.failed);
    });

    socket.onDisconnect((reason) {
      _socketLog(
        SocketLogKind.disconnect,
        'Socket disconnected',
        data: {'reason': reason},
      );
      if (connectedCompleter.isCompleted) {
        _emitConnection(ChatConnectionState.disconnected);
      }
      _eventsController.add(
        SocketEvent(
          type: SocketEventType.disconnected,
          payload: {'reason': reason},
        ),
      );
      if (!connectedCompleter.isCompleted) {
        connectedCompleter.completeError(
          ChatSocketHandshakeException(
            message: 'Socket disconnected before connect: $reason',
          ),
        );
      }
    });

    socket.onConnectError((error) {
      _socketLog(
        SocketLogKind.connectError,
        'Socket connect error',
        data: {'error': error.toString()},
        level: SocketLogLevel.error,
      );
      _eventsController.add(
        SocketEvent(
          type: SocketEventType.error,
          payload: {'message': error.toString()},
        ),
      );
      if (!connectedCompleter.isCompleted) {
        connectedCompleter.completeError(
          ChatSocketHandshakeException(
            message: 'Socket connect error: ${error.toString()}',
            cause: error,
          ),
        );
      }
    });

    socket.onError((error) {
      _socketLog(
        SocketLogKind.socketError,
        'Socket error',
        data: {'error': error.toString()},
        level: SocketLogLevel.error,
      );
      _eventsController.add(
        SocketEvent(
          type: SocketEventType.error,
          payload: {'message': error.toString()},
        ),
      );
      if (!connectedCompleter.isCompleted) {
        connectedCompleter.completeError(
          ChatSocketHandshakeException(
            message: 'Socket error before connect: ${error.toString()}',
            cause: error,
          ),
        );
      }
    });

    _registerEvent(socket, 'message', SocketEventType.messageReceived);
    _registerEvent(socket, 'message_received', SocketEventType.messageReceived);
    _registerEvent(socket, 'reaction_added', SocketEventType.messageReacted);
    _registerEvent(socket, 'message_reacted', SocketEventType.messageReacted);
    _registerEvent(socket, 'reaction_removed', SocketEventType.reactionRemoved);
    _registerEvent(
        socket, 'message_delivered', SocketEventType.messageDelivered);
    _registerEvent(socket, 'message_read', SocketEventType.messageRead);
    _registerEvent(socket, 'user_typing', SocketEventType.userTyping);
    _registerEvent(
      socket,
      'user_stopped_typing',
      SocketEventType.userStoppedTyping,
    );
    _registerEvent(socket, 'user_online', SocketEventType.userOnline);
    _registerEvent(socket, 'user_offline', SocketEventType.userOffline);

    _socket = socket;
    socket.connect();

    try {
      await connectedCompleter.future.timeout(
        _config.connectTimeout,
        onTimeout: () {
          _socketLog(
            SocketLogKind.connectTimeout,
            'Socket connect timeout after ${_config.connectTimeout.inSeconds}s',
            data: {'url': effectiveSocketUrl, 'path': effectiveSocketPath},
            level: SocketLogLevel.error,
          );
          throw ChatSocketHandshakeException(
            message:
                'Socket connect timeout after ${_config.connectTimeout.inSeconds}s',
          );
        },
      );
    } catch (e) {
      // Handshake failures are already logged via connectError / disconnect / onError;
      // connectTimeout is logged in [onTimeout]. Only log unexpected errors here.
      if (e is! ChatSocketHandshakeException) {
        _socketLog(
          SocketLogKind.connectFailed,
          'Socket connect failed: $e',
          data: {'error': e.toString()},
          level: SocketLogLevel.error,
        );
      }
      _emitConnection(ChatConnectionState.failed);
      if (identical(_socket, socket)) {
        socket.disconnect();
        socket.dispose();
        _socket = null;
        _auth = null;
      }
      rethrow;
    }
  }

  Future<T> emitWithAck<T>(
    String event,
    Map<String, dynamic> payload,
    T Function(dynamic rawData) mapper,
  ) async {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      throw const ChatSocketNotConnectedException();
    }

    _socketLog(
      SocketLogKind.emit,
      'Socket emit',
      data: {'event': event, 'payload': payload},
    );

    final completer = Completer<T>();
    var settled = false;

    void onException(dynamic err) {
      if (settled) {
        return;
      }
      settled = true;
      socket.off('exception', onException);
      final msg = _formatNestExceptionPayload(err);
      _socketLog(
        SocketLogKind.exception,
        'Socket exception',
        data: {'event': event, 'payload': err},
        level: SocketLogLevel.error,
      );
      if (!completer.isCompleted) {
        completer.completeError(
          ChatSocketNestException(message: msg, rawPayload: err),
        );
      }
    }

    socket.once('exception', onException);

    socket.emitWithAck(
      event,
      payload,
      ack: (response) {
        if (settled) {
          return;
        }
        settled = true;
        socket.off('exception', onException);
        _socketLog(
          SocketLogKind.ack,
          'Socket ack',
          data: {'event': event, 'response': response},
        );

        try {
          final data = _unwrapAck(response);
          if (!completer.isCompleted) {
            completer.complete(mapper(data));
          }
        } catch (error, stackTrace) {
          if (error is ChatSocketServerAckException) {
            completer.completeError(error, stackTrace);
          } else if (error is FormatException || error is TypeError) {
            completer.completeError(
              ChatModelParseException(
                message: error.toString(),
                cause: error,
              ),
              stackTrace,
            );
          } else {
            completer.completeError(error, stackTrace);
          }
        }
      },
    );

    try {
      return await completer.future.timeout(
        _config.socketAckTimeout,
        onTimeout: () {
          if (!settled) {
            settled = true;
            socket.off('exception', onException);
          }
          _socketLog(
            SocketLogKind.ackTimeout,
            'Socket ack timeout',
            data: {'event': event},
            level: SocketLogLevel.error,
          );
          throw ChatSocketAckTimeoutException(eventName: event);
        },
      );
    } catch (e) {
      if (!settled) {
        settled = true;
        socket.off('exception', onException);
      }
      rethrow;
    }
  }

  static String _formatNestExceptionPayload(Object? payload) {
    if (payload == null) {
      return 'Socket server error';
    }
    if (payload is String) {
      return payload.trim().isEmpty ? 'Socket server error' : payload;
    }
    if (payload is List) {
      final parts = payload.map(_formatNestExceptionPayload).where((s) => s.isNotEmpty);
      final joined = parts.join('; ');
      return joined.isEmpty ? 'Socket server error' : joined;
    }
    if (payload is Map) {
      final m = payload['message'];
      if (m is String && m.trim().isNotEmpty) {
        return m;
      }
    }
    return payload.toString();
  }

  void disconnect() {
    if (_socket != null) {
      _socketLog(SocketLogKind.clientDisconnect, 'Socket client disconnect()');
    }
    _emitConnection(ChatConnectionState.disconnected);
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _auth = null;
  }

  Future<void> close() async {
    disconnect();
    await _eventsController.close();
    await _connectionStateController.close();
  }

  void _registerEvent(io.Socket socket, String event, SocketEventType type) {
    socket.on(event, (payload) {
      _socketLog(
        SocketLogKind.inbound,
        'Socket inbound event',
        data: {'event': event, 'payload': payload},
      );
      _eventsController.add(SocketEvent(type: type, payload: payload));
    });
  }

  dynamic _unwrapAck(dynamic response) {
    if (response is Map) {
      final responseMap = Map<String, dynamic>.from(response);
      if (responseMap['ok'] == false) {
        throw ChatSocketServerAckException(
          message: responseMap['error']?.toString() ?? 'Socket error',
        );
      }
      if (responseMap.containsKey('data')) {
        return responseMap['data'];
      }
    }
    return response;
  }

  Map<String, Object?> _sanitizedAuth(ChatAuth auth) {
    return {
      'apiKey': redactApiKey(auth.apiKey),
      'chatUserId': auth.chatUserId,
      'hasChatUserToken': auth.hasChatUserAccessToken,
    };
  }

  String _normalizeSocketUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return trimmed;
    }

    // Allow host:port input by assuming http.
    if (!uri.hasScheme && uri.host.isEmpty) {
      uri = Uri.tryParse('http://$trimmed') ?? uri;
    }

    if (uri.host.isEmpty) {
      return trimmed;
    }

    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  String _normalizeSocketPath(String rawPath) {
    var path = rawPath.trim();
    if (path.isEmpty) {
      path = '/socket.io/';
    }
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    if (!path.endsWith('/')) {
      path = '$path/';
    }
    return path;
  }
}

enum SocketEventType {
  connected,
  disconnected,
  error,
  messageReceived,
  messageReacted,
  reactionRemoved,
  messageDelivered,
  messageRead,
  userTyping,
  userStoppedTyping,
  userOnline,
  userOffline,
}

class SocketEvent {
  const SocketEvent({required this.type, this.payload});

  final SocketEventType type;
  final dynamic payload;
}
