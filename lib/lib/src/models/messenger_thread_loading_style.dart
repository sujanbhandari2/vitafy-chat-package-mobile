import 'package:flutter/material.dart';

/// Styling for the built-in **empty-thread** loading placeholder only (spinner +
/// text while [MessengerChatThread.isConversationLoading] is true and there are
/// no messages yet). Ignored when [MessengerChatThread.loadingMessagesBuilder]
/// supplies a custom loading widget. Refetch while messages exist is controlled
/// by [MessengerChatThread.threadFetchLoadingMode].
///
/// Reload styling while messages are already shown is left to the host (shell,
/// app bar, snackbars, etc.).
class MessengerThreadLoadingStyle {
  const MessengerThreadLoadingStyle({
    this.placeholderMessage = 'Loading messages...',
    this.placeholderSemanticsLabel = 'Loading conversation',
    this.indicatorColor,
    this.placeholderIndicatorSize = 22,
    this.placeholderIndicatorStrokeWidth = 2.4,
    this.placeholderTextStyle,
  });

  /// Shown when the thread is empty and [MessengerChatThread.isConversationLoading] is true.
  final String placeholderMessage;

  final String placeholderSemanticsLabel;

  /// When null, [CircularProgressIndicator] uses the ambient theme default.
  final Color? indicatorColor;

  final double placeholderIndicatorSize;
  final double placeholderIndicatorStrokeWidth;

  final TextStyle? placeholderTextStyle;

  static const MessengerThreadLoadingStyle defaults = MessengerThreadLoadingStyle();
}
