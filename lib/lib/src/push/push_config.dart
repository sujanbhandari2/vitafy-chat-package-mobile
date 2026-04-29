/// Gating and key mapping for message-only FCM payloads.
class MessengerPushGate {
  const MessengerPushGate({
    this.typeDataKey = 'type',
    this.typeValue = 'CHAT_MESSAGE',
    this.messageIdKeys = const ['messageId', 'message_id'],
    this.conversationIdKeys = const ['conversationId', 'conversation_id'],
    this.tenantIdKeys = const ['tenantId', 'tenant_id'],
    this.senderIdKeys = const ['senderId', 'sender_id'],
  });

  final String typeDataKey;
  final String typeValue;
  final List<String> messageIdKeys;
  final List<String> conversationIdKeys;
  final List<String> tenantIdKeys;
  final List<String> senderIdKeys;
}
