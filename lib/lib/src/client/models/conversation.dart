import 'app_role.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.tenantId,
    required this.isGlobal,
    required this.createdAt,
    required this.participants,
  });

  final String id;
  final String tenantId;
  final bool isGlobal;
  final DateTime createdAt;
  final List<ConversationParticipant> participants;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawParticipants =
        json['participants'] as List<dynamic>? ?? <dynamic>[];

    return Conversation(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      isGlobal: json['isGlobal'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
    required this.user,
  });

  final String id;
  final String userId;
  final ConversationParticipantUser user;

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) {
    return ConversationParticipant(
      id: json['id'] as String,
      userId: json['userId'] as String,
      user: ConversationParticipantUser.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
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
  });

  final String id;
  final String username;
  final AppRole role;
  final String? email;
  final String? avatarUrl;
  final String? status;

  factory ConversationParticipantUser.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role']?.toString();
    return ConversationParticipantUser(
      id: json['id'] as String,
      username: json['name']?.toString() ?? json['username']?.toString() ?? '',
      role: rawRole == null ? AppRole.client : parseRole(rawRole),
      email: json['email']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      status: json['status']?.toString(),
    );
  }
}
