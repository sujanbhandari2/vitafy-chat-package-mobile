import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../media/messenger_document_preview_kind.dart';
import '../media/messenger_media_cache_scope.dart';
import '../media/messenger_media_download.dart';
import '../media/messenger_media_file_resolver.dart';
import '../theme/messenger_theme.dart';
import 'messenger_preview_chrome.dart';

/// Opens a full-screen dialog to preview a document attachment.
void openMessengerDocumentPreview(
  BuildContext context, {
  required String source,
  String? fileName,
  String? mimeType,
  ThemeData? packageDialogTheme,
}) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) {
    return;
  }
  final cacheScope = MessengerMediaCacheScope.maybeOf(context);
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (dialogContext) {
      final preview = MessengerDocumentPreviewDialog(
        source: trimmed,
        fileName: fileName,
        mimeType: mimeType,
      );
      final themed = wrapMessengerPackageDialogTheme(
        ambientContext: context,
        packageDialogTheme: packageDialogTheme,
        child: preview,
      );
      if (cacheScope == null) {
        return themed;
      }
      return MessengerMediaCacheScope(
        cache: cacheScope.cache,
        staticHeaders: cacheScope.staticHeaders,
        headersForUrl: cacheScope.headersForUrl,
        mediaBaseOrigin: cacheScope.mediaBaseOrigin,
        child: themed,
      );
    },
  );
}

/// In-app preview for PDF/text files; fallback UI for unsupported types.
class MessengerDocumentPreviewDialog extends StatefulWidget {
  const MessengerDocumentPreviewDialog({
    super.key,
    required this.source,
    this.fileName,
    this.mimeType,
  });

  final String source;
  final String? fileName;
  final String? mimeType;

  @override
  State<MessengerDocumentPreviewDialog> createState() =>
      _MessengerDocumentPreviewDialogState();
}

class _MessengerDocumentPreviewDialogState
    extends State<MessengerDocumentPreviewDialog> {
  static const int _maxTextBytes = 512 * 1024;
  bool _downloadInProgress = false;

  MessengerDocumentPreviewKind get _previewKind =>
      messengerDocumentPreviewKind(
        mimeType: widget.mimeType,
        fileName: widget.fileName,
        url: widget.source,
      );

  String get _title => messengerMediaDownloadFileName(
        fileName: widget.fileName,
        source: widget.source,
        previewKind: _previewKind,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MessengerPreviewChrome(
              title: _title,
              isDownloading: _downloadInProgress,
              onClose: () => Navigator.of(context).pop(),
              onDownload: () => unawaited(_download(context)),
            ),
            Expanded(
              child: _DocumentPreviewBody(
                source: widget.source,
                fileName: widget.fileName,
                mimeType: widget.mimeType,
                previewKind: _previewKind,
                maxTextBytes: _maxTextBytes,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    if (_downloadInProgress) {
      return;
    }
    setState(() => _downloadInProgress = true);
    try {
      final result = await messengerDownloadMedia(
        context: context,
        source: widget.source,
        fileName: widget.fileName,
        mimeType: widget.mimeType,
      );
      if (!mounted) {
        return;
      }
      if (result.success) {
        showMessengerPreviewSnackBar(
          context,
          result.message ?? 'Download complete',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadInProgress = false);
      }
    }
  }
}

class _DocumentPreviewBody extends StatefulWidget {
  const _DocumentPreviewBody({
    required this.source,
    this.fileName,
    this.mimeType,
    required this.previewKind,
    required this.maxTextBytes,
  });

  final String source;
  final String? fileName;
  final String? mimeType;
  final MessengerDocumentPreviewKind previewKind;
  final int maxTextBytes;

  @override
  State<_DocumentPreviewBody> createState() => _DocumentPreviewBodyState();
}

class _DocumentPreviewBodyState extends State<_DocumentPreviewBody> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _resolve();
  }

  Future<_ResolvedPreview>? _future;

  Future<_ResolvedPreview> _resolve() async {
    final file = await messengerResolveMediaFile(
      context,
      widget.source,
      fileName: widget.fileName,
      mimeType: widget.mimeType,
    );
    if (file == null) {
      return _ResolvedPreview.missing;
    }
    final bytes = await file.readAsBytes();
    var effectiveKind = widget.previewKind;
    if (effectiveKind == MessengerDocumentPreviewKind.unsupported ||
        effectiveKind == MessengerDocumentPreviewKind.pdf) {
      effectiveKind = messengerSniffPreviewKindFromBytes(bytes);
    }
    switch (effectiveKind) {
      case MessengerDocumentPreviewKind.pdf:
        if (!messengerBytesLookLikePdf(bytes)) {
          return _ResolvedPreview.invalidPdf;
        }
        final pdfFile = await messengerMaterializePreviewFile(
          file,
          previewKind: MessengerDocumentPreviewKind.pdf,
          fileName: widget.fileName,
        );
        return _ResolvedPreview.pdf(
          file: pdfFile,
          bytes: Uint8List.fromList(bytes),
        );
      case MessengerDocumentPreviewKind.text:
        final bytes = await file.readAsBytes();
        final slice = bytes.length > widget.maxTextBytes
            ? bytes.sublist(0, widget.maxTextBytes)
            : bytes;
        final text = String.fromCharCodes(slice);
        final truncated = bytes.length > widget.maxTextBytes;
        return _ResolvedPreview.text(text, truncated: truncated);
      case MessengerDocumentPreviewKind.unsupported:
        return _ResolvedPreview.unsupported;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResolvedPreview>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          );
        }
        final data = snapshot.data;
        if (data == null || data.kind == _PreviewBodyKind.missing) {
          return const _PreviewFallback(
            message: 'Preview not available',
            detail: 'File could not be loaded on this device.',
          );
        }
        if (data.kind == _PreviewBodyKind.unsupported) {
          return const _PreviewFallback(message: 'Preview not available');
        }
        if (data.kind == _PreviewBodyKind.invalidPdf) {
          return const _PreviewFallback(
            message: 'Preview not available',
            detail:
                'The file could not be opened as a PDF. It may require login or be in an unsupported format.',
          );
        }
        if (data.kind == _PreviewBodyKind.text) {
          return _TextPreview(
            text: data.text ?? '',
            truncated: data.truncated,
          );
        }
        if (data.kind == _PreviewBodyKind.pdf &&
            data.file != null &&
            data.bytes != null) {
          return _PdfPreview(bytes: data.bytes!);
        }
        return const _PreviewFallback(message: 'Preview not available');
      },
    );
  }
}

