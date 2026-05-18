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
  return message.copyWith(deliveredReceipts: next);
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
  return message.copyWith(readReceipts: next);
}
