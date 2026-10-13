class ExampleBootstrapFormData {
  const ExampleBootstrapFormData({
    required this.apiBaseUrl,
    required this.socketUrl,
    required this.apiKey,
    required this.externalTenantId,
    required this.externalUserId,
    required this.externalUserRole,
    required this.email,
    required this.name,
    this.profile,
  });

  const ExampleBootstrapFormData.initial()
      : apiBaseUrl = 'https://api-generic-chat.vitafyhealth.com',
        socketUrl = 'https://api-generic-chat.vitafyhealth.com',
        apiKey =
            'vfk_ak_U2FMapguEUmJMK9B7mUMlA:ohxHIA84Wi4pjuHZNP6HSm45fY3Q7y3nKXtDABedXK0',
        externalTenantId = '7EB541E4-91A9-4DEB-BB7E-55813D3CA140',
        externalUserId = 'surya bhai legend',
        externalUserRole = 'user',
        email = 'Sujan@example.com',
        name = 'Sujan Flutter',
        profile = null;

  final String apiBaseUrl;
  final String socketUrl;
  final String apiKey;
  final String externalTenantId;
  final String externalUserId;
  final String externalUserRole;
  final String email;
  final String name;
  final String? profile;

  ExampleBootstrapFormData copyWith({
    String? apiBaseUrl,
    String? socketUrl,
    String? apiKey,
    String? externalTenantId,
    String? externalUserId,
    String? externalUserRole,
    String? email,
    String? name,
    String? profile,
  }) {
    return ExampleBootstrapFormData(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      socketUrl: socketUrl ?? this.socketUrl,
      apiKey: apiKey ?? this.apiKey,
      externalTenantId: externalTenantId ?? this.externalTenantId,
      externalUserId: externalUserId ?? this.externalUserId,
      externalUserRole: externalUserRole ?? this.externalUserRole,
      email: email ?? this.email,
      name: name ?? this.name,
      profile: profile ?? this.profile,
    );
  }
}
