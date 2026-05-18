import 'app_role.dart';
import 'chat_message.dart';

ChatMessage? _latestMessageFromJson(Map<String, dynamic> json) {
  final raw = json['latestMessage'] ?? json['latest_message'];
  if (raw is! Map) {
    return null;
  }
  return ChatMessage.fromJson(Map<String, dynamic>.from(raw));
}

/// Per-user read/delivery pointers for a conversation.
class ConversationMessageStatus {
  const ConversationMessageStatus({
    required this.userId,
    this.lastReadMessageId,
    this.lastDeliveredMessageId,
  });

  final String userId;
  final String? lastReadMessageId;
  final String? lastDeliveredMessageId;

  factory ConversationMessageStatus.fromJson(Map<String, dynamic> json) {
    final userId = (json['userId'] ??
            json['chatUserId'] ??
            json['chat_user_id'] ??
            json['user_id'] ??
            '')
        .toString()
        .trim();
    String? readId = _trimToNull(json['lastReadMessageId'] ??
        json['last_read_message_id'] ??
        json['lastReadId'] ??
        json['last_read_id']);
    String? deliveredId = _trimToNull(json['lastDeliveredMessageId'] ??
        json['last_delivered_message_id'] ??
        json['lastDeliveredId'] ??
        json['last_delivered_id']);
    return ConversationMessageStatus(
      userId: userId,
      lastReadMessageId: readId,
      lastDeliveredMessageId: deliveredId,
    );
  }
}

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
    this.unreadCount,
    this.latestMessage,
    this.latestMessageId,
    this.messageState,
    this.messageStatusByUserId = const <String, ConversationMessageStatus>{},
  });

  final String id;
  final String tenantId;
  final String type;
  final String? title;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConversationParticipant> participants;

  /// Per-user unread from REST list, if the API provides it.
  final int? unreadCount;

  /// Last message on the conversation from REST list payloads (e.g. getConversations).
  final ChatMessage? latestMessage;

  /// Latest message id on the conversation. Falls back to [latestMessage]?.id
  /// when the server only ships the embedded message.
  final String? latestMessageId;

  /// Current user's read/delivery pointers from REST list `messageState`.
  final ConversationMessageStatus? messageState;

  /// Per-user read/delivery pointers, keyed by user id.
  ///
  /// Sourced from any of these JSON shapes (first non-empty wins):
  ///   - top-level `messageStatus` / `messageStatuses` / `userStatuses` array
  ///   - per-participant `messageStatus` object on `participants[]`
  final Map<String, ConversationMessageStatus> messageStatusByUserId;

  bool get isGlobal => type.toUpperCase() == 'SUPPORT';

  String? _effectiveLatestMessageId() {
    final fromField = latestMessageId?.trim();
    if (fromField != null && fromField.isNotEmpty) {
      return fromField;
    }
    final fromMessage = latestMessage?.id.trim();
    if (fromMessage != null && fromMessage.isNotEmpty) {
      return fromMessage;
    }
    return null;
  }

  /// True when [userId] has at least one unread inbound message.
  ///
  /// Uses REST `messageState` / `messageStatus` cursors vs `latestMessage` id.
  /// Returns `false` when the latest row is your own send, or when read and
  /// delivery cursors are tied to the same id at/ past latest (outbound / caught up).
  bool isUnreadFor(String userId) {
    final me = userId.trim();
    if (me.isEmpty) {
      return false;
    }

    final latest = latestMessage;
    if (latest != null && latest.senderId.trim() == me) {
      return false;
    }

    final latestIdStr = _effectiveLatestMessageId();
    final latestId = int.tryParse(latestIdStr ?? '');
    if (latestId == null) {
      return false;
    }

    final status = messageStatusByUserId[me] ?? messageState;
    final lastReadRaw = status?.lastReadMessageId?.trim();
    final lastDeliveredRaw = status?.lastDeliveredMessageId?.trim();

    if (lastReadRaw != null &&
        lastReadRaw.isNotEmpty &&
        lastDeliveredRaw != null &&
        lastDeliveredRaw.isNotEmpty &&
        lastReadRaw == lastDeliveredRaw) {
      final tiedId = int.tryParse(lastReadRaw);
      if (tiedId != null && tiedId >= latestId) {
        return false;
      }
    }

    if (lastReadRaw == null || lastReadRaw.isEmpty) {
      return true;
    }

    final lastReadId = int.tryParse(lastReadRaw);
    if (lastReadId == null) {
      return true;
    }
    return latestId > lastReadId;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawParticipants =
        json['participants'] as List<dynamic>? ?? <dynamic>[];

    int? parseUnread(Object? raw) {
      if (raw == null) {
        return null;
      }
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.toInt();
      }
      return int.tryParse(raw.toString());
    }

    final participants = rawParticipants
        .map(
          (item) => ConversationParticipant.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    final latest = _latestMessageFromJson(json);
    final latestId = _trimToNull(json['latestMessageId'] ??
            json['latest_message_id'] ??
            json['lastMessageId'] ??
            json['last_message_id']) ??
        latest?.id.trim();

    return Conversation(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'DIRECT',
      title: (json['title'] ?? json['name'])?.toString(),
      createdBy: json['createdBy']?.toString(),
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt']?.toString() ??
            json['createdAt']?.toString() ??
            DateTime.now().toIso8601String(),
      ),
      unreadCount: parseUnread(json['unreadCount'] ?? json['unread']),
      participants: participants,
      latestMessage: latest,
      latestMessageId: (latestId == null || latestId.isEmpty) ? null : latestId,
      messageState: _messageStateFromJson(json),
      messageStatusByUserId: _messageStatusFromJson(json, rawParticipants),
    );
  }
}

