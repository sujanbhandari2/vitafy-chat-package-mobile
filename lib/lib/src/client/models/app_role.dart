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

/// Maps Vitafy / host `externalUserRole` values into the package [AppRole] enum.
///
/// Unknown values used to fall through to [AppRole.client], which incorrectly
/// labeled roles like `PLATFORM_ADMIN` as CLIENT in the UI.
AppRole parseRole(String value) {
  final normalized = value.trim().toUpperCase();
  if (normalized.isEmpty || _isConversationMembershipRole(normalized)) {
    return AppRole.client;
  }

  switch (normalized) {
    case 'CLIENT':
    case 'USER':
    case 'PLATFORM_USER':
      return AppRole.client;
    case 'AGENT':
    case 'ADVOCATE':
    case 'VCARE_ADVOCATE':
    case 'CARE_ADVOCATE':
      return AppRole.agent;
    case 'ADMIN':
    case 'PLATFORM_ADMIN':
    case 'TENANT_ADMIN':
    case 'SUPER_ADMIN':
    case 'VCARE_ADMIN':
      return AppRole.admin;
  }

  if (normalized.contains('ADMIN')) {
    return AppRole.admin;
  }
  if (normalized.contains('ADVOCATE') || normalized.contains('AGENT')) {
    return AppRole.agent;
  }
  if (normalized.contains('CLIENT') || normalized.contains('USER')) {
    return AppRole.client;
  }
  return AppRole.client;
}

bool _isConversationMembershipRole(String normalized) {
  switch (normalized) {
    case 'MEMBER':
    case 'OWNER':
    case 'MODERATOR':
    case 'PARTICIPANT':
      return true;
    default:
      return false;
  }
}

/// True when [value] is a conversation membership label, not a tenant user role.
bool parseRoleIgnoresMembershipLabel(String value) {
  return _isConversationMembershipRole(value.trim().toUpperCase());
}
