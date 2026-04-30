# health_messenger_ui_example

Demonstrates the chat UI package and **message FCM / push bridge** wired in the example app.

## Firebase setup

1. Add **`android/app/google-services.json`** (Android) and **`GoogleService-Info.plist`** to the Xcode Runner target (iOS).
2. The Android Gradle **Google Services** plugin applies only when `google-services.json` is present (see `android/app/build.gradle.kts`).
3. **iOS**: enable **Push Notifications** and **Background Modes → Remote notifications** in Xcode. `Runner/AppDelegate` forwards background payloads to `HealthMessengerUiPlugin`.

## What the example does

- **`main.dart`** calls `WidgetsFlutterBinding.ensureInitialized()` and tries `Firebase.initializeApp()` so Firebase is ready before the first frame when config files exist.
- After a successful chat **bootstrap**, `ExampleChatPage` runs **`_setupPushAfterBootstrap`**:
  - Requests notification permission (`FirebaseMessaging.instance.requestPermission`).
  - **`HealthMessengerPush`**: native `syncPushConfig` (REST delivered ACK snapshot) + `EventChannel` listener.
  - **`MessengerPushFirebaseBinding`**: foreground `onMessage` → `markAsDeliveredPrefer` (REST then socket).
  - Logs FCM token preview and native push events; refreshes the affected conversation’s messages when a chat push arrives.
- The header line shows **`Push: on`** when the bridge initialized, **`Push: off`** otherwise (e.g. missing Firebase files).

## FCM `data` payload (chat only)

Use a string `type` field (default: `type` = `CHAT_MESSAGE`) plus:

- `messageId` (or `message_id`)
- `conversationId` (or `conversation_id`)

Optional: `tenantId`, `senderId`. Native code ignores non-matching `type` values.

## REST receipt paths

Defaults match `ChatServiceConfig.deliveredReceiptRestPath` / `readReceiptRestPath`. Change them when constructing `ChatServiceConfig` in `_bootstrapPackageFlow` if your API differs.
