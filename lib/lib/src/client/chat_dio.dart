import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'chat_config.dart';
import 'chat_exceptions.dart';
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

  dio.interceptors.add(_ChatRequestIdInterceptor(config));
  dio.interceptors.add(_ChatLoggingInterceptor(config));
  if (config.maxIdempotentRetries > 0) {
    dio.interceptors.add(_ChatRetryInterceptor(dio, config));
  }

  return dio;
}

class _ChatRequestIdInterceptor extends Interceptor {
  _ChatRequestIdInterceptor(this._config);

  final ChatServiceConfig _config;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final name = _config.requestIdHeaderName?.trim();
    final gen = _config.requestIdGenerator;
    if (name != null && name.isNotEmpty && gen != null) {
      final headers = Map<String, dynamic>.from(options.headers);
      headers[name] = gen();
      options.headers = headers;
    }
    handler.next(options);
  }
}

class _ChatRetryInterceptor extends Interceptor {
  _ChatRetryInterceptor(this._dio, this._config);

  final Dio _dio;
  final ChatServiceConfig _config;

  static const _retryCountKey = 'chat_retry_attempts';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = err.requestOptions;
    if (!_isIdempotentGet(opts.method)) {
      return handler.next(err);
    }
    final attempts = (opts.extra[_retryCountKey] as int?) ?? 0;
    if (attempts >= _config.maxIdempotentRetries) {
      return handler.next(err);
    }
    final httpEx = ChatHttpException.fromDio(err);
    if (!httpEx.isRetryable) {
      return handler.next(err);
    }
    final nextAttempts = attempts + 1;
    opts.extra[_retryCountKey] = nextAttempts;
    final delayMs = _config.idempotentRetryBaseDelay.inMilliseconds *
        math.pow(2, attempts).round();
    await Future<void>.delayed(Duration(milliseconds: math.min(delayMs, 8000)));
    try {
      final response = await _dio.fetch(opts);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isIdempotentGet(String method) {
    return method.toUpperCase() == 'GET';
  }
}

class _ChatLoggingInterceptor extends Interceptor {
  _ChatLoggingInterceptor(this._config);

  final ChatServiceConfig _config;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _config.apiLogger?.call(
      'HTTP request',
      data: {
        'method': options.method,
        'path': options.path,
        'query': options.queryParameters,
        'headers': _sanitizeHeaders(options.headers),
        if (_config.verboseNetworkLogging && options.data != null)
          'body': options.data,
      },
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _config.apiLogger?.call(
      'HTTP response',
      data: {
        'method': response.requestOptions.method,
        'path': response.requestOptions.path,
        'statusCode': response.statusCode,
        if (_config.verboseNetworkLogging) 'data': response.data,
      },
    );
    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    _config.apiLogger?.call(
      'HTTP error',
      data: {
        'method': error.requestOptions.method,
        'path': error.requestOptions.path,
        'statusCode': statusCode,
        'error': error.error?.toString(),
        if (_config.verboseNetworkLogging) 'response': data,
      },
    );

    handler.next(error);
  }
}

Map<String, Object?> _sanitizeHeaders(Map<String, dynamic> headers) {
  return headers.map((key, value) {
    if (key.toLowerCase() == 'x-api-key' && value is String) {
      return MapEntry(key, redactApiKey(value));
    }
    return MapEntry(key, value);
  });
}
