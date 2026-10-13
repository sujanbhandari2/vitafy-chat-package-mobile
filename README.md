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
  externalTenantId: 'mobile-app',
  externalUserId: 'user-123',
  externalUserRole: 'user',
  email: 'user@example.com',
  name: 'Jane Doe',
);

// After you have a chat-user JWT in [sessionAuth], batch-create users + open a
// DIRECT (two users, no groupName) or GROUP conversation:
// await client.startConversation(sessionAuth, users: [ ... ], groupName: 'Team');

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

MessengerChatShell(
  // ...required args
  packageDialogTheme: Theme.of(context).copyWith(
    dialogTheme: const DialogThemeData(
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      contentTextStyle: TextStyle(fontSize: 14, height: 1.4),
    ),
  ),
);
```

`packageDialogTheme` applies to package-owned dialogs (delete confirmations, image preview). Pass a full `ThemeData` from `Theme.of(context).copyWith(dialogTheme: …)` so field-wise overrides stay complete.

**Creating a group with one selected peer**

- Prefer `onCreateGroupRequested` (not `onCreateGroupSelected` alone) so you receive a [MessengerGroupCreateRequest] with a resolved name.
- For `POST …/users/start-conversation`, Vitafy treats **two users + empty `groupName` as DIRECT**. Use `request.startConversationGroupName()` or `ChatClient.startGroupConversation(...)` so a non-empty name is always sent.
- For `POST …/conversations`, pass `type: 'GROUP'` explicitly (the example app does this when not using the dummy start-conversation path).

## Parity with the Vitafy web widget

For REST + Socket.IO field-by-field alignment with **`vitafy-generic-chat-frontend`**, use the checklist **`vitafy-genric-chat-backend/docs/WIDGET_CLIENT_PARITY.md`** next to this repo when present. **Verification:** run the web widget and your Flutter app against the same API key; compare DevTools **Network** (`POST .../conversations` body) and the socket handshake **`auth`** object with this package’s `socketLogger` output.

## Notes
- Default REST routes target **`ChatServiceConfig.chatApiPath`** (`/api/v1/chat` by default) and uploads target `/api/upload/file`. If your gateway serves chat user routes under **`/api/v1/users/chat`**, set **`chatApiPath`** to that prefix instead.
- **`POST …/chat/users`** (registration) is **API-key-only** and sends **`externalTenantId`**, **`externalUserId`**, **`externalUserRole`**, and optional **`email`**, **`name`**, **`profile`** (same shape as **`vitafy-generic-chat-frontend`**). Deprecated **`providerId`** / **`providerUserId`** are still accepted and mapped to the external ids.
- **`POST …/chat/users/start-conversation`** uses the same **`X-Api-Key`** plus **chat-user Bearer** JWT as other chat REST (not API-key-only).
- Most other chat REST routes require **`X-Api-Key`** and **`Authorization: Bearer`** using the **`accessToken`** returned by registration; **`GET .../tenant`**, **`POST .../users`**, and **`POST /api/upload/file`** are API-key-only for registration/upload. A full socket session sends the same JWT in **`auth.token` / `auth.accessToken`** (and optionally the `Authorization` header) whenever **`auth.userId`** / **`auth.chatUserId`** is set—prefer **`ChatSession.bootstrap`** so the client wires this automatically.
- Socket handshake **`auth`** sends **`apiKey`**, **`xApiKey`**, literal **`X-Api-Key`**, optional **`userId`/`chatUserId`**, and **`token`/`accessToken`** when you have a chat-user JWT. Handshake HTTP headers include **`X-Api-Key`**, **`Authorization: Bearer …`**, and a duplicate **`auth`** header with the same Bearer value when a JWT is present (for servers that read `handshake.headers.auth`).
- `apiLogger` and `socketLogger` are optional named parameters intended for development-time transport debugging. Log payloads include an **`integration`** label (e.g. `REST GET /api/v1/chat/tenant`, `socket.io_connect`, `socket.emit.join_conversation`) and **redacted** credentials: REST logs sanitize `X-Api-Key`, `Authorization`, and `auth` headers; socket connect logs include **`handshakeAuth`** and **`handshakeHeaders`** maps matching the wire shape with secrets redacted.
- For a full working example, open the `example` app in this package.
