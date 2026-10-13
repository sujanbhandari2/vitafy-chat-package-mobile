import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/messenger_media_url.dart';
import 'messenger_document_preview_kind.dart';
import 'messenger_media_cache_scope.dart';
import 'messenger_media_file_resolver.dart';

/// Optional override for tests or host apps that manage storage themselves.
Directory Function()? messengerDownloadsDirectoryOverride;

/// Result of a user-initiated media download/save action.
class MessengerMediaDownloadResult {
  const MessengerMediaDownloadResult({
    required this.success,
    this.savedPath,
    this.message,
  });

  final bool success;
  final String? savedPath;
  final String? message;
}

/// Copies or downloads [source] into a user-accessible location:
/// images → photo gallery; documents → public Downloads / Files.
Future<MessengerMediaDownloadResult> messengerDownloadMedia({
  required BuildContext context,
  required String source,
  String? fileName,
  String? mimeType,
  Dio? dio,
}) async {
  final trimmed = source.trim();
  if (trimmed.isEmpty) {
    return const MessengerMediaDownloadResult(
      success: false,
      message: 'Nothing to download',
    );
  }

  final saveToGallery = messengerIsImageMedia(
    mimeType: mimeType,
    fileName: fileName,
    source: trimmed,
  );
  final previewKind = messengerDocumentPreviewKind(
    mimeType: mimeType,
    fileName: fileName,
    url: trimmed,
  );
  final targetName = messengerMediaDownloadFileName(
    fileName: fileName,
    source: trimmed,
    previewKind: previewKind,
  );

  final cacheScope = MessengerMediaCacheScope.maybeOf(context);
  final resolved = cacheScope != null
      ? MessengerMediaCacheScope.resolveMediaUrl(context, trimmed)
      : trimmed;

  try {
    final file = await _resolveFileForSave(
      context: context,
      trimmed: trimmed,
      resolved: resolved,
      cacheScope: cacheScope,
      dio: dio,
    );
    if (file == null) {
      return const MessengerMediaDownloadResult(
        success: false,
        message: 'File is not available on this device',
      );
    }

    if (messengerDownloadsDirectoryOverride != null) {
      final saved = await _copyToDownloads(file, targetName);
      return MessengerMediaDownloadResult(
        success: true,
        savedPath: saved.path,
        message: 'Saved to ${saved.path}',
      );
    }

    if (saveToGallery) {
      return _saveImageToGallery(file);
    }
    return _saveDocumentToPublicStorage(file, targetName);
  } catch (_) {
    return const MessengerMediaDownloadResult(
      success: false,
      message: 'Could not download file',
    );
  }
}

Future<File?> _resolveFileForSave({
  required BuildContext context,
  required String trimmed,
  required String resolved,
  required MessengerMediaCacheScope? cacheScope,
  Dio? dio,
}) async {
  if (!messengerMediaSourceIsNetwork(resolved)) {
    final local = File(resolved);
    if (await local.exists()) {
      return local;
    }
    return null;
  }

  if (cacheScope != null) {
    final headers =
        await MessengerMediaCacheScope.resolveHeaders(context, resolved);
    final cached = await cacheScope.cache.getFile(resolved, headers: headers);
    if (cached != null && await cached.exists()) {
      return cached;
    }
  }

  final resolvedFile = await messengerResolveMediaFile(
    context,
    trimmed,
    fileName: null,
    mimeType: null,
    dio: dio,
  );
  if (resolvedFile != null) {
    return resolvedFile;
  }

  if (!messengerMediaSourceIsNetwork(resolved)) {
    return null;
  }

  final networkHeaders = cacheScope != null
      ? await MessengerMediaCacheScope.resolveHeaders(context, resolved)
      : const <String, String>{};
  final bytes = await messengerFetchNetworkMediaBytes(
    resolved,
    headers: networkHeaders,
    dio: dio,
  );
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  return _writeTempFile(resolved, bytes);
}

Future<File> _writeTempFile(String url, List<int> bytes) async {
  final dir = await getTemporaryDirectory();
  final uri = Uri.tryParse(url);
  final segment = uri != null && uri.pathSegments.isNotEmpty
      ? uri.pathSegments.last
      : 'download';
  final file = File('${dir.path}/messenger_save_${url.hashCode}_$segment');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<MessengerMediaDownloadResult> _saveImageToGallery(File file) async {
  if (kIsWeb || !_platformSupportsGallerySave()) {
    return _saveViaFallbackDirectory(file, 'image.jpg');
  }
  try {
    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    if (!await Gal.hasAccess()) {
      return const MessengerMediaDownloadResult(
        success: false,
        message: 'Photo library access denied',
      );
    }
    await Gal.putImage(file.path);
    return const MessengerMediaDownloadResult(
      success: true,
      message: 'Saved to gallery',
    );
  } on GalException catch (e) {
    return MessengerMediaDownloadResult(
      success: false,
      message: e.type.message,
    );
  } catch (_) {
    return _saveViaFallbackDirectory(file, 'image.jpg');
  }
}

Future<MessengerMediaDownloadResult> _saveDocumentToPublicStorage(
  File file,
  String targetName,
) async {
  return _saveViaFallbackDirectory(file, targetName);
}

Future<MessengerMediaDownloadResult> _saveViaFallbackDirectory(
  File file,
  String targetName,
) async {
  final saved = await _copyToDownloads(file, targetName);
  return MessengerMediaDownloadResult(
    success: true,
    savedPath: saved.path,
    message: 'Saved to ${saved.path}',
  );
}

bool _platformSupportsGallerySave() {
  return Platform.isAndroid || Platform.isIOS;
}

Future<File> _copyToDownloads(File source, String targetName) async {
  final dir = await _downloadsDirectory();
  final out = await _uniqueFile(dir, targetName);
  await source.copy(out.path);
  return out;
}

Future<Directory> _downloadsDirectory() async {
  final override = messengerDownloadsDirectoryOverride;
  if (override != null) {
    final dir = override();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
  if (!kIsWeb) {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        if (!await downloads.exists()) {
          await downloads.create(recursive: true);
        }
        return downloads;
      }
    } catch (_) {}
  }
  final docs = await getApplicationDocumentsDirectory();
  final messengerDir = Directory('${docs.path}/MessengerDownloads');
  if (!await messengerDir.exists()) {
    await messengerDir.create(recursive: true);
  }
  return messengerDir;
}

Future<File> _uniqueFile(Directory dir, String fileName) async {
  var candidate = File('${dir.path}/$fileName');
  if (!await candidate.exists()) {
    return candidate;
  }
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 ? fileName.substring(dot) : '';
  var index = 1;
  while (await candidate.exists()) {
    candidate = File('${dir.path}/${stem}_$index$ext');
    index++;
  }
  return candidate;
}
