import '../../models/messenger_message.dart';
import '../models/chat_message.dart';

bool _isPeerUserId(String userId, String currentUserId) {
  final id = userId.trim();
  return id.isNotEmpty && id != currentUserId.trim();
}

bool _hasPeerReadReceipt(ChatMessage message, String currentUserId) {
  return message.readReceipts.any((r) => _isPeerUserId(r.userId, currentUserId));
}

bool _hasPeerDeliveredReceipt(ChatMessage message, String currentUserId) {
  return message.deliveredReceipts
      .any((r) => _isPeerUserId(r.userId, currentUserId));
}

/// Maps backend [deliveryStatus] using exact tokens only (trimmed, uppercased).
/// Substring matching is intentionally avoided so values like `UNREAD` / `NOT_READ`
/// / `UNDELIVERED` never classify as seen or delivered.
MessengerDeliveryStatus? _statusFromDeliveryStatusApi(String api) {
  if (api.isEmpty) {
    return null;
  }
  switch (api) {
    case 'SEEN':
    case 'READ':
    case 'VIEWED':
    case 'R':
      return MessengerDeliveryStatus.seen;
    case 'DELIVERED':
    case 'D':
      return MessengerDeliveryStatus.delivered;
    case 'SENT':
    case 'S':
    case 'SENDING':
      return MessengerDeliveryStatus.sent;
    default:
      return null;
  }
}

/// Outgoing tick state aligned with web `getDeliveryStatus`:
/// realtime read/delivered evidence wins over stale `deliveryStatus` from socket echoes.
MessengerDeliveryStatus messengerDeliveryStatusFor(
  ChatMessage message, {
  required String currentUserId,
}) {
  if (message.senderId != currentUserId) {
    return MessengerDeliveryStatus.none;
  }

  final api = message.deliveryStatus?.trim().toUpperCase() ?? '';
  if (api == 'SENDING') {
    return MessengerDeliveryStatus.sent;
  }

  // Socket `message_read` often updates receipts without clearing `deliveryStatus`.
  if ((message.readByCount ?? 0) >= 1 ||
      _hasPeerReadReceipt(message, currentUserId)) {
    return MessengerDeliveryStatus.seen;
  }

  final seenFromApi = _statusFromDeliveryStatusApi(api);
  if (seenFromApi == MessengerDeliveryStatus.seen) {
    return MessengerDeliveryStatus.seen;
  }

  if ((message.deliveredToCount ?? 0) >= 1 ||
      _hasPeerDeliveredReceipt(message, currentUserId)) {
    return MessengerDeliveryStatus.delivered;
  }

  if (seenFromApi == MessengerDeliveryStatus.delivered) {
    return MessengerDeliveryStatus.delivered;
  }

  if (seenFromApi == MessengerDeliveryStatus.sent) {
    return MessengerDeliveryStatus.sent;
  }

  return MessengerDeliveryStatus.sent;
}
