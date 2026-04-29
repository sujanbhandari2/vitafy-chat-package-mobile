import Foundation

private extension String {
  func trimmingTrailingSlashes() -> String {
    var s = self
    while s.hasSuffix("/") { s.removeLast() }
    return s
  }
}

struct PushConfigSnapshot {
  let apiBaseUrl: String
  let chatApiPath: String
  let deliveredPathTemplate: String
  let headersJson: String
  let chatTypeDataKey: String
  let chatTypeValue: String

  func buildDeliveredUrl(conversationId: String, messageId: String) -> String {
    var path = deliveredPathTemplate
      .replacingOccurrences(of: "{conversationId}", with: conversationId)
      .replacingOccurrences(of: "{messageId}", with: messageId)
    if !path.hasPrefix("/") {
      path = "/" + path
    }
    var prefix = chatApiPath.trimmingCharacters(in: .whitespacesAndNewlines)
    if !prefix.hasPrefix("/") {
      prefix = "/" + prefix
    }
    prefix = prefix.trimmingTrailingSlashes()
    let base = apiBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingTrailingSlashes()
    return "\(base)\(prefix)\(path)"
  }

  func headersMap() -> [String: String] {
    var out: [String: String] = [:]
    guard let data = headersJson.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return ["Content-Type": "application/json"]
    }
    for (k, v) in obj {
      out[String(describing: k)] = String(describing: v)
    }
    if out["Content-Type"] == nil {
      out["Content-Type"] = "application/json"
    }
    return out
  }
}

enum PushNativeStore {
  private static let prefix = "hmu_push_"

  private static var defaults: UserDefaults { .standard }

  static func syncPushConfig(_ args: [String: Any]) {
    let d = defaults
    d.set(args["apiBaseUrl"] as? String ?? "", forKey: prefix + "api_base_url")
    d.set(args["chatApiPath"] as? String ?? "/api/v1/chat", forKey: prefix + "chat_api_path")
    d.set(
      args["deliveredPathTemplate"] as? String ?? "/conversations/{conversationId}/messages/{messageId}/delivered",
      forKey: prefix + "delivered_path_template")
    d.set(args["headersJson"] as? String ?? "{}", forKey: prefix + "headers_json")
    d.set(args["chatTypeDataKey"] as? String ?? "type", forKey: prefix + "chat_type_data_key")
    d.set(args["chatTypeValue"] as? String ?? "CHAT_MESSAGE", forKey: prefix + "chat_type_value")
  }

  static func readConfig() -> PushConfigSnapshot? {
    let d = defaults
    let base = (d.string(forKey: prefix + "api_base_url") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if base.isEmpty { return nil }
    return PushConfigSnapshot(
      apiBaseUrl: base,
      chatApiPath: d.string(forKey: prefix + "chat_api_path") ?? "/api/v1/chat",
      deliveredPathTemplate: d.string(forKey: prefix + "delivered_path_template")
        ?? "/conversations/{conversationId}/messages/{messageId}/delivered",
      headersJson: d.string(forKey: prefix + "headers_json") ?? "{}",
      chatTypeDataKey: d.string(forKey: prefix + "chat_type_data_key") ?? "type",
      chatTypeValue: d.string(forKey: prefix + "chat_type_value") ?? "CHAT_MESSAGE"
    )
  }

  static func enqueueAck(conversationId: String, messageId: String) {
    let d = defaults
    let key = prefix + "pending_delivered_ack_queue"
    let raw = d.string(forKey: key) ?? "[]"
    var arr: [[String: Any]] = []
    if let data = raw.data(using: .utf8),
       let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
      arr = parsed
    }
    arr.append(["conversationId": conversationId, "messageId": messageId])
    if arr.count > 50 {
      arr = Array(arr.suffix(50))
    }
    if let data = try? JSONSerialization.data(withJSONObject: arr),
       let s = String(data: data, encoding: .utf8) {
      d.set(s, forKey: key)
    }
  }

  static func dequeueAll() -> [(String, String)] {
    let d = defaults
    let key = prefix + "pending_delivered_ack_queue"
    let raw = d.string(forKey: key) ?? "[]"
    d.set("[]", forKey: key)
    guard let data = raw.data(using: .utf8),
          let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return []
    }
    return parsed.compactMap { row in
      let cc = (row["conversationId"] as? String) ?? String(describing: row["conversationId"] ?? "")
      let mm = (row["messageId"] as? String) ?? String(describing: row["messageId"] ?? "")
      guard !cc.isEmpty, !mm.isEmpty else { return nil }
      return (cc, mm)
    }
  }
}
