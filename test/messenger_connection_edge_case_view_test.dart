import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_ui.dart';

void main() {
  test('classifies failed host lookup as no internet', () {
    final dioError = DioException(
      requestOptions: RequestOptions(path: '/conversations'),
      type: DioExceptionType.connectionError,
      error: const SocketExceptionStub(
        'Failed host lookup: api-generic-chat.viafyhealth.com',
      ),
    );
    final error = ChatHttpException.fromDio(dioError);

    final edgeCase = MessengerConnectionEdgeCase.fromError(error);

    expect(edgeCase.type, MessengerConnectionEdgeCaseType.noInternet);
  });

  test('classifies host-sanitized no-connection message as no internet', () {
    final edgeCase = MessengerConnectionEdgeCase.fromError(
      'No internet connection. Please try again.',
    );

    expect(edgeCase.type, MessengerConnectionEdgeCaseType.noInternet);
  });

  test('classifies transport timeout separately', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/conversations'),
      type: DioExceptionType.connectionTimeout,
    );

    final edgeCase = MessengerConnectionEdgeCase.fromError(error);

    expect(edgeCase.type, MessengerConnectionEdgeCaseType.timeout);
  });

  testWidgets('delegates connection edge case rendering to host builder',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerConnectionEdgeCaseView(
          error: Exception('Failed host lookup: chat.example.com'),
          builder: (context, edgeCase) => Text(
            'host-${edgeCase.type.name}',
          ),
        ),
      ),
    );

    expect(find.text('host-noInternet'), findsOneWidget);
    expect(find.textContaining('chat.example.com'), findsNothing);
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub(this.message);

  final String message;

  @override
  String toString() => 'SocketException: $message';
}
