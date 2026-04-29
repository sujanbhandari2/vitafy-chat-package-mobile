import Flutter
import UIKit

@objcMembers
public class HealthMessengerUiPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let method = FlutterMethodChannel(name: "health_messenger_ui/push", binaryMessenger: messenger)
    let instance = HealthMessengerUiPlugin()
    method.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
    let events = FlutterEventChannel(name: "health_messenger_ui/push_events", binaryMessenger: messenger)
    events.setStreamHandler(PushEventStreamHandler())
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "syncPushConfig":
      if let args = call.arguments as? [String: Any] {
        PushNativeStore.syncPushConfig(args)
      }
      result(nil)
    case "drainAckQueue":
      DispatchQueue.global(qos: .utility).async {
        guard let config = PushNativeStore.readConfig() else {
          DispatchQueue.main.async { result(0) }
          return
        }
        var done = 0
        let pending = PushNativeStore.dequeueAll()
        for item in pending {
          if NativeDeliveredAck.postDelivered(config: config, conversationId: item.0, messageId: item.1) {
            done += 1
          } else {
            PushNativeStore.enqueueAck(conversationId: item.0, messageId: item.1)
            break
          }
        }
        DispatchQueue.main.async { result(done) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Call from `AppDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`.
  /// Returns `true` when the payload was recognized as a chat message push.
  @objc public static func handleRemoteNotification(
    userInfo: [AnyHashable: Any],
    completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) -> Bool {
    let flat = flattenUserInfo(userInfo)
    guard let config = PushNativeStore.readConfig() else {
      return false
    }
    let typeKey = config.chatTypeDataKey
    let incoming = flat[typeKey] ?? ""
    if incoming != config.chatTypeValue {
      return false
    }
    guard let conversationId = flat["conversationId"] ?? flat["conversation_id"],
          let messageId = flat["messageId"] ?? flat["message_id"],
          !conversationId.isEmpty, !messageId.isEmpty else {
      completionHandler(.failed)
      return true
    }
    let ok = NativeDeliveredAck.postDelivered(config: config, conversationId: conversationId, messageId: messageId)
    if !ok {
      PushNativeStore.enqueueAck(conversationId: conversationId, messageId: messageId)
    }
    PushEventStreamHandler.emit([
      "kind": "incoming_chat_message",
      "conversationId": conversationId,
      "messageId": messageId,
      "nativeAckSucceeded": ok,
    ])
    completionHandler(ok ? .newData : .failed)
    return true
  }

  private static func flattenUserInfo(_ userInfo: [AnyHashable: Any]) -> [String: String] {
    var out: [String: String] = [:]
    for (key, value) in userInfo {
      let k = String(describing: key)
      if let s = value as? String {
        out[k] = s
      } else if let nested = value as? [String: Any] {
        for (k2, v2) in nested {
          out[k2] = String(describing: v2)
        }
      } else {
        out[k] = String(describing: value)
      }
    }
    return out
  }
}
