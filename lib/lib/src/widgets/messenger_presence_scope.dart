import 'package:flutter/widgets.dart';

import '../client/chat_session.dart';

/// App-root presence wiring.
///
/// This widget forwards [`AppLifecycleState`] changes into the session-level
/// presence state machine (`ChatSession.handleAppLifecycleState`).
///
/// Hosts should mount it once at app root, not inside chat screens.
class MessengerPresenceScope extends StatefulWidget {
  const MessengerPresenceScope({
    super.key,
    required this.session,
    required this.child,
  });

  final ChatSession session;
  final Widget child;

  @override
  State<MessengerPresenceScope> createState() =>
      _MessengerPresenceScopeState();
}

class _MessengerPresenceScopeState extends State<MessengerPresenceScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize immediately so presence becomes online on bootstrap even if
    // the first lifecycle callback arrives later.
    final initial =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    widget.session.handleAppLifecycleState(initial);
  }

  @override
  void didUpdateWidget(covariant MessengerPresenceScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      final initial =
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
      widget.session.handleAppLifecycleState(initial);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.session.handleAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

