# Health Messenger UI

Reusable chat UI widgets plus a backend client toolkit for Socket.IO + REST chat services.

**What this package provides**
- UI toolkit: chat shells, lists, bubbles, composer, and theme helpers.
- Client toolkit: REST + Socket.IO integration, models, and repository API.

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
    apiBaseUrl: 'https://your-backend.example.com/api',
    socketUrl: 'https://your-backend.example.com',
  ),
);

await client.connect('<auth-token>');
client.events.listen((event) {
  // Handle ChatSocketEvent
});

final conversations = await client.getConversations('<auth-token>');
```

**UI Toolkit**
```dart
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

// Use the widgets in your UI tree. See the /example app for a full integration.
```

## Notes
- The client SDK is backend-agnostic as long as your REST and Socket.IO API match the expected endpoints/events.
- For a full working example, open the `example` app in this package.
