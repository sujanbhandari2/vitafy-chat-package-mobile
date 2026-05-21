import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/messenger_media_url.dart';
import 'messenger_document_preview_kind.dart';
import 'messenger_media_cache_scope.dart';

/// Resolves [source] to a readable on-device [File] when possible.
///
/// Uses cache/local paths first, then downloads remote media into a temp file
/// so PDF/text preview can open attachments that are not yet cached.
Future<File?> messengerResolveMediaFile(
  BuildContext context,
  String source, {
  String? fileName,
  String? mimeType,
  Dio? dio,
}) async {
  final trimmed = source.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final resolved = MessengerMediaCacheScope.maybeOf(context) != null
      ? MessengerMediaCacheScope.resolveMediaUrl(context, trimmed)
      : trimmed;
  if (resolved.isEmpty) {
    return null;
  }

  final previewKind = messengerDocumentPreviewKind(
    mimeType: mimeType,
    fileName: fileName,
    url: resolved,
  );
  final materializedName = messengerMediaDownloadFileName(
    fileName: fileName,
    source: resolved,
    previewKind: previewKind,
  );

  if (!messengerMediaSourceIsNetwork(resolved)) {
    final file = File(resolved);
    if (await file.exists()) {
      return messengerMaterializePreviewFile(
        file,
        previewKind: previewKind,
        fileName: materializedName,
      );
    }
    return null;
  }

  final scope = MessengerMediaCacheScope.maybeOf(context);
  final headers = messengerMediaSourceIsNetwork(resolved)
      ? await MessengerMediaCacheScope.resolveHeaders(context, resolved)
      : const <String, String>{};
  if (scope != null) {
    final cached = await scope.cache.getFile(resolved, headers: headers);
    if (cached != null && await cached.exists()) {
      final materialized = await messengerMaterializePreviewFile(
        cached,
        previewKind: previewKind,
        fileName: materializedName,
      );
      if (previewKind != MessengerDocumentPreviewKind.pdf ||
          messengerBytesLookLikePdf(await materialized.readAsBytes())) {
        return materialized;
      }
    }
  }

  final bytes = await messengerFetchNetworkMediaBytes(
    resolved,
    headers: headers,
    dio: dio,
  );
  if (bytes == null || bytes.isEmpty) {
    return null;
  }

  final temp = await _writeTempPreviewFile(
    resolved,
    bytes,
    materializedName,
  );
  return messengerMaterializePreviewFile(
    temp,
    previewKind: previewKind,
    fileName: materializedName,
  );
}

/// Downloads [url] when cache/local resolution is unavailable.
Future<List<int>?> messengerFetchNetworkMediaBytes(
  String url, {
  Map<String, String> headers = const {},
  Dio? dio,
}) async {
  final normalized = url.trim();
  if (normalized.isEmpty || !messengerMediaSourceIsNetwork(normalized)) {
    return null;
  }
  try {
    final client = dio ?? Dio();
    final response = await client.get<List<int>>(
      normalized,
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
      ),
    );
    return response.data;
  } catch (_) {
    return null;
  }
}

/// Copies [source] to a temp path with an extension when required by [previewKind].
Future<File> messengerMaterializePreviewFile(
  File source, {
  required MessengerDocumentPreviewKind previewKind,
  String? fileName,
}) async {
  final ext = _previewExtension(previewKind);
  if (ext == null || source.path.toLowerCase().endsWith(ext)) {
    return source;
  }
  final dir = await getTemporaryDirectory();
  final safeName = (fileName ?? 'preview').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final stem = safeName.toLowerCase().endsWith(ext)
      ? safeName.substring(0, safeName.length - ext.length)
      : safeName;
  final out = File('${dir.path}/${stem}_${source.path.hashCode}$ext');
  if (await out.exists()) {
    return out;
  }
  await source.copy(out.path);
  return out;
}

String? _previewExtension(MessengerDocumentPreviewKind kind) {
  switch (kind) {
    case MessengerDocumentPreviewKind.pdf:
      return '.pdf';
    case MessengerDocumentPreviewKind.text:
    case MessengerDocumentPreviewKind.unsupported:
      return null;
  }
}

Future<File> _writeTempPreviewFile(
  String url,
  List<int> bytes,
  String fileName,
) async {
  final dir = await getTemporaryDirectory();
  final safe = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File('${dir.path}/messenger_fetch_${url.hashCode}_$safe');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
