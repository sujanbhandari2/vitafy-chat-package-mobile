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

    return ConversationParticipant(
      id: json['id']?.toString() ?? '',
      userId:
          json['userId']?.toString() ?? json['chatUserId']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      user: ConversationParticipantUser.fromJson(
        Map<String, dynamic>.from(
          rawUser as Map? ?? const <String, dynamic>{},
        ),
      ),
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
    return ConversationParticipantUser(
      id: json['id']?.toString() ?? '',
      username: json['name']?.toString() ?? json['username']?.toString() ?? '',
      role: rawRole == null ? AppRole.client : parseRole(rawRole),
      email: json['email']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      status: json['status']?.toString(),
      isOnline:
          json['isOnline'] as bool? ?? json['is_online'] as bool? ?? false,
    );
  }
}
