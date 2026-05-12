import '../chat_exceptions.dart';
import 'conversation.dart';

/// Matches `CHAT_USER_DEFAULT_EXTERNAL_ROLE` in vitafy-generic-chat-frontend.
const String kChatUserDefaultExternalRole = 'user';

/// One entry in `POST …/chat/users` or `users[]` for `POST …/users/start-conversation`.
class ChatUserRegistrationBody {
  const ChatUserRegistrationBody({
    required this.externalTenantId,
    required this.externalUserId,
    required this.externalUserRole,
    this.email,
    this.name,
    this.profile,
  });

  final String externalTenantId;
  final String externalUserId;
  final String externalUserRole;
  final String? email;
  final String? name;
  final String? profile;

  /// Normalizes ids and role (empty role → [kChatUserDefaultExternalRole]).
  ///
  /// Provide either `externalTenantId` / `externalUserId` or deprecated
  /// `providerId` / `providerUserId`.
  factory ChatUserRegistrationBody.resolve({
    String? externalTenantId,
    String? externalUserId,
    String? providerId,
    String? providerUserId,
    String? externalUserRole,
    String? email,
    String? name,
    String? profile,
  }) {
    final extT = _firstNonEmpty(externalTenantId) ?? _firstNonEmpty(providerId);
    final extU = _firstNonEmpty(externalUserId) ?? _firstNonEmpty(providerUserId);
    if (extT == null || extU == null) {
      throw ArgumentError(
        'externalTenantId (or deprecated providerId) and externalUserId '
        '(or deprecated providerUserId) must be non-empty.',
      );
    }
    var role = _firstNonEmpty(externalUserRole);
    role ??= kChatUserDefaultExternalRole;
    return ChatUserRegistrationBody(
      externalTenantId: extT,
      externalUserId: extU,
      externalUserRole: role,
      email: _firstNonEmpty(email),
      name: _firstNonEmpty(name),
      profile: _firstNonEmpty(profile),
    );
  }

  Map<String, dynamic> toRegistrationJson() {
    return <String, dynamic>{
      'externalTenantId': externalTenantId,
      'externalUserId': externalUserId,
      'externalUserRole': externalUserRole,
      if (email != null && email!.isNotEmpty) 'email': email!,
      if (name != null && name!.isNotEmpty) 'name': name!,
      if (profile != null && profile!.isNotEmpty) 'profile': profile!,
    };
  }
}

String? _firstNonEmpty(String? value) {
  final t = value?.trim() ?? '';
  return t.isEmpty ? null : t;
}

/// Unwraps Vitafy `POST …/users/start-conversation` (`conversation` or nested `data`).
Conversation parseStartConversationResponse(Object? raw) {
  final root = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  Map<String, dynamic> layer = root;
  final nested = root['data'];
  if (nested is Map) {
    layer = Map<String, dynamic>.from(nested);
  }
  final conv = layer['conversation'];
  if (conv is! Map) {
    throw const ChatUnexpectedResponseException(
      message: 'Invalid start-conversation response: missing conversation.',
    );
  }
  return Conversation.fromJson(Map<String, dynamic>.from(conv));
}
