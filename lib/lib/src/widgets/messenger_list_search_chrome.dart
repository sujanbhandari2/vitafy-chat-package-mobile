import 'package:flutter/material.dart';

import '../theme/messenger_theme.dart';

/// Resolves the same search-field chrome as [MessengerConversationList] and
/// the start-new-chat bottom sheet, optionally overridden by
/// [MessengerChatShell] so embedded surfaces (e.g. suggested people) stay in
/// sync without duplicating constructor arguments.
class MessengerListSearchChrome extends InheritedWidget {
  const MessengerListSearchChrome({
    super.key,
    required this.backgroundColor,
    required this.iconColor,
    required this.hintStyle,
    required this.borderRadius,
    this.contentPadding,
    this.inputTextStyle,
    required super.child,
  });

  final Color backgroundColor;
  final Color iconColor;
  final TextStyle hintStyle;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? inputTextStyle;

  static MessengerListSearchChrome? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MessengerListSearchChrome>();
  }

  /// Same defaults as [MessengerConversationList] and the start-new-chat sheet.
  factory MessengerListSearchChrome.resolve(
    BuildContext context, {
    required Widget child,
    Color? searchFieldBackgroundColor,
    Color? searchIconColor,
    TextStyle? searchHintTextStyle,
    EdgeInsetsGeometry? searchFieldContentPadding,
    double? searchFieldBorderRadius,
    TextStyle? searchInputTextStyle,
  }) {
    final theme = MessengerTheme.of(context);
    return MessengerListSearchChrome(
      backgroundColor:
          searchFieldBackgroundColor ?? theme.searchBackground,
      iconColor: searchIconColor ?? theme.mutedText,
      hintStyle:
          searchHintTextStyle ?? TextStyle(color: theme.mutedText),
      contentPadding: searchFieldContentPadding,
      borderRadius: searchFieldBorderRadius ?? 12,
      inputTextStyle: searchInputTextStyle,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(MessengerListSearchChrome oldWidget) {
    return backgroundColor != oldWidget.backgroundColor ||
        iconColor != oldWidget.iconColor ||
        hintStyle != oldWidget.hintStyle ||
        borderRadius != oldWidget.borderRadius ||
        contentPadding != oldWidget.contentPadding ||
        inputTextStyle != oldWidget.inputTextStyle;
  }
}
