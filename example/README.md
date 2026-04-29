# health_messenger_ui_example

Demonstrates the chat UI package and optional **message FCM** wiring.

## Message push (FCM)

1. Add Firebase to the host app: `google-services.json` under `android/app/`, and `GoogleService-Info.plist` in the Xcode Runner target. The Android Gradle plugin is applied **only** when `android/app/google-services.json` exists.
2. Build the example with FCM hooks enabled:

   ```bash
   flutter run --dart-define=ENABLE_FCM_EXAMPLE=true
   ```

3. After login, the example calls `HealthMessengerPush.syncNativePushConfig` so **native** Android/iOS code can POST delivered receipts while the app is backgrounded (using the same REST path template as `ChatServiceConfig.deliveredReceiptRestPath`).
4. **iOS**: `Runner/AppDelegate` forwards `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` to `HealthMessengerUiPlugin.handleRemoteNotification`. Enable **Push Notifications** and **Background Modes → Remote notifications** in Xcode.

### FCM `data` payload (chat only)

Use a string `type` field (default gate: `type` = `CHAT_MESSAGE`) plus:

- `messageId` (or `message_id`)
- `conversationId` (or `conversation_id`)

Optional: `tenantId`, `senderId`.

Native code ignores payloads that do not match the gate so non-chat notifications are not ACK’d as chat messages.

### Dart API

Import `package:health_messenger_ui/lib/health_messenger_push.dart` for:

- `HealthMessengerPush` — MethodChannel sync + `EventChannel` stream
- `parseMessengerPushPayload` / `flattenPushDataMap`
- `MessengerPushFirebaseBinding` — foreground `FirebaseMessaging.onMessage` → `ChatClient.markAsDeliveredPrefer`

REST receipt endpoints default to paths under `chatApiPath`; override with `ChatServiceConfig.deliveredReceiptRestPath` / `readReceiptRestPath` if your backend differs.
