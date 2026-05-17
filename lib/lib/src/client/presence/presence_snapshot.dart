/// Public snapshot of the local user's presence intent/state.
///
/// This is "own presence" for the current SDK user, driven by the host app
/// lifecycle and the configured offline grace timer.
enum LocalPresenceStatus {
  /// User should be treated as unavailable.
  offline,

  /// User should be treated as available.
  online,
}

/// More detail than [LocalPresenceStatus], useful for debugging/UX.
enum LocalPresencePhase {
  /// Session not ready yet or SDK has been disposed.
  inactive,

  /// Socket intent is online and the app is in foreground.
  foregroundOnline,

  /// Socket intent is online while the client waits out the background grace.
  backgroundGrace,

  /// Socket intent is offline (grace expired or app is disposed).
  offline,
}

class PresenceSnapshot {
  const PresenceSnapshot({
    required this.status,
    required this.phase,
    required this.updatedAt,
    this.backgroundGraceEndsAt,
  });

  final LocalPresenceStatus status;
  final LocalPresencePhase phase;
  final DateTime updatedAt;

  /// When set, indicates the background grace deadline (if any) for display.
  final DateTime? backgroundGraceEndsAt;

  PresenceSnapshot copyWith({
    LocalPresenceStatus? status,
    LocalPresencePhase? phase,
    DateTime? updatedAt,
    DateTime? backgroundGraceEndsAt,
  }) {
    return PresenceSnapshot(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      updatedAt: updatedAt ?? this.updatedAt,
      backgroundGraceEndsAt: backgroundGraceEndsAt ?? this.backgroundGraceEndsAt,
    );
  }
}

