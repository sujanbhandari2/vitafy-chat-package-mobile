import 'dart:async';

import 'package:flutter/material.dart';

/// Scroll helpers for the messenger message [ListView].
///
/// Used by [MessengerChatShell] when [MessengerChatShell.autoScrollThreadToBottom]
/// is true. Hosts may also call these when building a custom shell around
/// [MessengerChatThread].
abstract final class MessengerThreadScroll {
  /// Default max post-frame retries (~500ms at 60Hz) so layout survives
  /// [AnimatedSwitcher] transitions and late [ListView] attachment.
  static const int defaultMaxAttempts = 30;

  /// Post-frame jumps after the first successful attach, so
  /// [maxScrollExtent] updates (e.g. keyboard inset) are picked up.
  static const int defaultSettleFrames = 6;

  static List<ScrollPosition> _attachedReadyPositions(
    ScrollController controller,
  ) {
    if (!controller.hasClients) {
      return const [];
    }
    return controller.positions
        .where((position) => position.hasContentDimensions)
        .toList(growable: false);
  }

  static bool _hasAnyReadyPosition(ScrollController controller) {
    if (!controller.hasClients) {
      return false;
    }
    for (final position in controller.positions) {
      if (position.hasContentDimensions) {
        return true;
      }
    }
    return false;
  }

  /// Schedules [ScrollPosition.jumpTo] after the scroll view is attached and
  /// laid out, with bounded retries, then chained settle frames.
  static void scheduleJumpToBottom(
    ScrollController controller, {
    int maxAttempts = defaultMaxAttempts,
    int settleFrames = defaultSettleFrames,
  }) {
    var attempt = 0;

    void tick() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        attempt++;
        final ready = _hasAnyReadyPosition(controller);
        if (!ready && attempt < maxAttempts) {
          tick();
          return;
        }
        final positions = _attachedReadyPositions(controller);
        if (positions.isEmpty) {
          return;
        }
        for (final position in positions) {
          position.jumpTo(position.maxScrollExtent);
        }
        _scheduleSettleJumpChain(controller, frames: settleFrames);
      });
    }

    tick();
  }

  /// Chains [jumpTo] on successive frames so a growing [maxScrollExtent] is
  /// followed (viewport / inset changes).
  static void _scheduleSettleJumpChain(
    ScrollController controller, {
    int frames = defaultSettleFrames,
  }) {
    void step(int remaining) {
      if (remaining <= 0) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final positions = _attachedReadyPositions(controller);
        if (positions.isEmpty) {
          return;
        }
        for (final position in positions) {
          position.jumpTo(position.maxScrollExtent);
        }
        step(remaining - 1);
      });
    }

    step(frames);
  }

  /// Same retry timing as [scheduleJumpToBottom], but uses
  /// [ScrollPosition.animateTo], then a final [jumpTo] to settle extent.
  static void scheduleAnimateToBottom(
    ScrollController controller, {
    Duration duration = const Duration(milliseconds: 240),
    Curve curve = Curves.easeOut,
    int maxAttempts = defaultMaxAttempts,
  }) {
    var attempt = 0;

    void tick() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        attempt++;
        final ready = _hasAnyReadyPosition(controller);
        if (!ready && attempt < maxAttempts) {
          tick();
          return;
        }
        if (!_hasAnyReadyPosition(controller)) {
          return;
        }
        unawaited(_animateThenSettle(
          controller,
          duration: duration,
          curve: curve,
        ));
      });
    }

    tick();
  }

  static Future<void> _animateThenSettle(
    ScrollController controller, {
    required Duration duration,
    required Curve curve,
  }) async {
    final positions = _attachedReadyPositions(controller);
    if (positions.isEmpty) {
      return;
    }
    try {
      await Future.wait(
        positions.map(
          (position) => position.animateTo(
            position.maxScrollExtent,
            duration: duration,
            curve: curve,
          ),
        ),
      );
    } catch (_) {
      // Controller may be disposed mid-animation.
    }
    final settledPositions = _attachedReadyPositions(controller);
    if (settledPositions.isEmpty) {
      return;
    }
    for (final position in settledPositions) {
      position.jumpTo(position.maxScrollExtent);
    }
    _scheduleSettleJumpChain(controller);
  }
}
