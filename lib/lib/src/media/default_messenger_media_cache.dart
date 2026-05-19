import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'messenger_media_cache.dart';

/// Default attachment cache backed by [flutter_cache_manager].
class DefaultMessengerMediaCache implements MessengerMediaCache {
  DefaultMessengerMediaCache({
    Duration stalePeriod = const Duration(days: 14),
    int maxNrOfCacheObjects = 500,
    CacheManager? manager,
  }) : _manager = manager ??
            CacheManager(
              Config(
                'messenger_media_cache',
                stalePeriod: stalePeriod,
                maxNrOfCacheObjects: maxNrOfCacheObjects,
                // JSON metadata avoids sqflite, which is not always registered
                // when this package is consumed from a host app plugin graph.
                repo: JsonCacheInfoRepository(
                  databaseName: 'messenger_media_cache',
                ),
              ),
            );

  final CacheManager _manager;

  @override
  Future<File?> getFile(
    String url, {
    Map<String, String>? headers,
  }) async {
    final normalized = url.trim();
    if (normalized.isEmpty || !messengerMediaSourceIsNetwork(normalized)) {
      return null;
    }
    try {
      return await _manager.getSingleFile(
        normalized,
        headers: headers,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> prefetch(
    Iterable<String> urls, {
    Map<String, String>? headers,
  }) async {
    final unique = urls
        .map((u) => u.trim())
        .where((u) => messengerMediaSourceIsNetwork(u))
        .toSet();
    if (unique.isEmpty) {
      return;
    }
    await Future.wait(
      unique.map((url) => getFile(url, headers: headers)),
    );
  }

  @override
  Future<void> remove(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return;
    }
    try {
      await _manager.removeFile(normalized);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await _manager.emptyCache();
    } catch (_) {}
  }
}
