/// Observed socket connectivity for UI and session logic.
enum ChatConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}
