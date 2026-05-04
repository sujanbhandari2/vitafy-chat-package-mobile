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

  bool get hasChatUserId => (chatUserId ?? '').trim().isNotEmpty;

  bool get hasChatUserAccessToken => (accessToken ?? '').trim().isNotEmpty;

  Map<String, dynamic> toSocketAuth() {
    final auth = <String, dynamic>{
      'apiKey': apiKey,
      'xApiKey': apiKey,
    };
    if (hasChatUserId) {
      auth['userId'] = chatUserId;
      auth['chatUserId'] = chatUserId;
    }
    final token = (accessToken ?? '').trim();
    if (token.isNotEmpty) {
      auth['token'] = token;
      auth['accessToken'] = token;
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
      'X-Api-Key': apiKey,
    };
    if (includeChatUserBearer) {
      final token = (accessToken ?? '').trim();
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }
}
