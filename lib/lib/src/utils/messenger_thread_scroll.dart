import 'dart:async';

import 'package:flutter/material.dart';

/// Scroll helpers for the messenger message [ListView].
///
/// Used by [MessengerChatShell] when [MessengerChatShell.autoScrollThreadToBottom]
/// is true. Hosts may also call these when building a custom shell around
/// [MessengerChatThread].
abstract final class MessengerThreadScroll {
  /// Schedules two post-frame [ScrollPosition.jumpTo] calls so
  /// [ScrollPosition.maxScrollExtent] is correct after layout.
  static void scheduleJumpToBottom(ScrollController controller) {
    void jump() {
      if (!controller.hasClients) {
        return;
      }
      controller.jumpTo(controller.position.maxScrollExtent);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        jump();
      });
    });
  }

  /// Same timing as [scheduleJumpToBottom], but uses [ScrollPosition.animateTo].
  static void scheduleAnimateToBottom(
    ScrollController controller, {
    Duration duration = const Duration(milliseconds: 240),
    Curve curve = Curves.easeOut,
  }) {
    void animate() {
      if (!controller.hasClients) {
        return;
      }
      unawaited(
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: duration,
          curve: curve,
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      animate();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        animate();
      });
    });
  }
}
