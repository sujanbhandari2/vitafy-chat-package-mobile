import 'package:flutter/material.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

/// Demo host widget for [MessengerChatShell.emptyInboxBuilder].
class ExampleEmptyInboxPane extends StatelessWidget {
  const ExampleEmptyInboxPane({
    super.key,
    required this.onRefresh,
    this.isRefreshing = false,
  });

  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 56,
                    color: scheme.primary.withValues(alpha: 0.72),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      color: theme.subtleText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'This screen comes from emptyInboxBuilder on MessengerChatShell. '
                    'Use the app-bar toggle to compare with the suggested-people flow.',
                    style: TextStyle(
                      color: theme.subtleText,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: isRefreshing ? null : () => onRefresh(),
                    icon: isRefreshing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(isRefreshing ? 'Refreshing...' : 'Refresh inbox'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
