import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:health_messenger_ui/lib/src/client/chat_connection_state.dart';
import 'package:health_messenger_ui/lib/src/client/presence/presence_config.dart';
import 'package:health_messenger_ui/lib/src/client/presence/presence_controller.dart';
import 'package:health_messenger_ui/lib/src/client/presence/presence_snapshot.dart';

void main() {
  group('PresenceController', () {
    test('initial resumed -> online / foregroundOnline', () {
      final connectionStateController =
          StreamController<ChatConnectionState>.broadcast();

      final controller = PresenceController(
        config: const PresenceConfig(
          backgroundOfflineGrace: Duration(milliseconds: 50),
          inactiveDebounce: Duration.zero,
        ),
        connectionStateStream: connectionStateController.stream,
        reconnectSocket: () async {},
        disconnectSocket: () {},
        emitGoingOffline: (_) async {},
        now: () => DateTime.utc(2026, 01, 01),
        initialLifecycleState: AppLifecycleState.resumed,
      );

      expect(controller.presence.value.status, LocalPresenceStatus.online);
      expect(
        controller.presence.value.phase,
        LocalPresencePhase.foregroundOnline,
      );

      controller.dispose();
      connectionStateController.close();
    });

    test('paused -> grace -> offline transitions', () async {
      final connectionStateController =
          StreamController<ChatConnectionState>.broadcast();

      var disconnectCalls = 0;
      final emitReasons = <String>[];

      final controller = PresenceController(
        config: const PresenceConfig(
          backgroundOfflineGrace: Duration(milliseconds: 40),
          inactiveDebounce: Duration.zero,
        ),
        connectionStateStream: connectionStateController.stream,
        reconnectSocket: () async {},
        disconnectSocket: () => disconnectCalls++,
        emitGoingOffline: (reason) async {
          emitReasons.add(reason);
        },
        now: () => DateTime.utc(2026, 01, 01),
        initialLifecycleState: AppLifecycleState.resumed,
      );

      controller.handleLifecycleState(AppLifecycleState.paused);

      // Socket drops as soon as background grace starts.
      expect(disconnectCalls, 1);

      // Wait for grace timer to fire.
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(controller.presence.value.status, LocalPresenceStatus.offline);
      expect(controller.presence.value.phase, LocalPresencePhase.offline);
      expect(disconnectCalls, greaterThanOrEqualTo(1));
      expect(emitReasons, isNotEmpty);

      controller.dispose();
      await connectionStateController.close();
    });

    test('paused grace cancelled on resume', () async {
      final connectionStateController =
          StreamController<ChatConnectionState>.broadcast();

      var disconnectCalls = 0;
      var reconnectCalls = 0;
      final emitReasons = <String>[];

      final controller = PresenceController(
        config: const PresenceConfig(
          backgroundOfflineGrace: Duration(milliseconds: 60),
          inactiveDebounce: Duration.zero,
        ),
        connectionStateStream: connectionStateController.stream,
        reconnectSocket: () async {
          reconnectCalls++;
        },
        disconnectSocket: () => disconnectCalls++,
        emitGoingOffline: (reason) async => emitReasons.add(reason),
        now: () => DateTime.utc(2026, 01, 01),
        initialLifecycleState: AppLifecycleState.resumed,
      );

      controller.handleLifecycleState(AppLifecycleState.paused);
      expect(disconnectCalls, 1);

      // Resume before grace expires.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.handleLifecycleState(AppLifecycleState.resumed);

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(controller.presence.value.status, LocalPresenceStatus.online);
      expect(reconnectCalls, 1);
      expect(emitReasons, isEmpty);

      controller.dispose();
      await connectionStateController.close();
    });

    test('resumed after offline reconnects socket', () async {
      final connectionStateController =
          StreamController<ChatConnectionState>.broadcast();

      var reconnectCalls = 0;

      final controller = PresenceController(
        config: const PresenceConfig(
          backgroundOfflineGrace: Duration(milliseconds: 40),
          inactiveDebounce: Duration.zero,
        ),
        connectionStateStream: connectionStateController.stream,
        reconnectSocket: () async {
          reconnectCalls++;
        },
        disconnectSocket: () {},
        emitGoingOffline: (_) async {},
        now: () => DateTime.utc(2026, 01, 01),
        initialLifecycleState: AppLifecycleState.resumed,
      );

      controller.handleLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(controller.presence.value.status, LocalPresenceStatus.offline);

      controller.handleLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.presence.value.status, LocalPresenceStatus.online);
      expect(reconnectCalls, 1);

      controller.dispose();
      await connectionStateController.close();
    });

    test('paused disconnects socket immediately when backgrounded', () async {
      final connectionStateController =
          StreamController<ChatConnectionState>.broadcast();

      var disconnectCalls = 0;

      final controller = PresenceController(
        config: const PresenceConfig(
          backgroundOfflineGrace: Duration(minutes: 5),
          inactiveDebounce: Duration.zero,
        ),
        connectionStateStream: connectionStateController.stream,
        reconnectSocket: () async {},
        disconnectSocket: () => disconnectCalls++,
        emitGoingOffline: (_) async {},
        now: () => DateTime.utc(2026, 01, 01),
        initialLifecycleState: AppLifecycleState.resumed,
      );

      controller.handleLifecycleState(AppLifecycleState.paused);

      expect(disconnectCalls, 1);
      expect(
        controller.presence.value.phase,
        LocalPresencePhase.backgroundGrace,
      );

      controller.dispose();
      await connectionStateController.close();
    });

    test('disconnected during background grace does not reconnect', () async {
      final connectionStateController =
          StreamController<ChatConnectionState>.broadcast();

      var reconnectCalls = 0;

      final controller = PresenceController(
        config: const PresenceConfig(
          backgroundOfflineGrace: Duration(minutes: 5),
          inactiveDebounce: Duration.zero,
        ),
        connectionStateStream: connectionStateController.stream,
        reconnectSocket: () async {
          reconnectCalls++;
        },
        disconnectSocket: () {},
        emitGoingOffline: (_) async {},
        now: () => DateTime.utc(2026, 01, 01),
        initialLifecycleState: AppLifecycleState.resumed,
      );

      controller.handleLifecycleState(AppLifecycleState.paused);
      connectionStateController.add(ChatConnectionState.disconnected);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.presence.value.phase,
          LocalPresencePhase.backgroundGrace);
      expect(reconnectCalls, 0);

      controller.dispose();
      await connectionStateController.close();
    });

    test('connection disconnected triggers reconnect when online intent is on',
        () async {
      final connectionStateController =
          StreamController<ChatConnectionState>.broadcast();

      var reconnectCalls = 0;

      final controller = PresenceController(
        config: const PresenceConfig(
          backgroundOfflineGrace: Duration(milliseconds: 60),
          inactiveDebounce: Duration.zero,
        ),
        connectionStateStream: connectionStateController.stream,
        reconnectSocket: () async {
          reconnectCalls++;
        },
        disconnectSocket: () {},
        emitGoingOffline: (_) async {},
        now: () => DateTime.utc(2026, 01, 01),
        initialLifecycleState: AppLifecycleState.resumed,
      );

      connectionStateController.add(ChatConnectionState.disconnected);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(reconnectCalls, 1);

      controller.dispose();
      await connectionStateController.close();
    });
  });
}

