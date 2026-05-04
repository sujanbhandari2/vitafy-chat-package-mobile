# Health Messenger UI

Reusable chat UI widgets plus a backend-aware Flutter client for REST + Socket.IO chat services.

**What this package provides**
- UI toolkit: chat shells, lists, bubbles, composer, and theme helpers.
- Client toolkit: tenant-scoped API key auth, chat-user registration, uploads, paginated message history, and realtime events.

## Getting started

Add the package and pick the library you need:
- UI widgets: `package:health_messenger_ui/lib/health_messenger_ui.dart`
- Client SDK: `package:health_messenger_ui/lib/health_messenger_client.dart`

## Usage

**Client SDK (recommended for backend integration)**
```dart
import 'package:health_messenger_ui/lib/health_messenger_client.dart';

final client = ChatClient(
  config: ChatServiceConfig(
    apiBaseUrl: 'https://your-backend.example.com',
    socketUrl: 'https://your-backend.example.com',
    apiLogger: (message, {data}) => print('API: $message -> $data'),
    socketLogger: (message, {data}) => print('SOCKET: $message -> $data'),
  ),
);

const apiAuth = ChatAuth(apiKey: '<accessKey>:<secretKey>');

final me = await client.registerOrGetUser(
  apiAuth,
  providerId: 'mobile-app',
  providerUserId: 'user-123',
  email: 'user@example.com',
  name: 'Jane Doe',
);

final sessionAuth = ChatAuth(
  apiKey: apiAuth.apiKey,
  chatUserId: me.id,
  accessToken: me.accessToken!,
);

await client.connect(sessionAuth);
final conversations =
    await client.getConversations(sessionAuth, forUserId: me.id);
final messagesPage =
    await client.getMessages(sessionAuth, conversations.first.id);

await client.joinConversation(conversations.first.id);
await client.sendMessage(
  conversationId: conversations.first.id,
  type: MessageType.text,
  content: 'Hello from Flutter',
);

client.events.listen((event) {
  // Handle ChatSocketEventType.messageReceived, userTyping, userOnline, etc.
});
```

**UI Toolkit**
```dart
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

// Use the widgets in your UI tree. See the /example app for a full integration.
```

## Parity with the Vitafy web widget

For REST + Socket.IO field-by-field alignment with **`vitafy-generic-chat-frontend`**, use the checklist **`vitafy-genric-chat-backend/docs/WIDGET_CLIENT_PARITY.md`** next to this repo when present. **Verification:** run the web widget and your Flutter app against the same API key; compare DevTools **Network** (`POST .../conversations` body) and the socket handshake **`auth`** object with this package’s `socketLogger` output.

## Notes
- Default REST routes target `/api/v1/chat` and uploads target `/api/upload/file`.
- Most chat REST routes require **`X-Api-Key`** and **`Authorization: Bearer`** using the **`accessToken`** returned by **`POST /api/v1/chat/users`**; **`GET .../tenant`**, **`POST .../users`**, and **`POST /api/upload/file`** are API-key-only. A full socket session sends the same JWT in **`auth.token` / `auth.accessToken`** (and optionally the `Authorization` header) whenever **`auth.userId`** / **`auth.chatUserId`** is set—prefer **`ChatSession.bootstrap`** so the client wires this automatically.
- Socket auth sends **`auth.apiKey`** / **`xApiKey`** and **`X-Api-Key`**, plus **`auth.userId`/`chatUserId`** and **`auth.token`/`accessToken`** when you have a chat-user JWT.
- `apiLogger` and `socketLogger` are optional named parameters intended for development-time transport debugging.
- For a full working example, open the `example` app in this package.