enum _PreviewBodyKind { missing, unsupported, invalidPdf, text, pdf }

class _ResolvedPreview {
  const _ResolvedPreview._({
    required this.kind,
    this.file,
    this.bytes,
    this.text,
    this.truncated = false,
  });

  final _PreviewBodyKind kind;
  final File? file;
  final Uint8List? bytes;
  final String? text;
  final bool truncated;

  static const missing = _ResolvedPreview._(kind: _PreviewBodyKind.missing);
  static const unsupported =
      _ResolvedPreview._(kind: _PreviewBodyKind.unsupported);
  static const invalidPdf =
      _ResolvedPreview._(kind: _PreviewBodyKind.invalidPdf);

  factory _ResolvedPreview.pdf({
    required File file,
    required Uint8List bytes,
  }) =>
      _ResolvedPreview._(
        kind: _PreviewBodyKind.pdf,
        file: file,
        bytes: bytes,
      );

  factory _ResolvedPreview.text(String text, {required bool truncated}) =>
      _ResolvedPreview._(
        kind: _PreviewBodyKind.text,
        text: text,
        truncated: truncated,
      );
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({required this.bytes});

  final Uint8List bytes;

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  PdfControllerPinch? _controller;
  Object? _error;

  static final _pdfBuilders = PdfViewPinchBuilders(
    options: const DefaultBuilderOptions(),
    documentLoaderBuilder: (_) => const Center(
      child: CircularProgressIndicator(color: Colors.white70),
    ),
    pageLoaderBuilder: (_) => const Center(
      child: CircularProgressIndicator(color: Colors.white70),
    ),
    errorBuilder: (_, error) => _PreviewFallback(
      message: 'Preview not available',
      detail: error.toString(),
    ),
  );

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    try {
      setState(() {
        _controller = PdfControllerPinch(
          document: PdfDocument.openData(widget.bytes),
        );
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const _PreviewFallback(
        message: 'Preview not available',
        detail: 'This PDF could not be opened.',
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    return PdfViewPinch(
      controller: controller,
      builders: _pdfBuilders,
      scrollDirection: Axis.vertical,
      backgroundDecoration: const BoxDecoration(color: Colors.white),
      onDocumentError: (error) {
        if (!mounted) {
          return;
        }
        setState(() => _error = error);
      },
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({
    required this.text,
    required this.truncated,
  });

  final String text;
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (truncated)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Showing the first part of this file.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            SelectableText(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback({
    required this.message,
    this.detail,
  });

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.visibility_off_outlined,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
