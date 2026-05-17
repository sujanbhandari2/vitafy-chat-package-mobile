import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'example_configuration_page.dart';
import 'example_chat_session_holder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    if (kDebugMode) {
      debugPrint('Firebase initialized for example app.');
    }
  } catch (e, st) {
    // Missing or invalid google-services.json / GoogleService-Info.plist is OK
    // for local runs; push setup in ExampleChatPage will no-op until configured.
    if (kDebugMode) {
      debugPrint('Firebase.initializeApp skipped: $e');
      debugPrintStack(stackTrace: st);
    }
  }
  runApp(const MessengerExampleApp());
}

class MessengerExampleApp extends StatelessWidget {
  const MessengerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ExampleChatSessionHolder(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Health Messenger UI Example',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2B6E62),
          ),
          useMaterial3: true,
        ),
        home: const ExampleConfigurationPage(),
      ),
    );
  }
}
