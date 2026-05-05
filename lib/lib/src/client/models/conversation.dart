import 'app_role.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.tenantId,
    required this.type,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.participants,
  });

  final String id;
  final String tenantId;
  final String type;
  final String? title;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConversationParticipant> participants;

  bool get isGlobal => type.toUpperCase() == 'SUPPORT';

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawParticipants =
        json['participants'] as List<dynamic>? ?? <dynamic>[];

    return Conversation(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'DIRECT',
      title: json['title']?.toString(),
      createdBy: json['createdBy']?.toString(),
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt']?.toString() ??
            json['createdAt']?.toString() ??
            DateTime.now().toIso8601String(),
      ),
      participants: rawParticipants
          .map(
            (item) => ConversationParticipant.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class ConversationParticipant {
  const ConversationParticipant({
    required this.id,
    required this.userId,
    required this.conversationId,
    required this.user,
  });

  final String id;
  final String userId;
  final String conversationId;
  final ConversationParticipantUser user;

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) {
    final rawUser = json['chatUser'] ?? json['user'];
    final userMap = Map<String, dynamic>.from(
      rawUser as Map? ?? const <String, dynamic>{},
    );
    // Many APIs omit `id` on nested `chatUser` but send `chatUserId` on the
    // participant row — needed for stable user ids (e.g. UI peer deduplication).
    final participantChatUserId =
        json['chatUserId']?.toString().trim() ??
            json['userId']?.toString().trim() ??
            '';
    final nestedId = userMap['id']?.toString().trim() ?? '';
    if (nestedId.isEmpty && participantChatUserId.isNotEmpty) {
      userMap['id'] = participantChatUserId;
    }

    return ConversationParticipant(
      id: json['id']?.toString() ?? '',
      userId:
          json['userId']?.toString() ?? json['chatUserId']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      user: ConversationParticipantUser.fromJson(userMap),
    );
  }
}

class ConversationParticipantUser {
  const ConversationParticipantUser({
    required this.id,
    required this.username,
    required this.role,
    this.email,
    this.avatarUrl,
    this.status,
    this.isOnline = false,
  });

  final String id;
  final String username;
  final AppRole role;
  final String? email;
  final String? avatarUrl;
  final String? status;
  final bool isOnline;

  factory ConversationParticipantUser.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role']?.toString();
    final idStr = _firstNonEmpty(json, const ['id', 'chatUserId', 'chat_user_id'])
            ?.trim() ??
        '';
    final label = _participantLabelFromJson(json, idStr);
    return ConversationParticipantUser(
      id: idStr,
      username: label,
      role: rawRole == null ? AppRole.client : parseRole(rawRole),
      email: _firstNonEmpty(json, const ['email']),
      avatarUrl: _firstNonEmpty(
        json,
        const ['avatarUrl', 'avatar_url'],
      ),
      status: _firstNonEmpty(json, const ['status']),
      isOnline:
          json['isOnline'] as bool? ?? json['is_online'] as bool? ?? false,
    );
  }
}

String _participantLabelFromJson(Map<String, dynamic> json, String idStr) {
  final fromFields = _firstNonEmpty(json, const [
    'name',
    'username',
    'displayName',
    'display_name',
    'email',
    'providerUserId',
    'provider_user_id',
  ]);
  if (fromFields != null) {
    return fromFields;
  }
  if (idStr.trim().isNotEmpty) {
    return 'User $idStr';
  }
  return 'User';
}

String? _firstNonEmpty(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) {
      continue;
    }
    final s = raw.toString().trim();
    if (s.isNotEmpty) {
      return s;
    }
  }
  return null;
}
