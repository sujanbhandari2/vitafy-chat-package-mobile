import 'app_role.dart';

class TenantUser {
  const TenantUser({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.email,
    required this.role,
    required this.isOnline,
    required this.createdAt,
    this.avatarUrl,
    this.status,
  });

  final String id;
  final String tenantId;
  final String name;
  final String email;
  final AppRole role;
  final bool isOnline;
  final DateTime createdAt;
  final String? avatarUrl;
  final String? status;

  String get displayName => name.isNotEmpty ? name : email;

  factory TenantUser.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role']?.toString();
    return TenantUser(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      name: json['name']?.toString() ?? json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: rawRole == null ? AppRole.client : parseRole(rawRole),
      isOnline:
          json['isOnline'] as bool? ?? json['is_online'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      avatarUrl: json['avatarUrl']?.toString(),
      status: json['status']?.toString(),
    );
  }
}
