import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

import '../chat_connection_state.dart';
import 'presence_config.dart';
import 'presence_snapshot.dart';

/// Own-presence state machine for the current SDK user.
///
/// This is driven by app lifecycle (foreground/background) and owns:
/// - the background grace timer
/// - own presence intent snapshot (`online` vs `offline`)
/// - socket connect/disconnect coordination
class PresenceController {
  PresenceController({
    required PresenceConfig config,
    required Stream<ChatConnectionState> connectionStateStream,
    required Future<void> Function() reconnectSocket,
    required void Function() disconnectSocket,
    required Future<void> Function(String reason) emitGoingOffline,
    required DateTime Function() now,
    AppLifecycleState initialLifecycleState = AppLifecycleState.resumed,
    Stream<AppLifecycleState>? lifecycleStream,
  })  : _config = config,
        _connectionStateStream = connectionStateStream,
        _reconnectSocket = reconnectSocket,
        _disconnectSocket = disconnectSocket,
        _emitGoingOffline = emitGoingOffline,
        _now = now {
    _lifecycleSubscription = lifecycleStream?.listen(handleLifecycleState);
    _connectionSubscription =
        _connectionStateStream.listen(_onConnectionState);

    // Initialize snapshot based on lifecycle so apps that bootstrap while
    // already resumed become "online immediately".
    _handleLifecycleIntent(initialLifecycleState);
  }

  final PresenceConfig _config;

  final Stream<ChatConnectionState> _connectionStateStream;
  final Future<void> Function() _reconnectSocket;
  final void Function() _disconnectSocket;
  final Future<void> Function(String reason) _emitGoingOffline;
  final DateTime Function() _now;

  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  StreamSubscription<ChatConnectionState>? _connectionSubscription;

  Timer? _inactiveDebounceTimer;
  Timer? _backgroundGraceTimer;

  bool _isOnlineIntent = false;
  bool _reconnectInFlight = false;
  bool _offlineInFlight = false;
  bool _intentionalDisconnect = false;
  bool _disposed = false;

  final ValueNotifier<PresenceSnapshot> _snapshot =
      ValueNotifier<PresenceSnapshot>(
    PresenceSnapshot(
      status: LocalPresenceStatus.offline,
      phase: LocalPresencePhase.inactive,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      backgroundGraceEndsAt: null,
    ),
  );

  /// Own presence intent for the current SDK user.
  ValueListenable<PresenceSnapshot> get presence => _snapshot;

  /// Call after `ChatSession.bootstrap` completes to ensure the presence state
  /// matches the current lifecycle intent.
  ///
  /// [socketConnected] is advisory; the controller will still coordinate
  /// reconnect/disconnect based on connectionState events.
  void onSessionReady({required bool socketConnected}) {
    if (_disposed) {
      return;
    }

    // Keep snapshot as set by initial lifecycle; optionally attempt reconnect
    // if intent is online but socket is already disconnected.
    if (_isOnlineIntent && !socketConnected) {
      // Actual reconnect happens on connection state changes; if we missed
      // those events and the stream hasn't yet produced disconnected, we
      // trigger one best-effort reconnect.
      unawaited(_tryReconnect('session_ready'));
    }
  }

  void handleLifecycleState(AppLifecycleState state) {
    if (_disposed) {
      return;
    }
    _handleLifecycleIntent(state);
  }

  void _handleLifecycleIntent(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _cancelGraceTimers();
        final previousPhase = _snapshot.value.phase;
        final shouldReconnect = previousPhase == LocalPresencePhase.offline ||
            previousPhase == LocalPresencePhase.backgroundGrace;
        _setOnlineIntent(LocalPresencePhase.foregroundOnline);
        if (shouldReconnect) {
          unawaited(_tryReconnect('lifecycle_resumed'));
        }
        break;
      case AppLifecycleState.inactive:
        // Debounce transient inactive so we don't flap presence for system UI.
        _inactiveDebounceTimer?.cancel();
        _inactiveDebounceTimer = Timer(_config.inactiveDebounce, () {
          if (_disposed) {
            return;
          }
          _startBackgroundGrace();
        });
        // Keep online intent until debounce fires.
        if (!_isOnlineIntent) {
          _setOnlineIntent(LocalPresencePhase.foregroundOnline);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _inactiveDebounceTimer?.cancel();
        _startBackgroundGrace();
        break;
      case AppLifecycleState.detached:
        unawaited(goOffline('detached'));
        break;
    }
  }