ConversationMessageStatus? _messageStateFromJson(Map<String, dynamic> json) {
  final raw = json['messageState'] ?? json['message_state'];
  if (raw is! Map) {
    return null;
  }
  return ConversationMessageStatus.fromJson(
    Map<String, dynamic>.from(raw),
  );
}

Map<String, ConversationMessageStatus> _messageStatusFromJson(
  Map<String, dynamic> json,
  List<dynamic> rawParticipants,
) {
  final out = <String, ConversationMessageStatus>{};

  // Top-level array shapes.
  final topLevel = json['messageStatus'] ??
      json['messageStatuses'] ??
      json['userStatuses'] ??
      json['statuses'];
  if (topLevel is List) {
    for (final item in topLevel) {
      if (item is! Map) continue;
      final status = ConversationMessageStatus.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (status.userId.isEmpty) continue;
      out[status.userId] = status;
    }
  }

  // Per-participant `messageStatus` object fallback.
  for (final raw in rawParticipants) {
    if (raw is! Map) continue;
    final part = Map<String, dynamic>.from(raw);
    final embedded = part['messageStatus'] ??
        part['message_status'] ??
        part['messageState'] ??
        part['message_state'];
    if (embedded is! Map) continue;
    final embeddedMap = Map<String, dynamic>.from(embedded);
    final pid = (part['chatUserId'] ??
            part['userId'] ??
            embeddedMap['userId'] ??
            embeddedMap['chatUserId'] ??
            '')
        .toString()
        .trim();
    if (pid.isEmpty) continue;
    if (out.containsKey(pid)) continue;
    embeddedMap['userId'] = pid;
    out[pid] = ConversationMessageStatus.fromJson(embeddedMap);
  }

  return out;
}

String? _trimToNull(Object? raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
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
    final participantChatUserId = json['chatUserId']?.toString().trim() ??
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
    final idStr =
        _firstNonEmpty(json, const ['id', 'chatUserId', 'chat_user_id'])
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
    'externalUserId',
    'external_user_id',
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
