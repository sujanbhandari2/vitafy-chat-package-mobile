/// How [MessengerChatThread] shows loading while fetching messages when the
/// thread already has messages to display.
enum MessengerThreadFetchLoadingMode {
  /// Replaces the message list with [MessengerChatThread.threadFetchLoadingBuilder]
  /// or a default centered spinner.
  replaceMessageList,

  /// Keeps existing messages visible with no in-thread fetch indicator.
  keepMessagesVisible,
}
