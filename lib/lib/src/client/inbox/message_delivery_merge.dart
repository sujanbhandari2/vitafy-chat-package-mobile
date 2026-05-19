import '../models/chat_message.dart';

/// Unions delivery/read receipts and aggregate counts so sparse realtime or REST
/// payloads do not regress ticks (web `mergeMessageDeliveryReadSnapshot` parity).
ChatMessage mergeMessageDeliveryReadSnapshot(
  ChatMessage existing,
  ChatMessage incoming,
) {
  final delByUser = <String, DeliveredReceipt>{};
  for (final r in existing.deliveredReceipts) {
    if (r.userId.isNotEmpty) {
      delByUser[r.userId] = r;
    }
  }
  for (final r in incoming.deliveredReceipts) {
    if (r.userId.isNotEmpty) {
      delByUser[r.userId] = r;
    }
  }

  final readByUser = <String, ReadReceipt>{};
  for (final r in existing.readReceipts) {
    if (r.userId.isNotEmpty) {
      readByUser[r.userId] = r;
    }
  }
  for (final r in incoming.readReceipts) {
    if (r.userId.isNotEmpty) {
      readByUser[r.userId] = r;
    }
  }

  final deliveredToCount = _maxCount(
    existing.deliveredToCount,
    incoming.deliveredToCount,
  );
  final readByCount = _maxCount(existing.readByCount, incoming.readByCount);

  return incoming.copyWith(
    deliveredReceipts:
        delByUser.isEmpty ? incoming.deliveredReceipts : delByUser.values.toList(),
    readReceipts:
        readByUser.isEmpty ? incoming.readReceipts : readByUser.values.toList(),
    deliveredToCount: deliveredToCount,
    readByCount: readByCount,
  );
}

int _maxCount(int? a, int? b) {
  final left = a ?? 0;
  final right = b ?? 0;
  return left > right ? left : right;
}

/// Applies a socket `message_delivered` receipt to [message] (idempotent per user).
ChatMessage applyDeliveredReceiptToMessage(
  ChatMessage message,
  DeliveredReceipt receipt,
) {
  if (message.id != receipt.messageId) {
    return message;
  }
  final next = List<DeliveredReceipt>.from(message.deliveredReceipts)
    ..removeWhere((item) => item.userId == receipt.userId)
    ..add(receipt);
  // Realtime receipt payloads can be sparse (missing peer id/count fields), so
  // raise aggregate delivery evidence immediately instead of waiting for a REST
  // refetch to advance outgoing ticks.
  return message.copyWith(
    deliveredReceipts: next,
    deliveredToCount: _maxCount(message.deliveredToCount, 1),
  );
}

/// Applies a socket `message_read` receipt to [message] (idempotent per user).
ChatMessage applyReadReceiptToMessage(
  ChatMessage message,
  ReadReceipt receipt,
) {
  if (message.id != receipt.messageId) {
    return message;
  }
  final next = List<ReadReceipt>.from(message.readReceipts)
    ..removeWhere((item) => item.userId == receipt.userId)
    ..add(receipt);
  // Read implies delivered; lift both aggregates so status updates in-place even
  // when socket echoes omit peer identifiers.
  return message.copyWith(
    readReceipts: next,
    readByCount: _maxCount(message.readByCount, 1),
    deliveredToCount: _maxCount(message.deliveredToCount, 1),
  );
}
