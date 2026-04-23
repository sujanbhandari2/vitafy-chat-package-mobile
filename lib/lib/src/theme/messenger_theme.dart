import 'package:flutter/material.dart';

@immutable
class MessengerThemeData {
  const MessengerThemeData({
    this.primary = const Color(0xFF1B74E4),
    this.background = const Color(0xFFF5F9FF),
    this.surface = Colors.white,
    this.border = const Color(0xFFE5E7EB),
    this.subtleText = const Color(0xFF64748B),
    this.mutedText = const Color(0xFF9CA3AF),
    this.searchBackground = const Color(0xFFF3F4F6),
    this.threadBackgroundMobile = const Color(0xFFF2F2F7),
    this.bubbleMine = Colors.white,
    this.bubbleOther = const Color(0xFF1B74E4),
    this.bubbleMineText = const Color(0xFF111827),
    this.bubbleOtherText = Colors.white,
    this.bubbleMineTime = const Color(0xFF6B7280),
    this.bubbleOtherTime = Colors.white70,
    this.composerFieldBackground = const Color(0xFFF1F3F5),
    this.onlineIndicator = const Color(0xFF10B981),
    this.offlineIndicator = const Color(0xFF9CA3AF),
    this.reactionBackground = Colors.white,
    this.reactionBorder = const Color(0xFFE5E7EB),
    this.dateSeparatorBackground = const Color(0xFFE2E8F0),
    this.dateSeparatorText = const Color(0xFF475569),
  });

  final Color primary;
  final Color background;
  final Color surface;
  final Color border;
  final Color subtleText;
  final Color mutedText;
  final Color searchBackground;
  final Color threadBackgroundMobile;
  final Color bubbleMine;
  final Color bubbleOther;
  final Color bubbleMineText;
  final Color bubbleOtherText;
  final Color bubbleMineTime;
  final Color bubbleOtherTime;
  final Color composerFieldBackground;
  final Color onlineIndicator;
  final Color offlineIndicator;
  final Color reactionBackground;
  final Color reactionBorder;
  final Color dateSeparatorBackground;
  final Color dateSeparatorText;

  MessengerThemeData copyWith({
    Color? primary,
    Color? background,
    Color? surface,
    Color? border,
    Color? subtleText,
    Color? mutedText,
    Color? searchBackground,
    Color? threadBackgroundMobile,
    Color? bubbleMine,
    Color? bubbleOther,
    Color? bubbleMineText,
    Color? bubbleOtherText,
    Color? bubbleMineTime,
    Color? bubbleOtherTime,
    Color? composerFieldBackground,
    Color? onlineIndicator,
    Color? offlineIndicator,
    Color? reactionBackground,
    Color? reactionBorder,
    Color? dateSeparatorBackground,
    Color? dateSeparatorText,
  }) {
    return MessengerThemeData(
      primary: primary ?? this.primary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      subtleText: subtleText ?? this.subtleText,
      mutedText: mutedText ?? this.mutedText,
      searchBackground: searchBackground ?? this.searchBackground,
      threadBackgroundMobile:
          threadBackgroundMobile ?? this.threadBackgroundMobile,
      bubbleMine: bubbleMine ?? this.bubbleMine,
      bubbleOther: bubbleOther ?? this.bubbleOther,
      bubbleMineText: bubbleMineText ?? this.bubbleMineText,
      bubbleOtherText: bubbleOtherText ?? this.bubbleOtherText,
      bubbleMineTime: bubbleMineTime ?? this.bubbleMineTime,
      bubbleOtherTime: bubbleOtherTime ?? this.bubbleOtherTime,
      composerFieldBackground:
          composerFieldBackground ?? this.composerFieldBackground,
      onlineIndicator: onlineIndicator ?? this.onlineIndicator,
      offlineIndicator: offlineIndicator ?? this.offlineIndicator,
      reactionBackground: reactionBackground ?? this.reactionBackground,
      reactionBorder: reactionBorder ?? this.reactionBorder,
      dateSeparatorBackground:
          dateSeparatorBackground ?? this.dateSeparatorBackground,
      dateSeparatorText: dateSeparatorText ?? this.dateSeparatorText,
    );
  }
}

class MessengerTheme extends InheritedWidget {
  const MessengerTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final MessengerThemeData data;

  static MessengerThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<MessengerTheme>();
    return theme?.data ?? const MessengerThemeData();
  }

  @override
  bool updateShouldNotify(MessengerTheme oldWidget) => data != oldWidget.data;
}
