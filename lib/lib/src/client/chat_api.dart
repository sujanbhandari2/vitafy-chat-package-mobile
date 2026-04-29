import 'dart:io';

import 'package:dio/dio.dart';

import 'chat_auth.dart';
import 'chat_config.dart';
import 'chat_exceptions.dart';
import 'models/chat_message.dart';

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
        options: _authOptions(auth),
      );
      return _asMap(_unwrapData(response.data));
    });
  }

  Future<Map<String, dynamic>> registerOrGetUser(
    ChatAuth auth, {
    required String providerId,
    required String providerUserId,
    required String email,
    String? name,
  }) {
    return _guard(() async {
      final response = await _dio.post(
        _chatUri('users'),
        options: _authOptions(auth),
        data: {
          'providerId': providerId,
          'providerUserId': providerUserId,
          'email': email,
          if (name != null && name.trim().isNotEmpty) 'name': name,
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
        options: _authOptions(auth),
        queryParameters: {
          if (forUserId != null && forUserId.trim().isNotEmpty)
            'forUserId': forUserId,
        },
      );
      return _asMapList(_unwrapData(response.data));
    });
  }

  Future<List<Map<String, dynamic>>> getUsers(ChatAuth auth) {
    return _guard(() async {
      final response = await _dio.get(
        _chatUri('users'),
        options: _authOptions(auth),
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
        options: _authOptions(auth),
        queryParameters: {'page': page, 'pageSize': pageSize},
      );

      return _asMap(_unwrapData(response.data));
    });
  }

  Future<Map<String, dynamic>> createConversation(
    ChatAuth auth, {
    required String type,
    String? creatorUserId,
    List<String>? participantIds,
  }) {
    return _guard(() async {
      final response = await _dio.post(
        _chatUri('conversations'),
        options: _authOptions(auth),
        data: {
          'type': type,
          if (creatorUserId != null && creatorUserId.trim().isNotEmpty)
            'creatorUserId': creatorUserId,
          if (participantIds != null) 'participantIds': participantIds,
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
        options: _authOptions(auth),
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
        options: _authOptions(
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
        options: _authOptions(auth),
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
        options: _authOptions(auth),
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
        options: _authOptions(auth),
        data: const <String, dynamic>{},
      );
      return _asMap(_unwrapData(response.data));
    });
  }

  Options _authOptions(
    ChatAuth auth, {
    bool includeDefaultHeaders = true,
    String? contentType,
  }) {
    return Options(
      headers: auth.toApiHeaders(
        includeDefaultHeaders ? _config.defaultHeaders : const {},
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
    if (raw is Map<String, dynamic> && raw.containsKey('data')) {
      return raw['data'];
    }
    return raw;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return Map<String, dynamic>.from(value as Map);
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    return (value as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
}
