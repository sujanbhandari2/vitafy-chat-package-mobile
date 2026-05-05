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
      : apiBaseUrl = 'https://api-generic-chat.vitafyhealth.com',
        socketUrl = 'https://api-generic-chat.vitafyhealth.com',
        apiKey =
            'vfk_ak_Qkn3JGfrFSSG1KSeTYtAng:4DxmzYIByyd4jrSOwPqZ5zcRgZqZNiC8YxB9rwHcr3k',
        providerId = '7EB541E4-91A9-4DEB-BB7E-55813D3CA140',
        providerUserId = 'surya bhai legend',
        email = 'Sujan@example.com',
        name = 'Sujan Flutter';

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
