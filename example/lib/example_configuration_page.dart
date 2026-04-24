import 'package:flutter/material.dart';

import 'example_chat_page.dart';
import 'example_models.dart';

class ExampleConfigurationPage extends StatefulWidget {
  const ExampleConfigurationPage({super.key});

  @override
  State<ExampleConfigurationPage> createState() =>
      _ExampleConfigurationPageState();
}

class _ExampleConfigurationPageState extends State<ExampleConfigurationPage> {
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _socketUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _providerIdController;
  late final TextEditingController _providerUserIdController;
  late final TextEditingController _emailController;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final initialData = const ExampleBootstrapFormData.initial();
    _apiBaseUrlController = TextEditingController(text: initialData.apiBaseUrl);
    _socketUrlController = TextEditingController(text: initialData.socketUrl);
    _apiKeyController = TextEditingController(text: initialData.apiKey);
    _providerIdController = TextEditingController(text: initialData.providerId);
    _providerUserIdController = TextEditingController(
      text: initialData.providerUserId,
    );
    _emailController = TextEditingController(text: initialData.email);
    _nameController = TextEditingController(text: initialData.name);
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _socketUrlController.dispose();
    _apiKeyController.dispose();
    _providerIdController.dispose();
    _providerUserIdController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _openChat() async {
    FocusScope.of(context).unfocus();
    final data = ExampleBootstrapFormData(
      apiBaseUrl: _apiBaseUrlController.text.trim(),
      socketUrl: _socketUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      providerId: _providerIdController.text.trim(),
      providerUserId: _providerUserIdController.text.trim(),
      email: _emailController.text.trim(),
      name: _nameController.text.trim(),
    );

    if (data.apiBaseUrl.isEmpty ||
        data.socketUrl.isEmpty ||
        data.apiKey.isEmpty ||
        data.providerId.isEmpty ||
        data.providerUserId.isEmpty ||
        data.email.isEmpty) {
      _showSnack('Please fill all required configuration fields.');
      return;
    }

    final didLogout = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ExampleChatPage(initialData: data),
      ),
    );

    if (didLogout == true && mounted) {
      _showSnack('Logged out and disconnected successfully.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Configuration'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure your chat session',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set API and user values here. Socket URL must be the API origin (example: http://host:4040, no /api path). On logout, chat disconnects and returns here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF475569),
                        ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _fieldTile(
                        label: 'API Base URL',
                        controller: _apiBaseUrlController,
                        width: 280,
                      ),
                      _fieldTile(
                        label: 'Socket URL',
                        controller: _socketUrlController,
                        width: 280,
                      ),
                      _fieldTile(
                        label: 'X-Api-Key',
                        controller: _apiKeyController,
                        width: 360,
                      ),
                      _fieldTile(
                        label: 'Provider ID',
                        controller: _providerIdController,
                        width: 220,
                      ),
                      _fieldTile(
                        label: 'Provider User ID',
                        controller: _providerUserIdController,
                        width: 220,
                      ),
                      _fieldTile(
                        label: 'Email',
                        controller: _emailController,
                        width: 260,
                      ),
                      _fieldTile(
                        label: 'Display Name',
                        controller: _nameController,
                        width: 260,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Open Chat'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldTile({
    required String label,
    required TextEditingController controller,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
