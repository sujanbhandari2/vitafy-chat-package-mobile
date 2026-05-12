import '../../models/messenger_message.dart';
import '../models/chat_message.dart';

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
      // No dedicated enum; treat like web "sending" tick as single-check sent.
      return MessengerDeliveryStatus.sent;
    default:
      return null;
  }
}

/// Outgoing tick state: prefers API [ChatMessage.deliveryStatus], then receipts
/// from peers (not the sender).
MessengerDeliveryStatus messengerDeliveryStatusFor(
  ChatMessage message, {
  required String currentUserId,
}) {
  if (message.senderId != currentUserId) {
    return MessengerDeliveryStatus.none;
  }

  final api = message.deliveryStatus?.trim().toUpperCase() ?? '';
  final fromApi = _statusFromDeliveryStatusApi(api);
  if (fromApi != null) {
    return fromApi;
  }

  final peerRead = message.readReceipts.any(
    (r) => r.userId.isNotEmpty && r.userId != currentUserId,
  );
  if (peerRead) {
    return MessengerDeliveryStatus.seen;
  }
  final peerDelivered = message.deliveredReceipts.any(
    (r) => r.userId.isNotEmpty && r.userId != currentUserId,
  );
  if (peerDelivered) {
    return MessengerDeliveryStatus.delivered;
  }
  return MessengerDeliveryStatus.sent;
}
