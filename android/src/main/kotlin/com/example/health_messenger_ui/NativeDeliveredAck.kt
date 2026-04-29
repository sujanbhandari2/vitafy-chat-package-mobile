package com.example.health_messenger_ui

import java.net.HttpURLConnection
import java.net.URL

internal object NativeDeliveredAck {
    /**
     * POST empty JSON body with configured headers. Returns true on 2xx.
     */
    fun postDelivered(config: PushConfigSnapshot, conversationId: String, messageId: String): Boolean {
        val urlString = config.buildDeliveredUrl(conversationId, messageId)
        val url = URL(urlString)
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 15_000
            readTimeout = 20_000
            setRequestProperty("Content-Type", "application/json")
        }
        for ((k, v) in config.headersMap()) {
            if (k.isNotBlank() && v.isNotBlank()) {
                conn.setRequestProperty(k, v)
            }
        }
        return try {
            conn.outputStream.use { os ->
                os.write("{}".toByteArray(Charsets.UTF_8))
            }
            val code = conn.responseCode
            code in 200..299
        } catch (_: Exception) {
            false
        } finally {
            conn.disconnect()
        }
    }
}
