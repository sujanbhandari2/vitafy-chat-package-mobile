package com.example.health_messenger_ui

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class HealthMessengerUiPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var applicationContext: Context? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext

        val messenger = binding.binaryMessenger
        val ch = MethodChannel(messenger, CHANNEL)
        ch.setMethodCallHandler(this)
        methodChannel = ch

        val ev = EventChannel(messenger, EVENT_CHANNEL)
        ev.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    synchronized(staticLock) {
                        staticSink = events
                    }
                }

                override fun onCancel(arguments: Any?) {
                    synchronized(staticLock) {
                        staticSink = null
                    }
                }
            },
        )
        eventChannel = ev
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        applicationContext = null
        synchronized(staticLock) {
            staticSink = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = applicationContext
        if (ctx == null) {
            result.error("no_context", "Plugin not attached", null)
            return
        }
        when (call.method) {
            "syncPushConfig" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                PushNativeStore.syncPushConfig(ctx, args)
                result.success(null)
            }
            "drainAckQueue" -> {
                Thread {
                    val config = PushNativeStore.readConfig(ctx)
                    if (config == null) {
                        Handler(Looper.getMainLooper()).post { result.success(0) }
                        return@Thread
                    }
                    var done = 0
                    val pending = PushNativeStore.dequeueAll(ctx)
                    for ((conversationId, messageId) in pending) {
                        if (NativeDeliveredAck.postDelivered(config, conversationId, messageId)) {
                            done++
                        } else {
                            PushNativeStore.enqueueAck(ctx, conversationId, messageId)
                            break
                        }
                    }
                    Handler(Looper.getMainLooper()).post { result.success(done) }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val CHANNEL = "health_messenger_ui/push"
        private const val EVENT_CHANNEL = "health_messenger_ui/push_events"

        private val staticLock = Any()
        private var staticSink: EventChannel.EventSink? = null

        fun emitIncomingPush(payload: Map<String, Any>) {
            val sink = synchronized(staticLock) { staticSink } ?: return
            Handler(Looper.getMainLooper()).post {
                sink.success(payload)
            }
        }
    }
}
