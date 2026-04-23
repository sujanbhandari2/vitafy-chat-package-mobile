import 'package:flutter/material.dart';

@immutable
class MessengerAttachmentOption {
  const MessengerAttachmentOption({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}
