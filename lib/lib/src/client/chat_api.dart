import 'dart:io';

import 'package:dio/dio.dart';

class ChatApi {
  ChatApi(this._dio);

  final Dio _dio;

  Options _authOptions(String token) {
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<Map<String, dynamic>>> getConversations(String token) async {
    final response = await _dio.get(
      '/conversations',
      options: _authOptions(token),
    );
    final data =
        (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getUsers(String token) async {
    final response = await _dio.get('/users', options: _authOptions(token));
    final data =
        (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String token,
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _dio.get(
      '/conversations/$conversationId/messages',
      options: _authOptions(token),
      queryParameters: {'page': page, 'pageSize': pageSize},
    );

    final data =
        (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>> createConversation(
    String token,
    List<String> participantIds,
  ) async {
    final response = await _dio.post(
      '/conversations',
      options: _authOptions(token),
      data: {'participantIds': participantIds},
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> createDirectConversation(
    String token,
    String userId,
  ) async {
    final response = await _dio.post(
      '/conversations/direct',
      options: _authOptions(token),
      data: {'userId': userId},
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<String> uploadFile(String token, File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });

    final response = await _dio.post(
      '/upload',
      data: formData,
      options: _authOptions(token),
    );

    return (response.data as Map<String, dynamic>)['url'] as String;
  }
}
