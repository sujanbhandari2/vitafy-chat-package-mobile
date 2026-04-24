import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';

void main() {
  group('ChatHttpException.fromDio', () {
    test('maps Nest-style message and retryable 503', () {
      final dio = DioException(
        requestOptions: RequestOptions(path: '/api/v1/chat/tenant'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/chat/tenant'),
          statusCode: 503,
          data: {'message': 'Service unavailable'},
        ),
        type: DioExceptionType.badResponse,
      );

      final ex = ChatHttpException.fromDio(dio);
      expect(ex.message, 'Service unavailable');
      expect(ex.statusCode, 503);
      expect(ex.isRetryable, isTrue);
      expect(ex.requestPath, '/api/v1/chat/tenant');
    });

    test('connection error is retryable', () {
      final dio = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      final ex = ChatHttpException.fromDio(dio);
      expect(ex.isRetryable, isTrue);
    });
  });
}
