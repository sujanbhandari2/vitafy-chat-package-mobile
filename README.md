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

const auth = ChatAuth(
  apiKey: '<accessKey>:<secretKey>',
  chatUserId: '<chatUserId>',
);

final me = await client.registerOrGetUser(
  auth,
  providerId: 'mobile-app',
  providerUserId: 'user-123',
  email: 'user@example.com',
  name: 'Jane Doe',
);

await client.connect(auth);
final conversations = await client.getConversations(auth, forUserId: me.id);
final messagesPage = await client.getMessages(auth, conversations.first.id);

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

## Notes
- Default REST routes target `/api/v1/chat` and uploads target `/api/upload/file`.
- Socket auth sends both `auth.apiKey` and `X-Api-Key`, plus `auth.userId/chatUserId` when provided.
- `apiLogger` and `socketLogger` are optional named parameters intended for development-time transport debugging.
- For a full working example, open the `example` app in this package.
