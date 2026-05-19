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
