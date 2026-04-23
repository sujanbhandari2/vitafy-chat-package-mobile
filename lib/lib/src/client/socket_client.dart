import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketClient {
  SocketClient({required this.socketUrl});

  final String socketUrl;

  io.Socket? _socket;
  String? _token;

  final _eventsController = StreamController<SocketEvent>.broadcast();
  Stream<SocketEvent> get events => _eventsController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String token) async {
    if (_socket != null && _token == token && _socket!.connected) {
      return;
    }

    disconnect();
    _token = token;

    final socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _eventsController.add(const SocketEvent(type: SocketEventType.connected));
    });

    socket.onDisconnect((_) {
      _eventsController.add(
        const SocketEvent(type: SocketEventType.disconnected),
      );
    });

    socket.onConnectError((error) {
      _eventsController.add(
        SocketEvent(
          type: SocketEventType.error,
          payload: {'message': error.toString()},
        ),
      );
    });

    socket.on('message_received', (payload) {
      _eventsController.add(
        SocketEvent(type: SocketEventType.messageReceived, payload: payload),
      );
    });

    void handleReactionEvent(dynamic payload) {
      _eventsController.add(
        SocketEvent(type: SocketEventType.messageReacted, payload: payload),
      );
    }

    socket.on('message_reacted', handleReactionEvent);
    socket.on('reaction_added', handleReactionEvent);
    socket.on('reaction_updated', handleReactionEvent);

    socket.on('message_deleted', (payload) {
      _eventsController.add(
        SocketEvent(type: SocketEventType.messageDeleted, payload: payload),
      );
    });

    socket.on('message_delivered', (payload) {
      _eventsController.add(
        SocketEvent(type: SocketEventType.messageDelivered, payload: payload),
      );
    });

    socket.on('message_read', (payload) {
      _eventsController.add(
        SocketEvent(type: SocketEventType.messageRead, payload: payload),
      );
    });

    _socket = socket;
    socket.connect();
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

    final completer = Completer<T>();

    socket.emitWithAck(
      event,
      payload,
      ack: (response) {
        if (response is! Map) {
          completer.completeError(Exception('Invalid socket response'));
          return;
        }

        final responseMap = Map<String, dynamic>.from(response);
        final ok = responseMap['ok'] == true;
        if (!ok) {
          completer.completeError(
            Exception(responseMap['error']?.toString() ?? 'Socket error'),
          );
          return;
        }

        completer.complete(mapper(responseMap['data']));
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw Exception('Socket event timeout: $event'),
    );
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _token = null;
  }

  Future<void> close() async {
    disconnect();
    await _eventsController.close();
  }
}

enum SocketEventType {
  connected,
  disconnected,
  error,
  messageReceived,
  messageReacted,
  messageDeleted,
  messageDelivered,
  messageRead,
}

class SocketEvent {
  const SocketEvent({required this.type, this.payload});

  final SocketEventType type;
  final dynamic payload;
}
