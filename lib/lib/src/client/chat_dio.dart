import 'package:dio/dio.dart';

import 'chat_config.dart';
import 'chat_logger.dart';

Dio createChatDio(ChatServiceConfig config) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: config.sendTimeout,
      headers: config.defaultHeaders,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        config.apiLogger?.call(
          'HTTP request',
          data: {
            'method': options.method,
            'path': options.path,
            'query': options.queryParameters,
            'headers': _sanitizeHeaders(options.headers),
            if (options.data != null) 'body': options.data,
          },
        );
        handler.next(options);
      },
      onResponse: (response, handler) {
        config.apiLogger?.call(
          'HTTP response',
          data: {
            'method': response.requestOptions.method,
            'path': response.requestOptions.path,
            'statusCode': response.statusCode,
            'data': response.data,
          },
        );
        handler.next(response);
      },
      onError: (error, handler) {
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        final message = data is Map<String, dynamic>
            ? (data['message']?.toString() ?? data['error']?.toString())
            : null;

        config.apiLogger?.call(
          'HTTP error',
          data: {
            'method': error.requestOptions.method,
            'path': error.requestOptions.path,
            'statusCode': statusCode,
            'error': error.error?.toString(),
            'response': data,
          },
        );

        final wrapped = DioException(
          requestOptions: error.requestOptions,
          response: error.response,
          type: error.type,
          error: message ??
              'Request failed${statusCode != null ? ' ($statusCode)' : ''}',
        );
        handler.reject(wrapped);
      },
    ),
  );

  return dio;
}

Map<String, Object?> _sanitizeHeaders(Map<String, dynamic> headers) {
  return headers.map((key, value) {
    if (key.toLowerCase() == 'x-api-key' && value is String) {
      return MapEntry(key, redactApiKey(value));
    }
    return MapEntry(key, value);
  });
}
