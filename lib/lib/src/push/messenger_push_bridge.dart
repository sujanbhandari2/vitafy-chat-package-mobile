import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../client/chat_auth.dart';
import '../client/chat_config.dart';
import 'push_models.dart';

/// Bridges native FCM handling with Dart via [MethodChannel] / [EventChannel].
class HealthMessengerPush {
  HealthMessengerPush._();

  static final HealthMessengerPush instance = HealthMessengerPush._();

  static const MethodChannel _methodChannel =
      MethodChannel('health_messenger_ui/push');
  static const EventChannel _eventChannel =
      EventChannel('health_messenger_ui/push_events');

  final StreamController<MessengerPushEvent> _events =
      StreamController<MessengerPushEvent>.broadcast();

  StreamSubscription<dynamic>? _nativeSubscription;
  bool _listening = false;

  Stream<MessengerPushEvent> get events => _events.stream;

  /// Subscribes to native push events (token refresh, incoming message metadata).
  Future<void> startListening() async {
    if (_listening) {
      return;
    }
    _listening = true;
    _nativeSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          _events.add(MessengerPushEvent.fromNativeMap(map));
        }
      },
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('HealthMessengerPush event stream error: $e $st');
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    _listening = false;
  }

  /// Persists REST + gate settings for native background delivered ACK.
  ///
  /// [deliveredPathTemplate] is appended after [ChatServiceConfig.chatApiPath]
  /// and supports `{conversationId}` and `{messageId}` placeholders, matching
  /// native [PushConfigSnapshot.buildDeliveredUrl] behavior.
  Future<void> syncNativePushConfig({
    required ChatServiceConfig config,
    required ChatAuth auth,
    String? deliveredPathTemplate,
    String chatTypeDataKey = 'type',
    String chatTypeValue = 'CHAT_MESSAGE',
  }) async {
    var pathTemplate = deliveredPathTemplate?.trim() ?? '';
    if (pathTemplate.isEmpty) {
      pathTemplate = config.deliveredReceiptRestPath.startsWith('/')
          ? config.deliveredReceiptRestPath
          : '/${config.deliveredReceiptRestPath}';
    }
    final headers = auth.toApiHeaders(extra: config.defaultHeaders);
    await _methodChannel.invokeMethod<void>('syncPushConfig', <String, dynamic>{
      'apiBaseUrl': config.apiBaseUrl,
      'chatApiPath': config.chatApiPath,
      'deliveredPathTemplate': pathTemplate,
      'headersJson': jsonEncode(headers),
      'chatTypeDataKey': chatTypeDataKey,
      'chatTypeValue': chatTypeValue,
    });
  }

  /// Retries pending native delivered ACK jobs (also triggered after auth refresh).
  Future<int> drainNativeAckQueue() async {
    final n = await _methodChannel.invokeMethod<dynamic>('drainAckQueue');
    if (n is int) {
      return n;
    }
    if (n is num) {
      return n.toInt();
    }
    return 0;
  }

  Future<void> dispose() async {
    await stopListening();
  }
}
