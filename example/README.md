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

## Troubleshooting

### `Failed to decode advisories` / `advisoriesUpdated must be a String`

pub.dev can return `"advisoriesUpdated": null` for packages with no advisories; some Dart SDKs still log a `FormatException` while resolving. **Dependencies still resolve** (“Got dependencies!”). Options:

- Run **`flutter upgrade`** when a newer stable SDK ships a matching `pub` fix.
- After the first successful download, use **`flutter pub get --offline`** to resolve from the local pub cache without re-fetching advisories (no advisory decode step).

### Android: `compileFlutterBuildDebug` / “problem occurred starting process … flutter”

From this repo’s `example` folder, **`flutter build apk --debug`** and **`./gradlew :app:compileFlutterBuildDebug`** should work if `android/local.properties` has a valid `flutter.sdk` and `sdk.dir` (Flutter tooling generates these; paths must exist on your machine).

If Android Studio fails but the terminal works: **File → Settings → Build, Execution, Deployment → Build Tools → Gradle** and ensure the IDE uses a JDK that can run your Flutter install; or run **`cd android && ./gradlew --stop`** and rebuild. Project path segments with spaces are supported by current Gradle/Flutter, but a stale Gradle daemon or IDE JDK mismatch often causes one-off exec failures.
