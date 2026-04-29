import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_push.dart';

void main() {
  const gate = MessengerPushGate();

  test('parseMessengerPushPayload accepts canonical keys', () {
    final payload = parseMessengerPushPayload(
      {
        'type': 'CHAT_MESSAGE',
        'messageId': 'm1',
        'conversationId': 'c1',
        'tenantId': 't1',
      },
      gate,
    );
    expect(payload, isNotNull);
    expect(payload!.messageId, 'm1');
    expect(payload.conversationId, 'c1');
    expect(payload.tenantId, 't1');
  });

  test('parseMessengerPushPayload accepts snake_case keys', () {
    final payload = parseMessengerPushPayload(
      {
        'type': 'CHAT_MESSAGE',
        'message_id': 'mid',
        'conversation_id': 'cid',
      },
      gate,
    );
    expect(payload, isNotNull);
    expect(payload!.messageId, 'mid');
    expect(payload.conversationId, 'cid');
  });

  test('parseMessengerPushPayload returns null when type mismatches', () {
    expect(
      parseMessengerPushPayload(
        {'type': 'OTHER', 'messageId': 'm', 'conversationId': 'c'},
        gate,
      ),
      isNull,
    );
  });

  test('parseMessengerPushPayload returns null when ids missing', () {
    expect(
      parseMessengerPushPayload(
        {'type': 'CHAT_MESSAGE'},
        gate,
      ),
      isNull,
    );
  });

  test('flattenPushDataMap merges nested data map', () {
    final flat = flattenPushDataMap({
      'aps': {'alert': 'x'},
      'data': {
        'type': 'CHAT_MESSAGE',
        'messageId': 'm2',
        'conversationId': 'c2',
      },
    });
    final payload = parseMessengerPushPayload(flat, gate);
    expect(payload, isNotNull);
    expect(payload!.messageId, 'm2');
  });
}
