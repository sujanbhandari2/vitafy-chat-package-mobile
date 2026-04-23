class ChatAuth {
  const ChatAuth({
    required this.apiKey,
    this.chatUserId,
  });

  final String apiKey;
  final String? chatUserId;

  bool get hasChatUserId => (chatUserId ?? '').trim().isNotEmpty;

  Map<String, dynamic> toSocketAuth() {
    final auth = <String, dynamic>{
      'apiKey': apiKey,
      'xApiKey': apiKey,
    };
    if (hasChatUserId) {
      auth['userId'] = chatUserId;
      auth['chatUserId'] = chatUserId;
    }
    return auth;
  }

  Map<String, String> toApiHeaders([Map<String, String> extra = const {}]) {
    return <String, String>{
      ...extra,
      'X-Api-Key': apiKey,
    };
  }
}
