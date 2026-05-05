import 'package:flutter/material.dart';

/// Centered compact spinner used when replacing list / message bodies during load.
class MessengerDefaultInlineLoading extends StatelessWidget {
  const MessengerDefaultInlineLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}
