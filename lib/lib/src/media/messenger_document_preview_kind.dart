/// In-app preview strategy for a document attachment.
enum MessengerDocumentPreviewKind {
  pdf,
  text,
  unsupported,
}

/// Detects whether a file can be rendered inside the package preview dialog.
MessengerDocumentPreviewKind messengerDocumentPreviewKind({
  String? mimeType,
  String? fileName,
  String? url,
}) {
  final mime = (mimeType ?? '').trim().toLowerCase();
  if (mime == 'application/pdf' ||
      mime.endsWith('/pdf') ||
      mime == 'application/x-pdf' ||
      mime == 'application/acrobat' ||
      mime == 'applications/vnd.pdf') {
    return MessengerDocumentPreviewKind.pdf;
  }
  if (mime == 'application/octet-stream') {
    final name = _combinedName(fileName, url).toLowerCase();
    if (name.endsWith('.pdf')) {
      return MessengerDocumentPreviewKind.pdf;
    }
  }
  if (mime.startsWith('text/') ||
      mime == 'application/json' ||
      mime == 'application/xml' ||
      mime == 'application/javascript') {
    return MessengerDocumentPreviewKind.text;
  }

  final name = _combinedName(fileName, url).toLowerCase();
  if (name.endsWith('.pdf')) {
    return MessengerDocumentPreviewKind.pdf;
  }
  if (_textExtensions.any(name.endsWith)) {
    return MessengerDocumentPreviewKind.text;
  }
  return MessengerDocumentPreviewKind.unsupported;
}

/// True when [bytes] begin with the PDF magic header (`%PDF`).
bool messengerBytesLookLikePdf(List<int> bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;
}

/// Infers preview kind from raw file bytes (e.g. after download).
MessengerDocumentPreviewKind messengerSniffPreviewKindFromBytes(
  List<int> bytes,
) {
  if (messengerBytesLookLikePdf(bytes)) {
    return MessengerDocumentPreviewKind.pdf;
  }
  return MessengerDocumentPreviewKind.unsupported;
}

/// Whether [source] should be saved to the device photo gallery (not Downloads).
bool messengerIsImageMedia({
  String? mimeType,
  String? fileName,
  required String source,
}) {
  final mime = (mimeType ?? '').trim().toLowerCase();
  if (mime.startsWith('image/')) {
    return true;
  }
  final name = _combinedName(fileName, source).toLowerCase();
  return RegExp(r'\.(jpe?g|png|gif|webp|bmp|heic|heif|avif)$').hasMatch(name);
}

const _textExtensions = <String>{
  '.txt',
  '.text',
  '.md',
  '.markdown',
  '.csv',
  '.log',
  '.json',
  '.xml',
  '.html',
  '.htm',
  '.yaml',
  '.yml',
};

String _combinedName(String? fileName, String? url) {
  final fromName = (fileName ?? '').trim();
  if (fromName.isNotEmpty) {
    return fromName;
  }
  final trimmed = (url ?? '').trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.last;
  }
  return trimmed;
}

/// Suggested download/save filename for [source].
String messengerMediaDownloadFileName({
  String? fileName,
  required String source,
  MessengerDocumentPreviewKind? previewKind,
}) {
  final fromName = (fileName ?? '').trim();
  if (fromName.isNotEmpty) {
    return _sanitizeFileName(fromName);
  }
  final fromUrl = _combinedName(null, source);
  if (fromUrl.isNotEmpty) {
    return _sanitizeFileName(fromUrl);
  }
  switch (previewKind) {
    case MessengerDocumentPreviewKind.pdf:
      return 'document.pdf';
    case MessengerDocumentPreviewKind.text:
      return 'document.txt';
    case MessengerDocumentPreviewKind.unsupported:
    case null:
      return 'download';
  }
}

String _sanitizeFileName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return cleaned.isEmpty ? 'download' : cleaned;
}
