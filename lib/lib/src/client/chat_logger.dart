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
