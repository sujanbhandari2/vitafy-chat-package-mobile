import Foundation

enum NativeDeliveredAck {
  static func postDelivered(config: PushConfigSnapshot, conversationId: String, messageId: String) -> Bool {
    let urlString = config.buildDeliveredUrl(conversationId: conversationId, messageId: messageId)
    guard let url = URL(string: urlString) else {
      return false
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = "{}".data(using: .utf8)
    for (k, v) in config.headersMap() {
      request.setValue(v, forHTTPHeaderField: k)
    }
    let semaphore = DispatchSemaphore(value: 0)
    var success = false
    let task = URLSession.shared.dataTask(with: request) { _, response, _ in
      if let http = response as? HTTPURLResponse {
        success = (200...299).contains(http.statusCode)
      }
      semaphore.signal()
    }
    task.resume()
    _ = semaphore.wait(timeout: .now() + 20)
    return success
  }
}
