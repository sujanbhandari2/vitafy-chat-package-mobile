import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../client/chat_auth.dart';
import '../client/chat_client.dart';
import 'push_config.dart';
import 'push_models.dart';
import 'push_parser.dart';

/// Wires [FirebaseMessaging] foreground callbacks to chat delivery ACK.
///
/// For Dart-side background handling, the host app may register once:
/// `FirebaseMessaging.onBackgroundMessage(messengerFirebaseBackgroundHandler);`
/// (optional; native Android [ChatFirebaseMessagingService] still runs for data messages).
class MessengerPushFirebaseBinding {
  MessengerPushFirebaseBinding({
    required this.gate,
    this.deliveredAckPreference =
        MessengerDeliveredAckPreference.restThenSocket,
  });

  final MessengerPushGate gate;
  final MessengerDeliveredAckPreference deliveredAckPreference;

  Future<void> Function(String token)? onFcmToken;

  StreamSubscription<RemoteMessage>? _foregroundSub;

  Future<void> attachForeground({
    required ChatClient chatClient,
    required ChatAuth chatAuth,
  }) async {
    await _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final data = flattenPushDataMap(
        Map<String, dynamic>.from(message.data),
      );
      final payload = parseMessengerPushPayload(data, gate);
      if (payload == null) {
        return;
      }
      try {
        await chatClient.markAsDeliveredPrefer(
          chatAuth,
          conversationId: payload.conversationId,
          messageId: payload.messageId,
          preference: deliveredAckPreference,
        );
      } catch (_) {
        // Best-effort; native layer may still ACK or queue.
      }
    });

    final initial = await FirebaseMessaging.instance.getToken();
    if (initial != null) {
      await onFcmToken?.call(initial);
    }
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (t) async {
        await onFcmToken?.call(t);
      },
    );
  }

  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> detach() async {
    await _foregroundSub?.cancel();
    _foregroundSub = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }
}

@pragma('vm:entry-point')
Future<void> messengerFirebaseBackgroundHandler(RemoteMessage message) async {
  // Native Android/iOS services perform HTTP ACK when configured.
  // Optionally extend this handler to enqueue work with `firebase_core` init.
}
