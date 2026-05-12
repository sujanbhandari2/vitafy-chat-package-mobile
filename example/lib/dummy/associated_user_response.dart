import 'dart:convert';

/// Example-only mirror of the host app's associated-user payload (no vitafyhealthclient).
///
/// [chatUserRole] / [chatUid] rules follow a **best-effort** copy of the host
/// `fromJson`; adjust [exampleCometChatUserRole] if your backend uses different labels.
AssociatedUserResponse associatedUserResponseFromJson(String str) =>
    AssociatedUserResponse.fromJson(
      json.decode(str) as Map<String, dynamic>,
    );

String associatedUserResponseToJson(AssociatedUserResponse data) =>
    json.encode(data.toJson());

class AssociatedUserResponse {
  const AssociatedUserResponse({
    required this.userId,
    required this.email,
    required this.id,
    required this.profilePicture,
    required this.type,
    required this.name,
    required this.tenantId,
    required this.tenantCode,
    this.chatUid,
    this.chatUserRole,
  });

  final String userId;
  final String email;
  final String id;
  final String profilePicture;
  final String type;
  final String name;
  final String tenantId;
  final String tenantCode;
  final String? chatUid;
  final String? chatUserRole;

  factory AssociatedUserResponse.fromJson(Map<String, dynamic> json) {
    final typeRaw = json['type']?.toString() ?? '';
    final chatUserRole = exampleCometChatUserRole(_capitalize(typeRaw));
    final tenantCode = json['tenantCode']?.toString() ?? '';
    final userId = json['userId']?.toString() ?? '';
    final isAdmin = typeRaw.toLowerCase() == 'admin';
    final chatUid = isAdmin
        ? '$tenantCode-$userId'
        : '${tenantCode}_${userId}_$chatUserRole';

    return AssociatedUserResponse(
      userId: userId,
      email: json['email']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      profilePicture: json['profilePicture']?.toString() ?? '',
      type: typeRaw,
      name: json['name']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      tenantCode: tenantCode,
      chatUserRole: chatUserRole,
      chatUid: chatUid,
    );
  }

  Map<String, dynamic> toJson() {
    final fields = <String, dynamic>{
      'userId': userId,
      'email': email,
      'id': id,
      'profilePicture': profilePicture,
      'type': type,
      'name': name,
      'tenantId': tenantId,
      'tenantCode': tenantCode,
    };
    return Map<String, dynamic>.from(fields)
      ..removeWhere((_, value) => value == null);
  }

  static List<AssociatedUserResponse> fromJsonList(List<dynamic> json) =>
      json
          .map((x) => AssociatedUserResponse.fromJson(Map<String, dynamic>.from(x as Map)))
          .toList(growable: false);
}

String _capitalize(String input) {
  final t = input.trim();
  if (t.isEmpty) {
    return t;
  }
  return t[0].toUpperCase() + t.substring(1).toLowerCase();
}

/// Stand-in for host `getCometChatUserRole(capitalize(type))`.
String exampleCometChatUserRole(String capitalizedType) {
  switch (capitalizedType.toLowerCase()) {
    case 'admin':
      return 'ADMIN';
    case 'doctor':
    case 'physician':
      return 'DOCTOR';
    case 'patient':
      return 'PATIENT';
    case 'nurse':
      return 'NURSE';
    default:
      return capitalizedType.toUpperCase();
  }
}
