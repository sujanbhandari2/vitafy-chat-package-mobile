/// Client-side presence policy.
///
/// Note: "online/offline as seen by other users" ultimately depends on the
/// server's presence semantics. This config controls the local intent and
/// when the client disconnects.
///
/// The server **must** mark users offline when their socket drops (force-quit,
/// OS kill, uninstall). No client can run code after uninstall; rely on socket
/// disconnect detection or a presence TTL on the backend.
class PresenceConfig {
  const PresenceConfig({
    this.backgroundOfflineGrace = const Duration(minutes: 5),
    this.inactiveDebounce = const Duration(milliseconds: 400),
    this.disconnectSocketOnOffline = true,
    this.emitGoingOfflineOnOffline = true,
    this.disconnectSocketWhenBackgrounded = true,
  });

  /// When the app moves to background (paused/hidden), keep the user online
  /// for this long before transitioning them to offline.
  final Duration backgroundOfflineGrace;

  /// Debounce duration for [AppLifecycleState.inactive] to reduce flapping
  /// (e.g. transient system UI overlays).
  final Duration inactiveDebounce;

  /// When grace expires (or the app is disposed), disconnect the socket so the
  /// server flips the user to offline.
  final bool disconnectSocketOnOffline;

  /// Best-effort emit of a "going_offline" signal before disconnecting.
  final bool emitGoingOfflineOnOffline;

  /// When the app enters background grace ([AppLifecycleState.paused] /
  /// [AppLifecycleState.hidden]), disconnect the socket immediately so the
  /// server sees a drop even before [backgroundOfflineGrace] expires.
  ///
  /// Local presence intent stays in [LocalPresencePhase.backgroundGrace] until
  /// grace ends; the socket is reconnected on [AppLifecycleState.resumed] if the
  /// user returns before grace times out.
  final bool disconnectSocketWhenBackgrounded;

  PresenceConfig copyWith({
    Duration? backgroundOfflineGrace,
    Duration? inactiveDebounce,
    bool? disconnectSocketOnOffline,
    bool? emitGoingOfflineOnOffline,
    bool? disconnectSocketWhenBackgrounded,
  }) {
    return PresenceConfig(
      backgroundOfflineGrace: backgroundOfflineGrace ?? this.backgroundOfflineGrace,
      inactiveDebounce: inactiveDebounce ?? this.inactiveDebounce,
      disconnectSocketOnOffline:
          disconnectSocketOnOffline ?? this.disconnectSocketOnOffline,
      emitGoingOfflineOnOffline:
          emitGoingOfflineOnOffline ?? this.emitGoingOfflineOnOffline,
      disconnectSocketWhenBackgrounded: disconnectSocketWhenBackgrounded ??
          this.disconnectSocketWhenBackgrounded,
    );
  }
}

