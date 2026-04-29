import 'push_config.dart';
import 'push_models.dart';

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final k in keys) {
    final v = data[k];
    if (v == null) {
      continue;
    }
    final s = v.toString().trim();
    if (s.isNotEmpty) {
      return s;
    }
  }
  return null;
}

/// Parses flat FCM/APNs `data` maps (string values) into [MessengerPushPayload].
MessengerPushPayload? parseMessengerPushPayload(
  Map<String, dynamic> data,
  MessengerPushGate gate,
) {
  final type = data[gate.typeDataKey]?.toString().trim() ?? '';
  if (type != gate.typeValue) {
    return null;
  }
  final messageId = _firstString(data, gate.messageIdKeys);
  final conversationId = _firstString(data, gate.conversationIdKeys);
  if (messageId == null || conversationId == null) {
    return null;
  }
  return MessengerPushPayload(
    messageId: messageId,
    conversationId: conversationId,
    tenantId: _firstString(data, gate.tenantIdKeys),
    senderId: _firstString(data, gate.senderIdKeys),
    raw: Map<String, dynamic>.from(data),
  );
}

void _mergeFlatMap(Map<String, dynamic> target, Map<dynamic, dynamic> source) {
  source.forEach((key, value) {
    if (value is Map) {
      _mergeFlatMap(target, value);
    } else {
      target[key.toString()] = value;
    }
  });
}

/// Flattens common nested shapes (`data` sub-map) into a single map.
Map<String, dynamic> flattenPushDataMap(Map<String, dynamic> root) {
  final out = <String, dynamic>{};
  _mergeFlatMap(out, root);
  final nested = root['data'];
  if (nested is Map) {
    _mergeFlatMap(out, Map<dynamic, dynamic>.from(nested));
  }
  return out;
}
