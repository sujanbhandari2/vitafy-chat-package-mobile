package com.example.health_messenger_ui

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class ChatFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        if (data.isEmpty()) {
            return
        }
        val config = PushNativeStore.readConfig(this) ?: run {
            Log.d(TAG, "Push config not synced; skipping native ACK")
            return
        }
        val typeKey = config.chatTypeDataKey
        val typeVal = config.chatTypeValue
        val incomingType = data[typeKey] ?: data[typeKey.replace("data.", "")] ?: ""
        if (incomingType != typeVal) {
            return
        }
        val conversationId = data["conversationId"] ?: data["conversation_id"] ?: return
        val messageId = data["messageId"] ?: data["message_id"] ?: return
        val ok = NativeDeliveredAck.postDelivered(config, conversationId, messageId)
        if (!ok) {
            PushNativeStore.enqueueAck(this, conversationId, messageId)
        }
        HealthMessengerUiPlugin.emitIncomingPush(
            mapOf(
                "kind" to "incoming_chat_message",
                "conversationId" to conversationId,
                "messageId" to messageId,
                "nativeAckSucceeded" to ok,
            ),
        )
    }

    override fun onNewToken(token: String) {
        HealthMessengerUiPlugin.emitIncomingPush(
            mapOf(
                "kind" to "fcm_token_refresh",
                "token" to token,
            ),
        )
    }

    companion object {
        private const val TAG = "ChatFcm"
    }
}
