import 'package:flutter/material.dart';

import 'example_configuration_page.dart';

void main() {
  runApp(const MessengerExampleApp());
}

class MessengerExampleApp extends StatelessWidget {
  const MessengerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Messenger UI Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B6E62)),
        useMaterial3: true,
      ),
      home: const ExampleConfigurationPage(),
    );
  }
}
