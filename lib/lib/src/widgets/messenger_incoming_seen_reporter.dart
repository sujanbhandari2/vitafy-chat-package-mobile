import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Invokes [onSeen] once after the first frame when [enabled] is true.
///
/// Used for peer messages in the open thread so hosts can emit read receipts
/// when bubbles are actually built (in addition to inbox socket policy).
class MessengerIncomingSeenReporter extends StatefulWidget {
  const MessengerIncomingSeenReporter({
    super.key,
    required this.enabled,
    required this.onSeen,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onSeen;
  final Widget child;

  @override
  State<MessengerIncomingSeenReporter> createState() =>
      _MessengerIncomingSeenReporterState();
}

class _MessengerIncomingSeenReporterState
    extends State<MessengerIncomingSeenReporter> {
  bool _reported = false;

  @override
  void didUpdateWidget(covariant MessengerIncomingSeenReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _reported = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enabled && !_reported) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _reported || !widget.enabled) {
          return;
        }
        _reported = true;
        widget.onSeen();
      });
    }
    return widget.child;
  }
}
