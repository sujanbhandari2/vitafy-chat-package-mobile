import Flutter

final class PushEventStreamHandler: NSObject, FlutterStreamHandler {
  static var sharedSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    PushEventStreamHandler.sharedSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    PushEventStreamHandler.sharedSink = nil
    return nil
  }

  static func emit(_ payload: [String: Any]) {
    DispatchQueue.main.async {
      sharedSink?(payload)
    }
  }
}
