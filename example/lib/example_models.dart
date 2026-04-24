class ExampleBootstrapFormData {
  const ExampleBootstrapFormData({
    required this.apiBaseUrl,
    required this.socketUrl,
    required this.apiKey,
    required this.providerId,
    required this.providerUserId,
    required this.email,
    required this.name,
  });

  const ExampleBootstrapFormData.initial()
      : apiBaseUrl = 'http://172.16.40.240:4040',
        socketUrl = 'http://172.16.40.240:4040',
        apiKey =
            'vfk_ak_fa7N1aeMBHogEwHg3K4JfA:EMwAFdBm0UDE3yZ9sg-AXdqV7gCe47Tnc4vvz8EWPsE',
        providerId = 'flutter-example',
        providerUserId = 'flutter-user-1',
        email = 'flutter@example.com',
        name = 'Flutter Example User';

  final String apiBaseUrl;
  final String socketUrl;
  final String apiKey;
  final String providerId;
  final String providerUserId;
  final String email;
  final String name;

  ExampleBootstrapFormData copyWith({
    String? apiBaseUrl,
    String? socketUrl,
    String? apiKey,
    String? providerId,
    String? providerUserId,
    String? email,
    String? name,
  }) {
    return ExampleBootstrapFormData(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      socketUrl: socketUrl ?? this.socketUrl,
      apiKey: apiKey ?? this.apiKey,
      providerId: providerId ?? this.providerId,
      providerUserId: providerUserId ?? this.providerUserId,
      email: email ?? this.email,
      name: name ?? this.name,
    );
  }
}
