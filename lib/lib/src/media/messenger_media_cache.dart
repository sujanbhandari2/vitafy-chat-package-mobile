import 'dart:io';

export '../utils/messenger_media_url.dart';

/// Disk-backed cache for chat attachment media (images, voice files).
abstract class MessengerMediaCache {
  /// Returns a cached file for [url], downloading when missing.
  Future<File?> getFile(
    String url, {
    Map<String, String>? headers,
  });

  /// Warms the cache for [urls] without blocking UI.
  Future<void> prefetch(
    Iterable<String> urls, {
    Map<String, String>? headers,
  });

  Future<void> remove(String url);

  Future<void> clear();
}
