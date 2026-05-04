import 'dart:convert';

import 'chat_exceptions.dart';

class ChatAuth {
  const ChatAuth({
    required this.apiKey,
    this.chatUserId,
    this.accessToken,
  });

  final String apiKey;
  final String? chatUserId;

  /// Chat-user JWT from `POST /api/v1/chat/users` (`accessToken` in the response).
  /// Required with [chatUserId] for guarded REST and a full socket session.
  final String? accessToken;

  String get normalizedApiKey => apiKey.trim();

  String get normalizedChatUserId => (chatUserId ?? '').trim();

  String get normalizedAccessToken => _stripBearerPrefix(accessToken ?? '');

  bool get hasChatUserId => normalizedChatUserId.isNotEmpty;

  bool get hasChatUserAccessToken => normalizedAccessToken.isNotEmpty;

  bool get hasFullChatUserAuth => hasChatUserId && hasChatUserAccessToken;

  void validateForSocketConnect() {
    if (normalizedApiKey.isEmpty) {
      throw const ChatSocketAuthException(
        message:
            'Socket API key is required. Pass accessKey:secretKey in ChatAuth.apiKey.',
      );
    }
    if (hasChatUserId && !hasChatUserAccessToken) {
      throw const ChatSocketAuthException(
        message:
            'Socket auth userId/chatUserId requires a chat-user JWT. Supply ChatAuth.accessToken or omit chatUserId for an API-key-only connection.',
      );
    }
    if (!hasChatUserId && hasChatUserAccessToken) {
      throw const ChatSocketAuthException(
        message:
            'Socket auth token/accessToken requires chatUserId. Supply the numeric chat profile id that matches the JWT claim chatUserId.',
      );
    }
    if (!hasFullChatUserAuth) {
      return;
    }
    final jwtChatUserId = _readChatUserIdFromJwt(normalizedAccessToken);
    if (jwtChatUserId != null && jwtChatUserId != normalizedChatUserId) {
      throw ChatSocketAuthException(
        message:
            'Socket auth chatUserId "$normalizedChatUserId" does not match JWT claim chatUserId "$jwtChatUserId".',
      );
    }
  }

  void validateForSocketAction(String eventName) {
    validateForSocketConnect();
    if (!hasFullChatUserAuth) {
      throw ChatSocketAuthException(
        message:
            'Socket event "$eventName" requires both chatUserId and chat-user JWT. Reconnect with full chat auth before using realtime chat actions.',
      );
    }
  }

  Map<String, dynamic> toSocketAuth() {
    final auth = <String, dynamic>{
      'apiKey': normalizedApiKey,
      'xApiKey': normalizedApiKey,
    };
    if (hasChatUserId) {
      auth['userId'] = normalizedChatUserId;
      auth['chatUserId'] = normalizedChatUserId;
    }
    if (hasChatUserAccessToken) {
      auth['token'] = normalizedAccessToken;
      auth['accessToken'] = normalizedAccessToken;
    }
    return auth;
  }

  /// REST headers. Set [includeChatUserBearer] to false for API-key-only routes
  /// (`GET .../tenant`, `POST .../users`, upload).
  Map<String, String> toApiHeaders({
    Map<String, String> extra = const {},
    bool includeChatUserBearer = true,
  }) {
    final headers = <String, String>{
      ...extra,
      'X-Api-Key': normalizedApiKey,
    };
    if (includeChatUserBearer) {
      if (hasChatUserAccessToken) {
        headers['Authorization'] = 'Bearer $normalizedAccessToken';
      }
    }
    return headers;
  }

  /// HTTP headers for Socket.IO Engine.IO handshake.
  ///
  /// Same as [toApiHeaders] plus an `auth` header mirroring `Authorization`
  /// when a chat-user JWT is present, for backends that read `handshake.headers.auth`.
  Map<String, String> toSocketHandshakeHeaders({
    Map<String, String> extra = const {},
  }) {
    final headers = Map<String, String>.from(toApiHeaders(extra: extra));
    final authorization = headers['Authorization'];
    if (authorization != null && authorization.trim().isNotEmpty) {
      headers['auth'] = authorization;
    }
    return headers;
  }
}

String? _readChatUserIdFromJwt(String token) {
  final normalizedToken = _stripBearerPrefix(token);
  final parts = normalizedToken.split('.');
  if (parts.length < 2) {
    return null;
  }
  var segment = parts[1];
  switch (segment.length % 4) {
    case 2:
      segment = '$segment==';
      break;
    case 3:
      segment = '$segment=';
      break;
    default:
      break;
  }
  try {
    final decoded = utf8.decode(base64Url.decode(segment));
    final raw = jsonDecode(decoded);
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    for (final key in ['chatUserId', 'chat_user_id', 'sub']) {
      final value = map[key];
      if (value == null) {
        continue;
      }
      final normalized = value.toString().trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

String _stripBearerPrefix(String raw) {
  final trimmed = raw.trim();
  const prefix = 'bearer ';
  if (trimmed.length > prefix.length &&
      trimmed.toLowerCase().startsWith(prefix)) {
    return trimmed.substring(prefix.length).trim();
  }
  return trimmed;
}
