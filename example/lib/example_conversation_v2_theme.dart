import 'package:flutter/material.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

/// Teal-forward palette matching the example v2 conversation mock.
abstract final class ExampleConversationV2Theme {
  static const Color teal = Color(0xFF0F766E);
  static const Color tealDark = Color(0xFF134E4A);
  static const Color advocateLabel = Color(0xFFEA580C);
  static const Color incomingBubble = Color(0xFFF3F4F6);
  static const Color incomingText = Color(0xFF1F2937);
  static const Color screenBackground = Color(0xFFFAFAFA);
  static const Color composerBorder = Color(0xFFE5E7EB);
  static const Color hint = Color(0xFF9CA3AF);

  static const MessengerThemeData messengerTheme = MessengerThemeData(
    primary: teal,
    background: screenBackground,
    surface: Colors.white,
    border: composerBorder,
    subtleText: Color(0xFF64748B),
    mutedText: hint,
    threadBackgroundMobile: screenBackground,
    bubbleMine: teal,
    bubbleOther: incomingBubble,
    bubbleMineText: Colors.white,
    bubbleOtherText: incomingText,
    bubbleMineTime: Color(0xCCFFFFFF),
    bubbleOtherTime: Color(0xFF6B7280),
    composerFieldBackground: Colors.white,
    dateSeparatorBackground: Color(0xFFF3F4F6),
    dateSeparatorText: Color(0xFF6B7280),
  );
}

enum ExampleConversationUiVersion { v1Legacy, v2Custom }
