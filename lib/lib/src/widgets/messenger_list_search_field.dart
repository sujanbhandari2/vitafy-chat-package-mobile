import 'package:flutter/material.dart';

import 'messenger_group_name_text_field.dart';

/// Shared search row used by [MessengerConversationList], the start-new-chat
/// sheet, and [MessengerSuggestedPeoplePanel] so height, padding, icons, and
/// decoration stay aligned.
class MessengerListSearchField extends StatelessWidget {
  const MessengerListSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    required this.hintText,
    this.hintStyle,
    this.inputTextStyle,
    required this.backgroundColor,
    required this.iconColor,
    required this.borderRadius,
    this.contentPadding,
    this.onClear,
    this.semanticsLabel,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final TextStyle? hintStyle;
  final TextStyle? inputTextStyle;
  final Color backgroundColor;
  final Color iconColor;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;

  /// Invoked when the trailing clear affordance is tapped. When null, the
  /// field clears the [controller] and calls [onChanged] with `''`.
  final VoidCallback? onClear;

  final String? semanticsLabel;

  static double get containerHeight =>
      MessengerGroupNameTextField.containerHeight;

  @override
  Widget build(BuildContext context) {
    final field = ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final showClear = value.text.trim().isNotEmpty;
        return Container(
          height: containerHeight,
          padding: contentPadding ??
              const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: inputTextStyle,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: hintStyle,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (showClear)
                GestureDetector(
                  onTap: () {
                    if (onClear != null) {
                      onClear!();
                    } else {
                      controller.clear();
                      onChanged?.call('');
                    }
                  },
                  child: Icon(Icons.close_rounded, color: iconColor),
                ),
            ],
          ),
        );
      },
    );

    if (semanticsLabel == null || semanticsLabel!.isEmpty) {
      return field;
    }
    return Semantics(
      label: semanticsLabel,
      child: field,
    );
  }
}
