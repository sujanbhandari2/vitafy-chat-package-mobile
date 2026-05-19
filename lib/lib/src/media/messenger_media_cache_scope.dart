import 'package:flutter/material.dart';

import '../utils/messenger_media_url.dart';
import 'default_messenger_media_cache.dart';
import 'messenger_media_cache.dart';

/// Provides [MessengerMediaCache] and optional per-URL request headers to descendants.
class MessengerMediaCacheScope extends InheritedWidget {
  const MessengerMediaCacheScope({
    super.key,
    required this.cache,
    this.headersForUrl,
    this.staticHeaders = const {},
    this.mediaBaseOrigin,
    required super.child,
  });

  final MessengerMediaCache cache;
  final Future<Map<String, String>> Function(String url)? headersForUrl;
  final Map<String, String> staticHeaders;

  /// API origin used to resolve relative attachment paths (e.g. `/uploads/x`).
  final String? mediaBaseOrigin;

  static MessengerMediaCacheScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MessengerMediaCacheScope>();
  }

  static MessengerMediaCache of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'MessengerMediaCacheScope not found. Wrap MessengerChatShell (or provide scope) above message UI.',
    );
    return scope!.cache;
  }

  static String resolveMediaUrl(BuildContext context, String url) {
    final scope = maybeOf(context);
    if (scope == null) {
      return url.trim();
    }
    return messengerAbsoluteMediaUrl(
      url,
      baseOrigin: scope.mediaBaseOrigin,
    );
  }

  static Future<Map<String, String>> resolveHeaders(
    BuildContext context,
    String url,
  ) async {
    final scope = maybeOf(context);
    if (scope == null) {
      return const {};
    }
    if (scope.headersForUrl != null) {
      return scope.headersForUrl!(url);
    }
    return scope.staticHeaders;
  }

  /// Clears all cached media files when a scope is available.
  static Future<void> clearCache(BuildContext context) async {
    final scope = maybeOf(context);
    if (scope == null) {
      return;
    }
    await scope.cache.clear();
  }

  /// Creates a default scope for hosts not using [MessengerChatShell].
  static Widget withDefaults({
    Key? key,
    MessengerMediaCache? cache,
    Map<String, String> headers = const {},
    Future<Map<String, String>> Function(String url)? headersForUrl,
    String? mediaBaseOrigin,
    required Widget child,
  }) {
    return MessengerMediaCacheScope(
      key: key,
      cache: cache ?? DefaultMessengerMediaCache(),
      staticHeaders: headers,
      headersForUrl: headersForUrl,
      mediaBaseOrigin: mediaBaseOrigin,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(MessengerMediaCacheScope oldWidget) {
    return !identical(cache, oldWidget.cache) ||
        headersForUrl != oldWidget.headersForUrl ||
        staticHeaders != oldWidget.staticHeaders ||
        mediaBaseOrigin != oldWidget.mediaBaseOrigin;
  }
}
