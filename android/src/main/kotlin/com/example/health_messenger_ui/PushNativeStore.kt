package com.example.health_messenger_ui

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persists auth snapshot and pending delivered-ACK jobs for native FCM handling.
 */
internal object PushNativeStore {
    private const val PREFS = "health_messenger_ui_push"
    private const val KEY_API_BASE = "api_base_url"
    private const val KEY_CHAT_API_PATH = "chat_api_path"
    private const val KEY_DELIVERED_PATH = "delivered_path_template"
    private const val KEY_HEADERS_JSON = "headers_json"
    private const val KEY_TYPE_KEY = "chat_type_data_key"
    private const val KEY_TYPE_VALUE = "chat_type_value"
    private const val KEY_QUEUE = "pending_delivered_ack_queue"

    fun syncPushConfig(context: Context, args: Map<*, *>) {
        val p = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        p.putString(KEY_API_BASE, args["apiBaseUrl"]?.toString() ?: "")
        p.putString(KEY_CHAT_API_PATH, args["chatApiPath"]?.toString() ?: "")
        p.putString(KEY_DELIVERED_PATH, args["deliveredPathTemplate"]?.toString() ?: "")
        p.putString(KEY_HEADERS_JSON, args["headersJson"]?.toString() ?: "{}")
        p.putString(KEY_TYPE_KEY, args["chatTypeDataKey"]?.toString() ?: "type")
        p.putString(KEY_TYPE_VALUE, args["chatTypeValue"]?.toString() ?: "CHAT_MESSAGE")
        p.apply()
    }

    fun readConfig(context: Context): PushConfigSnapshot? {
        val p = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val base = p.getString(KEY_API_BASE, "") ?: ""
        if (base.isBlank()) return null
        return PushConfigSnapshot(
            apiBaseUrl = base.trimEnd('/'),
            chatApiPath = (p.getString(KEY_CHAT_API_PATH, "/api/v1/chat") ?: "/api/v1/chat").trim(),
            deliveredPathTemplate =
                p.getString(
                    KEY_DELIVERED_PATH,
                    "/conversations/{conversationId}/messages/{messageId}/delivered",
                )
                    ?: "",
            headersJson = p.getString(KEY_HEADERS_JSON, "{}") ?: "{}",
            chatTypeDataKey = p.getString(KEY_TYPE_KEY, "type") ?: "type",
            chatTypeValue = p.getString(KEY_TYPE_VALUE, "CHAT_MESSAGE") ?: "CHAT_MESSAGE",
        )
    }

    fun enqueueAck(context: Context, conversationId: String, messageId: String) {
        val p = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = p.getString(KEY_QUEUE, "[]") ?: "[]"
        val arr = try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
        val obj = JSONObject()
        obj.put("conversationId", conversationId)
        obj.put("messageId", messageId)
        arr.put(obj)
        val capped = JSONArray()
        val start = maxOf(0, arr.length() - 50)
        for (i in start until arr.length()) {
            capped.put(arr.get(i))
        }
        p.edit().putString(KEY_QUEUE, capped.toString()).apply()
    }

    fun dequeueAll(context: Context): List<Pair<String, String>> {
        val p = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = p.getString(KEY_QUEUE, "[]") ?: "[]"
        p.edit().putString(KEY_QUEUE, "[]").apply()
        val out = mutableListOf<Pair<String, String>>()
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val c = o.optString("conversationId", "")
                val m = o.optString("messageId", "")
                if (c.isNotBlank() && m.isNotBlank()) {
                    out.add(c to m)
                }
            }
        } catch (_: Exception) {
        }
        return out
    }
}

internal data class PushConfigSnapshot(
    val apiBaseUrl: String,
    val chatApiPath: String,
    val deliveredPathTemplate: String,
    val headersJson: String,
    val chatTypeDataKey: String,
    val chatTypeValue: String,
) {
    fun buildDeliveredUrl(conversationId: String, messageId: String): String {
        var path = deliveredPathTemplate
            .replace("{conversationId}", conversationId)
            .replace("{messageId}", messageId)
        if (!path.startsWith("/")) {
            path = "/$path"
        }
        var prefix = chatApiPath.trim()
        if (!prefix.startsWith("/")) {
            prefix = "/$prefix"
        }
        prefix = prefix.trimEnd('/')
        return "$apiBaseUrl$prefix$path"
    }

    fun headersMap(): Map<String, String> {
        val out = mutableMapOf<String, String>()
        try {
            val o = JSONObject(headersJson)
            val keys = o.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                out[k] = o.optString(k, "")
            }
        } catch (_: Exception) {
        }
        out.putIfAbsent("Content-Type", "application/json")
        return out
    }
}
