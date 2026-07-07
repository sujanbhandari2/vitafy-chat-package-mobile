import 'package:flutter/material.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

/// Demo presenter for the example app v2 integration:
/// direct chat uses the package bottom sheet; group chat opens a full page.
Future<void> examplePresentStartNewChat(
  BuildContext context,
  MessengerStartNewChatOpenRequest request,
) {
  if (request.mode == MessengerStartNewChatMode.group) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(
            title: const Text('New group'),
          ),
          body: SafeArea(
            child: request.buildPicker(),
          ),
        ),
      ),
    );
  }

  return presentDefaultStartNewChatBottomSheet(
    context: context,
    request: request,
  );
}
