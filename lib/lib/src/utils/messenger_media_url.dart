/// Normalizes API origin for joining relative attachment paths (matches web
/// `toAbsoluteMediaUrl`).
String messengerNormalizeMediaOrigin(String base) {
  var origin = base.trim();
  if (origin.isEmpty) {
    return '';
  }
  if (origin.endsWith('/')) {
    origin = origin.substring(0, origin.length - 1);
  }
  return origin;
}

/// Server origin used for relative media URLs (matches web `getServerOrigin`).
///
/// Chat REST [apiBaseUrl] is often `https://host` or `https://host/api`. Object
/// keys like `/uploads/...` are served from the host origin, not under `/api`.
String messengerMediaServerOrigin(String apiBaseUrl) {
  var origin = messengerNormalizeMediaOrigin(apiBaseUrl);
  if (origin.toLowerCase().endsWith('/api')) {
    origin = origin.substring(0, origin.length - 4);
  }
  return origin;
}

/// Resolves attachment [url] to an absolute http(s) URL when [baseOrigin] is set.
String messengerAbsoluteMediaUrl(
  String url, {
  String? baseOrigin,
}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('data:') ||
      lower.startsWith('blob:') ||
      lower.startsWith('file://')) {
    return trimmed;
  }
  final origin = messengerNormalizeMediaOrigin(baseOrigin ?? '');
  if (origin.isEmpty) {
    return trimmed;
  }
  if (trimmed.startsWith('/')) {
    return '$origin$trimmed';
  }
  return '$origin/$trimmed';
}

/// Whether [source] should be loaded over the network (after absolutizing).
bool messengerMediaSourceIsNetwork(String source) {
  final uri = Uri.tryParse(source.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

/// Whether [url] is same-host as [mediaBaseOrigin] (chat API / app server).
///
/// Uploaded attachments are public S3/CDN URLs. Web loads them with bare
/// `<img src>` (no auth). Sending `Authorization` / `X-Api-Key` to those hosts
/// commonly returns 400/403 and surfaces as "Unable to load image".
bool messengerMediaUrlIsSameOrigin(
  String url, {
  String? mediaBaseOrigin,
}) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) {
    return false;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return false;
  }
  final origin = messengerNormalizeMediaOrigin(mediaBaseOrigin ?? '');
  if (origin.isEmpty) {
    return false;
  }
  final originUri = Uri.tryParse(origin);
  if (originUri == null || originUri.host.isEmpty) {
    return false;
  }
  return uri.host.toLowerCase() == originUri.host.toLowerCase();
}

/// Returns [headers] only for same-origin media; empty for public CDN/S3 URLs.
Map<String, String> messengerHeadersForMediaUrl(
  String url, {
  required Map<String, String> headers,
  String? mediaBaseOrigin,
}) {
  if (headers.isEmpty) {
    return const {};
  }
  if (messengerMediaUrlIsSameOrigin(url, mediaBaseOrigin: mediaBaseOrigin)) {
    return headers;
  }
  return const {};
}
