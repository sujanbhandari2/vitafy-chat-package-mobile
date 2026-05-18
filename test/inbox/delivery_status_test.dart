import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/inbox/delivery_status.dart';
import 'package:health_messenger_ui/lib/src/client/models/chat_message.dart';
import 'package:health_messenger_ui/lib/src/models/messenger_message.dart';

ChatMessage _outgoing({
  String? deliveryStatus,
  List<Map<String, dynamic>> readReceipts = const [],
  List<Map<String, dynamic>> deliveredReceipts = const [],
}) {
  return ChatMessage.fromJson({
    'id': 'm1',
    'conversationId': 'c1',
    'tenantId': 't',
    'senderId': 'me',
    'type': 'TEXT',
    'content': 'x',
    'createdAt': DateTime.utc(2026).toIso8601String(),
    if (deliveryStatus != null) 'deliveryStatus': deliveryStatus,
    'readReceipts': readReceipts,
    'deliveredReceipts': deliveredReceipts,
  });
}

void main() {
  group('messengerDeliveryStatusFor', () {
    test('prefers API SEEN', () {
      final s = messengerDeliveryStatusFor(
        _outgoing(deliveryStatus: 'SEEN'),
        currentUserId: 'me',
      );
      expect(s, MessengerDeliveryStatus.seen);
    });

    test('prefers exact API READ', () {
      final s = messengerDeliveryStatusFor(
        _outgoing(deliveryStatus: 'READ'),
        currentUserId: 'me',
      );
      expect(s, MessengerDeliveryStatus.seen);
    });

    test('case-insensitive READ maps to seen', () {
      final s = messengerDeliveryStatusFor(
        _outgoing(deliveryStatus: 'read'),
        currentUserId: 'me',
      );
      expect(s, MessengerDeliveryStatus.seen);
    });

    test('UNREAD does not substring-match as seen', () {
      final s = messengerDeliveryStatusFor(
        _outgoing(deliveryStatus: 'UNREAD'),
        currentUserId: 'me',
      );
      expect(s, MessengerDeliveryStatus.sent);
    });

    test('NOT_READ does not substring-match as seen', () {
      final s = messengerDeliveryStatusFor(
        _outgoing(deliveryStatus: 'NOT_READ'),
        currentUserId: 'me',
      );
      expect(s, MessengerDeliveryStatus.sent);
    });

    test('UNDELIVERED does not substring-match as delivered', () {
      final s = messengerDeliveryStatusFor(
        _outgoing(deliveryStatus: 'UNDELIVERED'),
        currentUserId: 'me',
      );
      expect(s, MessengerDeliveryStatus.sent);
    });

    test('peer read receipt wins over stale deliveryStatus SENT', () {
      final s = messengerDeliveryStatusFor(
        _outgoing(
          deliveryStatus: 'SENT',
          readReceipts: [
            {
              'id': 'r1',
              'messageId': 'm1',
              'userId': 'peer',
              'readAt': DateTime.utc(2026).toIso8601String(),
            },
          ],
        ),
        currentUserId: 'me',
      );
      expect(s, MessengerDeliveryStatus.seen);
    });

    test('deliveredToCount wins over stale deliveryStatus SENT', () {
      final m = ChatMessage.fromJson({
        'id': 'm1',
        'conversationId': 'c1',
        'tenantId': 't',
        'senderId': 'me',
        'type': 'TEXT',
        'content': 'x',
        'deliveryStatus': 'SENT',
        'deliveredToCount': 1,
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });
      expect(
        messengerDeliveryStatusFor(m, currentUserId: 'me'),
        MessengerDeliveryStatus.delivered,
      );
    });

    test('peer delivered receipt wins over stale deliveryStatus SENT', () {
      final s = messengerDeliveryStatusFor(
        _outgoing(
          deliveryStatus: 'SENT',
          deliveredReceipts: [
            {
              'id': 'd1',
              'messageId': 'm1',
              'userId': 'peer',
              'deliveredAt': DateTime.utc(2026).toIso8601String(),
            },
          ],
        ),
        currentUserId: 'me',
      );
      expect(s, MessengerDeliveryStatus.delivered);
    });

    test('peer read receipt implies seen', () {
      final s = messengerDeliveryStatusFor(
        _outgoing(
          readReceipts: [
            {
              'id': 'r1',
              'messageId': 'm1',
              'userId': 'peer',
              'readAt': DateTime.utc(2026).toIso8601String(),
            },
          ],
        ),
        currentUserId: 'me',
      );
      expect(s, MessengerDeliveryStatus.seen);
    });

    test('own read receipt does not imply seen', () {
      final s = messengerDeliveryStatusFor(
        _outgoing(
          readReceipts: [
            {
              'id': 'r1',
              'messageId': 'm1',
              'userId': 'me',
              'readAt': DateTime.utc(2026).toIso8601String(),
            },
          ],
        ),
        currentUserId: 'me',
      );
      expect(s, MessengerDeliveryStatus.sent);
    });

    test('incoming message is none', () {
      final m = ChatMessage.fromJson({
        'id': 'm1',
        'conversationId': 'c1',
        'tenantId': 't',
        'senderId': 'peer',
        'type': 'TEXT',
        'content': 'x',
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });
      expect(
        messengerDeliveryStatusFor(m, currentUserId: 'me'),
        MessengerDeliveryStatus.none,
      );
    });
  });
}
