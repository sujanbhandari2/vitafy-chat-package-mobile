import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

import 'example_models.dart';

/// App-root session + presence owner for the example application.
///
/// This holder keeps `ChatSession` alive across navigation (e.g. returning
/// from [`ExampleChatPage`] back to the configuration screen) so presence is
/// driven by app lifecycle, not the chat screen widget lifecycle.
class ExampleChatSessionHolder extends StatefulWidget {
  const ExampleChatSessionHolder({super.key, required this.child});

  final Widget child;

  @override
  State<ExampleChatSessionHolder> createState() =>
      _ExampleChatSessionHolderState();
}

class ExampleChatSessionHolderScope extends InheritedWidget {
  const ExampleChatSessionHolderScope({
    super.key,
    required super.child,
    required this.session,
    required this.isBootstrapping,
    required this.ownPresence,
    required this.startSession,
    required this.logout,
  });

  final ChatSession? session;
  final bool isBootstrapping;
  final ValueListenable<PresenceSnapshot?> ownPresence;
  final Future<void> Function(ExampleBootstrapFormData data) startSession;
  final Future<void> Function() logout;

  static ExampleChatSessionHolderScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ExampleChatSessionHolderScope>();
    if (scope == null) {
      throw StateError(
        'ExampleChatSessionHolderScope.of(context) called before init',
      );
    }
    return scope;
  }

  @override
  bool updateShouldNotify(covariant ExampleChatSessionHolderScope oldWidget) {
    return session != oldWidget.session ||
        isBootstrapping != oldWidget.isBootstrapping ||
        ownPresence != oldWidget.ownPresence;
  }
}

class _ExampleChatSessionHolderState extends State<ExampleChatSessionHolder> {
  ChatSession? _session;
  bool _isBootstrapping = false;

  final ValueNotifier<PresenceSnapshot?> _ownPresenceNotifier =
      ValueNotifier<PresenceSnapshot?>(null);

  late final VoidCallback _ownPresenceListener = () {
    final s = _session;
    _ownPresenceNotifier.value = s == null ? null : s.ownPresence.value;
  };

  Future<void> _startSessionInternal(ExampleBootstrapFormData data) async {
    if (_isBootstrapping) {
      return;
    }
    if (_session != null) {
      return;
    }

    final apiBaseUrl = data.apiBaseUrl.trim();
    final socketUrl = data.socketUrl.trim();
    final apiKey = data.apiKey.trim();
    final externalTenantId = data.externalTenantId.trim();
    final externalUserId = data.externalUserId.trim();
    final externalUserRole = data.externalUserRole.trim();
    final email = data.email.trim();
    final name = data.name.trim();
    final profile = data.profile?.trim();

    setState(() {
      _isBootstrapping = true;
    });

    try {
      final config = ChatServiceConfig(
        apiBaseUrl: apiBaseUrl,
        socketUrl: socketUrl,
        socketTransports: const ['websocket'],
        apiLogger: (message, {data}) {
          // ignore: avoid_print
          debugPrint('[health_messenger_ui/api] $message ${data ?? ''}');
        },
      );

      // Shorten grace for the example so "background -> offline" can be
      // tested quickly. Hosts should use the defaults (5 minutes) in real apps.
      const presenceConfig = PresenceConfig(
        backgroundOfflineGrace: Duration(seconds: 45),
      );

      final session = ChatSession(
        config: config,
        presenceConfig: presenceConfig,
      );

      final apiAuth = ChatAuth(apiKey: apiKey);
      await session.bootstrap(
        apiAuth: apiAuth,
        externalTenantId: externalTenantId,
        externalUserId: externalUserId,
        externalUserRole: externalUserRole,
        email: email,
        name: name.isEmpty ? null : name,
        profile: (profile?.isEmpty ?? true) ? null : profile,
        awaitSocketConnect: false,
      );

      _session = session;
      _session!.ownPresence.addListener(_ownPresenceListener);
      _ownPresenceNotifier.value = _session!.ownPresence.value;
    } finally {
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }
    }
  }

  Future<void> _logoutInternal() async {
    final session = _session;
    if (session == null) {
      return;
    }

    try {
      await session.logout();
    } finally {
      session.ownPresence.removeListener(_ownPresenceListener);
      _session = null;
      _ownPresenceNotifier.value = null;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _ownPresenceNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final child = session == null
        ? widget.child
        : MessengerPresenceScope(session: session, child: widget.child);

    return ExampleChatSessionHolderScope(
      session: session,
      isBootstrapping: _isBootstrapping,
      ownPresence: _ownPresenceNotifier,
      startSession: _startSessionInternal,
      logout: _logoutInternal,
      child: child,
    );
  }
}

