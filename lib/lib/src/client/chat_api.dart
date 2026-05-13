import 'dart:io';

import 'package:dio/dio.dart';

import 'chat_auth.dart';
import 'chat_config.dart';
import 'chat_exceptions.dart';
import 'models/chat_message.dart';
import 'models/chat_user_registration_payload.dart';

class ChatApi {
  ChatApi(this._dio, this._config);

  final Dio _dio;
  final ChatServiceConfig _config;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e, st) {
      Error.throwWithStackTrace(ChatHttpException.fromDio(e), st);
    }
  }

  Future<Map<String, dynamic>> getTenantScope(ChatAuth auth) {
    return _guard(() async {
      final response = await _dio.get(
        _chatUri('tenant'),
        options: _authOptionsApiKeyOnly(auth),
      );
      return _asMap(_unwrapData(response.data));
    });
  }

  Future<Map<String, dynamic>> registerOrGetUser(
    ChatAuth auth, {
    String? externalTenantId,
    String? externalUserId,
    @Deprecated('Use externalTenantId') String? providerId,
    @Deprecated('Use externalUserId') String? providerUserId,
    String? externalUserRole,
    String? email,
    String? name,
    String? profile,
  }) {
    return _guard(() async {
      final body = ChatUserRegistrationBody.resolve(
        externalTenantId: externalTenantId,
        externalUserId: externalUserId,
        providerId: providerId,
        providerUserId: providerUserId,
        externalUserRole: externalUserRole,
        email: email,
        name: name,
        profile: profile,
      );
      final response = await _dio.post(
        _chatUri('users'),
        options: _authOptionsApiKeyOnly(auth),
        data: body.toRegistrationJson(),
      );

      return _asMap(_unwrapData(response.data));
    });
  }

  /// `POST …/users/start-conversation` (Vitafy: API key + chat-user Bearer).
  Future<Map<String, dynamic>> postUsersStartConversation(
    ChatAuth auth, {
    required List<ChatUserRegistrationBody> users,
    String? groupName,
  }) {
    return _guard(() async {
      if (users.isEmpty) {
        throw ArgumentError(
            'startConversation requires a non-empty users list.');
      }
      for (var i = 0; i < users.length; i++) {
        final u = users[i];
        if (u.externalTenantId.trim().isEmpty ||
            u.externalUserId.trim().isEmpty) {
          throw ArgumentError(
            'startConversation: users[$i] is missing externalTenantId or externalUserId.',
          );
        }
      }
      final response = await _dio.post(
        _chatUri('users/start-conversation'),
        options: _authOptionsChatUser(auth),
        data: <String, dynamic>{
          'users': users.map((u) => u.toRegistrationJson()).toList(),
          if (groupName != null && groupName.trim().isNotEmpty)
            'groupName': groupName.trim(),
        },
      );

      return _asMap(_unwrapData(response.data));
    });
  }

  Future<List<Map<String, dynamic>>> getConversations(
    ChatAuth auth, {
    String? forUserId,
  }) {
    return _guard(() async {
      final response = await _dio.get(
        _chatUri('conversations'),
        options: _authOptionsChatUser(auth),
        queryParameters: {
          if (forUserId != null && forUserId.trim().isNotEmpty)
            'forUserId': forUserId,
        },
      );
      return _asMapList(_unwrapData(response.data));
    });
  }

  Future<List<Map<String, dynamic>>> getUsers(
    ChatAuth auth, {
    int? limit,
    int? page,
  }) {
    return _guard(() async {
      final response = await _dio.get(
        _chatUri('users'),
        options: _authOptionsChatUser(auth),
        queryParameters: <String, dynamic>{
          if (limit != null) 'limit': limit,
          if (page != null) 'page': page,
        },
      );
      return _asMapList(_unwrapData(response.data));
    });
  }

  Future<Map<String, dynamic>> getMessagesPage(
    ChatAuth auth,
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  }) {
    return _guard(() async {
      final response = await _dio.get(
        _chatUri('conversations/$conversationId/messages'),
        options: _authOptionsChatUser(auth),
        queryParameters: {'page': page, 'pageSize': pageSize},
      );

      return _asMap(_unwrapData(response.data));
    });
  }

  Future<Map<String, dynamic>> createConversation(
    ChatAuth auth, {
    required String type,
    String? title,
    String? creatorUserId,
    List<String>? participantIds,
  }) {
    return _guard(() async {
      final normalizedParticipants =
          _normalizeParticipantIds(participantIds, fieldName: 'participantIds');
      final response = await _dio.post(
        _chatUri('conversations'),
        options: _authOptionsChatUser(auth),
        data: {
          'type': type,
          if (title != null && title.trim().isNotEmpty) 'name': title.trim(),
          if (creatorUserId != null && creatorUserId.trim().isNotEmpty)
            'creatorUserId': creatorUserId.trim(),
          if (normalizedParticipants != null)
            'participantIds': normalizedParticipants,
        },
      );

      return _asMap(_unwrapData(response.data));
    });
  }

  Future<Map<String, dynamic>> updateConversation(
    ChatAuth auth, {
    required String conversationId,
    String? title,
    String? actorUserId,
  }) {
    return _guard(() async {
      final trimmedTitle = title?.trim() ?? '';
      final response = await _dio.patch(
        _chatUri('conversations/$conversationId'),
        options: _authOptionsChatUser(auth),
        data: {
          'name': trimmedTitle.isEmpty ? null : trimmedTitle,
          if (actorUserId != null && actorUserId.trim().isNotEmpty)
            'actorUserId': actorUserId.trim(),
        },
      );

      return _asMap(_unwrapData(response.data));
    });
  }

  Future<Map<String, dynamic>> addParticipant(
    ChatAuth auth, {
    required String conversationId,
    required String userId,
    String? actorUserId,
  }) {
    return _guard(() async {
      final response = await _dio.post(
        _chatUri('conversations/$conversationId/participants'),
        options: _authOptionsChatUser(auth),
        data: {
          'userId': userId,
          if (actorUserId != null && actorUserId.trim().isNotEmpty)
            'actorUserId': actorUserId,
        },
      );

      return _asMap(_unwrapData(response.data));
    });
  }

  Future<List<ChatAttachment>> uploadFiles(
    ChatAuth auth,
    List<File> files, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    if (files.isEmpty) {
      return const [];
    }

    return _guard(() async {
      final payload = <String, dynamic>{};
      if (files.length == 1) {
        payload['file'] = await MultipartFile.fromFile(files.first.path);
      } else {
        payload['files'] = await Future.wait(
          files.map((file) => MultipartFile.fromFile(file.path)),
        );
      }

      final response = await _dio.post(
        _normalizePath(_config.uploadPath),
        options: _authOptionsApiKeyOnly(
          auth,
          includeDefaultHeaders: false,
        ),
        data: FormData.fromMap(payload),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );

      final data = _asMap(_unwrapData(response.data));
      final attachments = data['attachments'] as List<dynamic>? ?? <dynamic>[];
      return attachments
          .map(
            (item) =>
                ChatAttachment.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    });
  }

  Future<Map<String, dynamic>> postMessage(
    ChatAuth auth, {
    required String conversationId,
    required String senderId,
    required MessageType type,
    String content = '',
    List<ChatAttachment> attachments = const [],
    String? replyToMessageId,
  }) {
    return _guard(() async {
      final response = await _dio.post(
        _chatUri('conversations/$conversationId/messages'),
        options: _authOptionsChatUser(auth),
        data: {
          'senderId': senderId,
          'type': type.apiValue,
          'content': content,
          if (attachments.isNotEmpty)
            'attachments':
                attachments.map((attachment) => attachment.toJson()).toList(),
          if (replyToMessageId != null && replyToMessageId.trim().isNotEmpty)
            'replyToMessageId': replyToMessageId,
        },
      );

      return _asMap(_unwrapData(response.data));
    });
  }

  Future<Map<String, dynamic>> deleteMessage(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
    required String userId,
  }) {
    return _guard(() async {
      final response = await _dio.delete(
        _chatUri('conversations/$conversationId/messages/$messageId'),
        options: _authOptionsChatUser(auth),
        queryParameters: {'userId': userId},
      );
      return _asMap(_unwrapData(response.data));
    });
  }

  Future<void> deleteConversation(
    ChatAuth auth, {
    required String conversationId,
    String? actorUserId,
  }) {
    return _guard(() async {
      await _dio.delete(
        _chatUri('conversations/$conversationId'),
        options: _authOptionsChatUser(auth),
        queryParameters: <String, dynamic>{
          if (actorUserId != null && actorUserId.trim().isNotEmpty)
            'actorUserId': actorUserId.trim(),
          if (actorUserId != null && actorUserId.trim().isNotEmpty)
            'userId': actorUserId.trim(),
        },
        data: <String, dynamic>{
          if (actorUserId != null && actorUserId.trim().isNotEmpty)
            'actorUserId': actorUserId.trim(),
          if (actorUserId != null && actorUserId.trim().isNotEmpty)
            'userId': actorUserId.trim(),
        },
      );
    });
  }

  Future<Map<String, dynamic>> markMessageDeliveredRest(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
  }) {
    final suffix = _config.resolveDeliveredReceiptPath(
      conversationId,
      messageId,
    );
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        _chatUri(suffix),
        options: _authOptionsChatUser(auth),
        data: const <String, dynamic>{},
      );
      return _asMap(_unwrapData(response.data));
    });
  }

  Future<Map<String, dynamic>> markMessageReadRest(
    ChatAuth auth, {
    required String conversationId,
    required String messageId,
  }) {
    final suffix = _config.resolveReadReceiptPath(
      conversationId,
      messageId,
    );
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        _chatUri(suffix),
        options: _authOptionsChatUser(auth),
        data: const <String, dynamic>{},
      );
      return _asMap(_unwrapData(response.data));
    });
  }

  Options _authOptionsApiKeyOnly(
    ChatAuth auth, {
    bool includeDefaultHeaders = true,
    String? contentType,
  }) {
    return Options(
      headers: auth.toApiHeaders(
        extra: includeDefaultHeaders ? _config.defaultHeaders : const {},
        includeChatUserBearer: false,
      ),
      contentType: contentType,
    );
  }

  Options _authOptionsChatUser(
    ChatAuth auth, {
    bool includeDefaultHeaders = true,
    String? contentType,
  }) {
    if (!auth.hasChatUserAccessToken) {
      throw const ChatUnexpectedResponseException(
        message:
            'ChatAuth.accessToken is required for this request. Use session auth after POST /chat/users or supply the JWT from that response.',
      );
    }
    return Options(
      headers: auth.toApiHeaders(
        extra: includeDefaultHeaders ? _config.defaultHeaders : const {},
        includeChatUserBearer: true,
      ),
      contentType: contentType,
    );
  }

  String _chatUri(String suffix) {
    final base = _normalizePath(_config.chatApiPath);
    final child = suffix.startsWith('/') ? suffix.substring(1) : suffix;
    return '$base/$child';
  }

  String _normalizePath(String path) {
    if (path.isEmpty) {
      return '';
    }
    var normalized = path.trim();
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  dynamic _unwrapData(dynamic raw) {
    // Dio / platform JSON may use Map<dynamic, dynamic>, so avoid `is Map<String, dynamic>`.
    if (raw is Map && raw.containsKey('data')) {
      return raw['data'];
    }
    return raw;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw StateError('Expected JSON object, got ${value.runtimeType}');
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    return (value as List<dynamic>).map((item) => _asMap(item)).toList();
  }

  /// Vitafy `POST .../conversations`: each id must be `ChatUser.id` as a digit string
  /// (same as `vitafy-generic-chat-frontend` `createDirectConversation`).
  static List<String>? _normalizeParticipantIds(
    List<String>? raw, {
    required String fieldName,
  }) {
    if (raw == null) {
      return null;
    }
    final out = <String>[];
    for (final entry in raw) {
      final id = entry.trim();
      if (id.isEmpty) {
        continue;
      }
      if (!RegExp(r'^\d+$').hasMatch(id)) {
        throw ChatUnexpectedResponseException(
          message:
              '$fieldName must contain only ChatUser.id values (decimal digit strings from GET/POST /chat/users). '
              'Got invalid value: "$id"',
        );
      }
      out.add(id);
    }
    if (out.isEmpty) {
      return null;
    }
    return out;
  }
}
