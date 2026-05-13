import 'package:flutter/material.dart';

/// Group name input styled like the “start new chat” search field: fixed
/// height container, leading icon, borderless dense [TextField]. Validation
/// text is shown below the bar so it is not clipped.
class MessengerGroupNameTextField extends StatelessWidget {
  const MessengerGroupNameTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.backgroundColor,
    this.borderRadius = 12,
    this.contentPadding,
    this.iconColor,
    this.hintStyle,
    this.inputTextStyle,
    this.leadingIcon = Icons.groups_outlined,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  });

  /// Same height as the start-new-chat search row.
  static const double containerHeight = 38;

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final Color backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final Color? iconColor;
  final TextStyle? hintStyle;
  final TextStyle? inputTextStyle;
  final IconData leadingIcon;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor =
        iconColor ?? theme.colorScheme.onSurfaceVariant;
    final effectiveHintStyle = hintStyle ??
        TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 14,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: containerHeight,
          padding: contentPadding ??
              const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Row(
            children: [
              Icon(
                leadingIcon,
                color: effectiveIconColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  label: labelText,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: effectiveHintStyle,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
