import 'package:dio/dio.dart';

/// Base type for recoverable and non-recoverable failures from the chat client.
sealed class ChatException implements Exception {
  const ChatException({
    required this.message,
    this.statusCode,
    this.cause,
    this.isRetryable = false,
    this.serverCode,
  });

  final String message;
  final int? statusCode;
  final Object? cause;
  final bool isRetryable;
  final String? serverCode;

  /// Unwraps a [DioException] carrying [ChatHttpException] in [DioException.error].
  static ChatHttpException? asHttp(Object? error) {
    if (error is ChatHttpException) {
      return error;
    }
    if (error is DioException && error.error is ChatHttpException) {
      return error.error as ChatHttpException;
    }
    return null;
  }

  @override
  String toString() => message;
}

/// HTTP / transport failure from the REST API.
final class ChatHttpException extends ChatException {
  const ChatHttpException({
    required super.message,
    super.statusCode,
    super.cause,
    super.isRetryable,
    super.serverCode,
    this.requestPath,
    this.dioType,
  });

  final String? requestPath;
  final DioExceptionType? dioType;

  factory ChatHttpException.fromDio(DioException e) {
    final response = e.response;
    final statusCode = response?.statusCode;
    final data = response?.data;
    String? serverMessage;
    String? serverCode;
    if (data is Map<String, dynamic>) {
      serverMessage = data['message']?.toString() ??
          data['error']?.toString() ??
          data['statusMessage']?.toString();
      serverCode = data['code']?.toString() ?? data['errorCode']?.toString();
    }
    final message = serverMessage ??
        e.message ??
        (statusCode != null ? 'Request failed ($statusCode)' : 'Request failed');
    final retryable = _isRetryableStatus(statusCode) ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
    return ChatHttpException(
      message: message,
      statusCode: statusCode,
      cause: e,
      isRetryable: retryable,
      serverCode: serverCode,
      requestPath: e.requestOptions.path,
      dioType: e.type,
    );
  }

  static bool _isRetryableStatus(int? code) {
    if (code == null) {
      return false;
    }
    return code == 408 ||
        code == 429 ||
        code == 500 ||
        code == 502 ||
        code == 503 ||
        code == 504;
  }
}

/// Socket is not connected (emit or similar).
final class ChatSocketNotConnectedException extends ChatException {
  const ChatSocketNotConnectedException({super.cause})
      : super(
          message: 'Socket is not connected',
          isRetryable: true,
        );
}

/// Ack for a socket event did not arrive in time.
final class ChatSocketAckTimeoutException extends ChatException {
  const ChatSocketAckTimeoutException({
    required this.eventName,
    super.cause,
  }) : super(
          message: 'Socket event timeout: $eventName',
          isRetryable: true,
        );

  final String eventName;
}

/// Server responded to an ack with `ok: false`.
final class ChatSocketServerAckException extends ChatException {
  const ChatSocketServerAckException({
    required super.message,
    super.cause,
  }) : super(isRetryable: false);
}

/// Failure while waiting for the initial socket connection (handshake).
final class ChatSocketHandshakeException extends ChatException {
  const ChatSocketHandshakeException({
    required super.message,
    super.cause,
    super.isRetryable = true,
  });
}

/// JSON / model parsing failed.
final class ChatModelParseException extends ChatException {
  const ChatModelParseException({
    required super.message,
    super.cause,
  }) : super(isRetryable: false);
}

/// Unexpected empty or invalid REST payload (e.g. upload returned no files).
final class ChatUnexpectedResponseException extends ChatException {
  const ChatUnexpectedResponseException({
    required super.message,
    super.cause,
  }) : super(isRetryable: false);
}
