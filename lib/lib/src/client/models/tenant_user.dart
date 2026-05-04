import 'dart:convert';

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
    this.accessToken,
    this.tokenType,
    this.providerUserId,
  });

  final String id;
  final String tenantId;
  final String name;
  final String email;

  /// External id from the host app (`provider_user_id` on the wire).
  final String? providerUserId;
  final AppRole role;
  final bool isOnline;
  final DateTime createdAt;
  final String? avatarUrl;
  final String? status;

  /// From `POST /api/v1/chat/users` only; omitted on `GET /chat/users` list rows.
  final String? accessToken;

  /// e.g. `Bearer` when [accessToken] is present.
  final String? tokenType;

  String get displayName {
    final n = name.trim();
    if (n.isNotEmpty) {
      return n;
    }
    final e = email.trim();
    if (e.isNotEmpty) {
      return e;
    }
    final p = (providerUserId ?? '').trim();
    if (p.isNotEmpty) {
      return p;
    }
    final idStr = id.trim();
    if (idStr.isNotEmpty) {
      return 'User $idStr';
    }
    return 'User';
  }

  factory TenantUser.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role']?.toString();
    // Vitafy API returns `id` (ChatUser primary key). Accept aliases for robustness.
    var idStr = _firstNonEmptyString(
          json,
          const ['id', 'chatUserId', 'chat_user_id'],
        ) ??
        '';
    final accessToken = json['accessToken']?.toString().trim();
    // POST /chat/users always returns a JWT with `chatUserId`; some gateways omit `id` in JSON.
    if (idStr.isEmpty &&
        accessToken != null &&
        accessToken.isNotEmpty) {
      idStr = _readChatUserIdFromJwt(accessToken) ?? '';
    }
    final provider =
        _firstNonEmptyString(json, const ['providerUserId', 'provider_user_id']);
    return TenantUser(
      id: idStr,
      tenantId: _firstNonEmptyString(
            json,
            const ['tenantId', 'tenant_id'],
          ) ??
          '',
      name: _firstNonEmptyString(json, const ['name', 'username']) ?? '',
      email: _firstNonEmptyString(json, const ['email']) ?? '',
      role: rawRole == null ? AppRole.client : parseRole(rawRole),
      isOnline:
          json['isOnline'] as bool? ?? json['is_online'] as bool? ?? false,
      createdAt: DateTime.tryParse(
            _firstNonEmptyString(
                  json,
                  const ['createdAt', 'created_at'],
                ) ??
                '',
          ) ??
          DateTime.now(),
      avatarUrl: _firstNonEmptyString(
        json,
        const ['avatarUrl', 'avatar_url'],
      ),
      status: _firstNonEmptyString(json, const ['status']),
      accessToken: json['accessToken']?.toString(),
      tokenType: json['tokenType']?.toString(),
      providerUserId: provider,
    );
  }
}

/// Reads Vitafy chat-user JWT claim `chatUserId` (unsigned payload parse only).
String? _readChatUserIdFromJwt(String token) {
  final parts = token.split('.');
  if (parts.length < 2) {
    return null;
  }
  var segment = parts[1];
  switch (segment.length % 4) {
    case 2:
      segment = '$segment==';
      break;
    case 3:
      segment = '$segment=';
      break;
    default:
      break;
  }
  try {
    final decoded = utf8.decode(base64Url.decode(segment));
    final raw = jsonDecode(decoded);
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    for (final key in ['chatUserId', 'chat_user_id', 'sub']) {
      final v = map[key];
      if (v == null) {
        continue;
      }
      final s = v.toString().trim();
      if (s.isNotEmpty && RegExp(r'^\d+$').hasMatch(s)) {
        return s;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

String? _firstNonEmptyString(Map<String, dynamic> json, List<String> keys) {
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
