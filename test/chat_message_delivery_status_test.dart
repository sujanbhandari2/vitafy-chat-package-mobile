import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/src/client/inbox/delivery_status.dart';
import 'package:health_messenger_ui/lib/src/client/models/chat_message.dart';
import 'package:health_messenger_ui/lib/src/models/messenger_message.dart';

void main() {
  group('ChatMessage deliveryStatus parsing', () {
    test('does not map generic status field to deliveryStatus', () {
      final message = ChatMessage.fromJson({
        'id': '329',
        'conversationId': '200',
        'tenantId': '1',
        'senderId': '243',
        'type': 'TEXT',
        'content': 'hyy',
        'status': 'READ',
        'createdAt': DateTime.utc(2026, 5, 15).toIso8601String(),
      });

      expect(message.deliveryStatus, isNull);
      expect(
        messengerDeliveryStatusFor(message, currentUserId: '243'),
        MessengerDeliveryStatus.sent,
      );
    });

    test('maps explicit deliveryStatus field', () {
      final message = ChatMessage.fromJson({
        'id': '1',
        'conversationId': 'c',
        'tenantId': 't',
        'senderId': 'me',
        'type': 'TEXT',
        'content': 'x',
        'deliveryStatus': 'SEEN',
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });

      expect(message.deliveryStatus, 'SEEN');
      expect(
        messengerDeliveryStatusFor(message, currentUserId: 'me'),
        MessengerDeliveryStatus.seen,
      );
    });
  });
}
