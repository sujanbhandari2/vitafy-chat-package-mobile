import '../../models/messenger_message.dart';
import '../models/chat_message.dart';

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
  if (api.contains('SEEN') ||
      api.contains('READ') ||
      api == 'R' ||
      api.contains('VIEWED')) {
    return MessengerDeliveryStatus.seen;
  }
  if (api.contains('DELIVERED') || api == 'D') {
    return MessengerDeliveryStatus.delivered;
  }
  if (api.contains('SENT') || api == 'S') {
    return MessengerDeliveryStatus.sent;
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
