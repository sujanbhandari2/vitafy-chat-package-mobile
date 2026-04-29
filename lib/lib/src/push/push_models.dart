/// Normalized chat payload extracted from FCM/APNs data maps.
class MessengerPushPayload {
  const MessengerPushPayload({
    required this.messageId,
    required this.conversationId,
    this.tenantId,
    this.senderId,
    this.raw = const {},
  });

  final String messageId;
  final String conversationId;
  final String? tenantId;
  final String? senderId;
  final Map<String, dynamic> raw;
}

/// Events emitted from native bridge or parsed in Dart.
enum MessengerPushEventKind {
  incomingChatMessage,
  fcmTokenRefresh,
  unknown,
}

class MessengerPushEvent {
  const MessengerPushEvent({
    required this.kind,
    this.conversationId,
    this.messageId,
    this.token,
    this.nativeAckSucceeded,
    this.raw = const {},
  });

  final MessengerPushEventKind kind;
  final String? conversationId;
  final String? messageId;
  final String? token;
  final bool? nativeAckSucceeded;
  final Map<String, dynamic> raw;

  factory MessengerPushEvent.fromNativeMap(Map<String, dynamic> map) {
    final kindStr = map['kind']?.toString() ?? '';
    if (kindStr == 'incoming_chat_message') {
      return MessengerPushEvent(
        kind: MessengerPushEventKind.incomingChatMessage,
        conversationId: map['conversationId']?.toString(),
        messageId: map['messageId']?.toString(),
        nativeAckSucceeded: map['nativeAckSucceeded'] == true,
        raw: map,
      );
    }
    if (kindStr == 'fcm_token_refresh') {
      return MessengerPushEvent(
        kind: MessengerPushEventKind.fcmTokenRefresh,
        token: map['token']?.toString(),
        raw: map,
      );
    }
    return MessengerPushEvent(kind: MessengerPushEventKind.unknown, raw: map);
  }
}

/// How Dart should ACK delivered when the app is running.
enum MessengerDeliveredAckPreference {
  /// Try REST first, then socket ([ChatRepository.markAsDelivered]).
  restThenSocket,

  /// Socket only (legacy behavior).
  socketOnly,
}
