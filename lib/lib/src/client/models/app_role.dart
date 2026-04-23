enum AppRole { client, agent, admin }

extension AppRoleX on AppRole {
  String get apiValue {
    switch (this) {
      case AppRole.client:
        return 'CLIENT';
      case AppRole.agent:
        return 'AGENT';
      case AppRole.admin:
        return 'ADMIN';
    }
  }

  String get label {
    switch (this) {
      case AppRole.client:
        return 'CLIENT';
      case AppRole.agent:
        return 'AGENT';
      case AppRole.admin:
        return 'ADMIN';
    }
  }
}

AppRole parseRole(String value) {
  switch (value.toUpperCase()) {
    case 'CLIENT':
      return AppRole.client;
    case 'AGENT':
      return AppRole.agent;
    case 'ADMIN':
      return AppRole.admin;
    default:
      return AppRole.client;
  }
}
