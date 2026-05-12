typedef ChatLogger = void Function(
  String message, {
  Object? data,
});

String redactApiKey(String value) {
  if (value.length <= 8) {
    return '***';
  }
  return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
}

/// Redacts `Authorization` values (`Bearer <jwt>` or raw token) for logs.
String redactAuthorizationHeader(String value) {
  final v = value.trim();
  if (v.length <= 12) {
    return '***';
  }
  const prefix = 'bearer ';
  if (v.length > prefix.length &&
      v.toLowerCase().startsWith(prefix)) {
    final token = v.substring(prefix.length).trim();
    if (token.length <= 8) {
      return 'Bearer ***';
    }
    return 'Bearer ${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }
  if (v.length <= 8) {
    return '***';
  }
  return '${v.substring(0, 4)}...${v.substring(v.length - 4)}';
}
