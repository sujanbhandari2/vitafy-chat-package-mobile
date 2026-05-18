import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/inbox/message_delivery_merge.dart';
import 'package:health_messenger_ui/lib/src/client/models/chat_message.dart';

ChatMessage _message({
  String? deliveryStatus,
  List<Map<String, dynamic>> deliveredReceipts = const [],
  List<Map<String, dynamic>> readReceipts = const [],
  int? deliveredToCount,
  int? readByCount,
}) {
  return ChatMessage.fromJson({
    'id': 'm1',
    'conversationId': 'c1',
    'tenantId': 't',
    'senderId': 's1',
    'type': 'TEXT',
    'content': 'hi',
    'createdAt': DateTime.utc(2020).toIso8601String(),
    if (deliveryStatus != null) 'deliveryStatus': deliveryStatus,
    'deliveredReceipts': deliveredReceipts,
    'readReceipts': readReceipts,
    if (deliveredToCount != null) 'deliveredToCount': deliveredToCount,
    if (readByCount != null) 'readByCount': readByCount,
  });
}

void main() {
  group('mergeMessageDeliveryReadSnapshot', () {
    test('keeps delivered receipts when sparse socket echo omits them', () {
      final existing = _message(
        deliveredReceipts: [
          {
            'id': 'm1:u2:t',
            'messageId': 'm1',
            'userId': 'u2',
            'deliveredAt': '2020-01-01T00:00:01.000Z',
          },
        ],
      );
      final incoming = _message(deliveryStatus: 'SENT');
      final merged = mergeMessageDeliveryReadSnapshot(existing, incoming);
      expect(merged.deliveredReceipts, hasLength(1));
      expect(merged.deliveredReceipts.first.userId, 'u2');
    });

    test('unions read receipts from both sides', () {
      final existing = _message(
        readReceipts: [
          {
            'id': 'm1:u2:r1',
            'messageId': 'm1',
            'userId': 'u2',
            'readAt': '2020-01-01T00:00:02.000Z',
          },
        ],
      );
      final incoming = _message(
        readReceipts: [
          {
            'id': 'm1:u3:r1',
            'messageId': 'm1',
            'userId': 'u3',
            'readAt': '2020-01-01T00:00:03.000Z',
          },
        ],
      );
      final merged = mergeMessageDeliveryReadSnapshot(existing, incoming);
      expect(
        merged.readReceipts.map((r) => r.userId).toList()..sort(),
        ['u2', 'u3'],
      );
    });

    test('keeps max aggregate counts', () {
      final existing = _message(deliveredToCount: 2, readByCount: 1);
      final incoming = _message(deliveredToCount: 1, readByCount: 2);
      final merged = mergeMessageDeliveryReadSnapshot(existing, incoming);
      expect(merged.deliveredToCount, 2);
      expect(merged.readByCount, 2);
    });
  });
}
