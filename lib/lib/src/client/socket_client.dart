import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'chat_auth.dart';
import 'chat_config.dart';
import 'chat_logger.dart';

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

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(ChatAuth auth) async {
    if (_socket != null &&
        _socket!.connected &&
        _auth?.apiKey == auth.apiKey &&
        _auth?.chatUserId == auth.chatUserId) {
      return;
    }

    disconnect();
    _auth = auth;
    final effectiveSocketUrl = _normalizeSocketUrl(socketUrl);
    final effectiveSocketPath = _normalizeSocketPath(_config.socketPath);
    final transports = _config.socketTransports.isEmpty
        ? const ['polling', 'websocket']
        : _config.socketTransports;

    _config.socketLogger?.call(
      'Socket connect requested',
      data: {
        ..._sanitizedAuth(auth),
        'url': effectiveSocketUrl,
        'path': effectiveSocketPath,
        'transports': transports,
      },
    );

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
      _config.socketLogger?.call(
        'Socket connected',
        data: {'id': socket.id, ..._sanitizedAuth(auth)},
      );
      _eventsController.add(const SocketEvent(type: SocketEventType.connected));
      if (!connectedCompleter.isCompleted) {
        connectedCompleter.complete();
      }
    });

    socket.onDisconnect((reason) {
      _config.socketLogger?.call(
        'Socket disconnected',
        data: {'reason': reason},
      );
      _eventsController.add(
        SocketEvent(
          type: SocketEventType.disconnected,
          payload: {'reason': reason},
        ),
      );
      if (!connectedCompleter.isCompleted) {
        connectedCompleter.completeError(
          Exception('Socket disconnected before connect: $reason'),
        );
      }
    });

    socket.onConnectError((error) {
      _config.socketLogger?.call(
        'Socket connect error',
        data: {'error': error.toString()},
      );
      _eventsController.add(
        SocketEvent(
          type: SocketEventType.error,
          payload: {'message': error.toString()},
        ),
      );
      if (!connectedCompleter.isCompleted) {
        connectedCompleter.completeError(
          Exception('Socket connect error: ${error.toString()}'),
        );
      }
    });

    socket.onError((error) {
      _config.socketLogger?.call(
        'Socket error',
        data: {'error': error.toString()},
      );
      _eventsController.add(
        SocketEvent(
          type: SocketEventType.error,
          payload: {'message': error.toString()},
        ),
      );
      if (!connectedCompleter.isCompleted) {
        connectedCompleter.completeError(
          Exception('Socket error before connect: ${error.toString()}'),
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
        onTimeout: () => throw Exception(
          'Socket connect timeout after ${_config.connectTimeout.inSeconds}s',
        ),
      );
    } catch (_) {
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
      throw Exception('Socket is not connected');
    }

    _config.socketLogger?.call(
      'Socket emit',
      data: {'event': event, 'payload': payload},
    );

    final completer = Completer<T>();

    socket.emitWithAck(
      event,
      payload,
      ack: (response) {
        _config.socketLogger?.call(
          'Socket ack',
          data: {'event': event, 'response': response},
        );

        try {
          final data = _unwrapAck(response);
          completer.complete(mapper(data));
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw Exception('Socket event timeout: $event'),
    );
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _auth = null;
  }

  Future<void> close() async {
    disconnect();
    await _eventsController.close();
  }

  void _registerEvent(io.Socket socket, String event, SocketEventType type) {
    socket.on(event, (payload) {
      _config.socketLogger?.call(
        'Socket event',
        data: {'event': event, 'payload': payload},
      );
      _eventsController.add(SocketEvent(type: type, payload: payload));
    });
  }

  dynamic _unwrapAck(dynamic response) {
    if (response is Map) {
      final responseMap = Map<String, dynamic>.from(response);
      if (responseMap['ok'] == false) {
        throw Exception(responseMap['error']?.toString() ?? 'Socket error');
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