  void _startBackgroundGrace() {
    if (_disposed) {
      return;
    }
    // If already in grace, keep the earlier deadline.
    if (_backgroundGraceTimer != null) {
      return;
    }

    if (_config.backgroundOfflineGrace <= Duration.zero) {
      unawaited(goOffline('background_immediate'));
      return;
    }

    _setOnlineIntent(
      LocalPresencePhase.backgroundGrace,
      graceEndsAt: _now().add(_config.backgroundOfflineGrace),
    );

    if (_config.disconnectSocketWhenBackgrounded) {
      _disconnectSocketForBackground();
    }

    _backgroundGraceTimer = Timer(
      _config.backgroundOfflineGrace,
      () => unawaited(goOffline('background_grace_timeout')),
    );
  }

  void _disconnectSocketForBackground() {
    _intentionalDisconnect = true;
    _disconnectSocket();
  }

  void _cancelGraceTimers() {
    _inactiveDebounceTimer?.cancel();
    _inactiveDebounceTimer = null;

    _backgroundGraceTimer?.cancel();
    _backgroundGraceTimer = null;
  }

  void _setOnlineIntent(
    LocalPresencePhase phase, {
    DateTime? graceEndsAt,
  }) {
    _isOnlineIntent = true;
    final updatedAt = _now();
    _snapshot.value = PresenceSnapshot(
      status: LocalPresenceStatus.online,
      phase: phase,
      updatedAt: updatedAt,
      backgroundGraceEndsAt: graceEndsAt,
    );
  }

  Future<void> goOffline(String reason) async {
    if (_disposed) {
      return;
    }
    if (_offlineInFlight) {
      return;
    }
    _offlineInFlight = true;
    try {
      _cancelGraceTimers();
      _isOnlineIntent = false;

      _snapshot.value = PresenceSnapshot(
        status: LocalPresenceStatus.offline,
        phase: LocalPresencePhase.offline,
        updatedAt: _now(),
        backgroundGraceEndsAt: null,
      );

      if (_config.emitGoingOfflineOnOffline) {
        await _emitGoingOffline(reason);
      }

      if (_config.disconnectSocketOnOffline) {
        _disconnectSocketForBackground();
      }
    } finally {
      _offlineInFlight = false;
    }
  }

  /// Socket reconnect is only allowed while actively foreground-online.
  ///
  /// Without this, a background grace period would still reconnect dropped sockets
  /// and keep the user "online" on the server for the full grace window (or longer).
  bool get _mayReconnectSocket {
    return _isOnlineIntent &&
        _snapshot.value.phase == LocalPresencePhase.foregroundOnline;
  }

  Future<void> _tryReconnect(String reason) async {
    if (_disposed) {
      return;
    }
    if (_reconnectInFlight) {
      return;
    }
    if (!_mayReconnectSocket) {
      return;
    }
    _reconnectInFlight = true;
    try {
      await _reconnectSocket();
    } catch (_) {
      // Reconnect errors are handled by the connection state machine.
    } finally {
      _reconnectInFlight = false;
    }
  }

  void _onConnectionState(ChatConnectionState state) {
    if (_disposed) {
      return;
    }
    switch (state) {
      case ChatConnectionState.connected:
        return;
      case ChatConnectionState.disconnected:
        if (_intentionalDisconnect) {
          _intentionalDisconnect = false;
          return;
        }
        if (_mayReconnectSocket) {
          unawaited(_tryReconnect('connection_state_$state'));
        }
        return;
      case ChatConnectionState.reconnecting:
      case ChatConnectionState.connecting:
      case ChatConnectionState.failed:
        if (_mayReconnectSocket) {
          unawaited(_tryReconnect('connection_state_$state'));
        }
        return;
    }
  }

  void dispose() {
    _disposed = true;
    _lifecycleSubscription?.cancel();
    _connectionSubscription?.cancel();
    _inactiveDebounceTimer?.cancel();
    _backgroundGraceTimer?.cancel();
    _snapshot.dispose();
  }
}

