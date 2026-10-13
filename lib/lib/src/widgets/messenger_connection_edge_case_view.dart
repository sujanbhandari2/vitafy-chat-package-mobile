import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../client/chat_exceptions.dart';

/// User-facing connection states that a host app can render in its own style.
enum MessengerConnectionEdgeCaseType {
  noInternet,
  timeout,
  unavailable,
}

/// Sanitized connection failure details passed to the host UI.
///
/// The original [error] is retained for diagnostics, but package widgets never
/// render it directly.
class MessengerConnectionEdgeCase {
  const MessengerConnectionEdgeCase({
    required this.type,
    required this.error,
  });

  final MessengerConnectionEdgeCaseType type;
  final Object? error;

  factory MessengerConnectionEdgeCase.fromError(Object? error) {
    final httpError = ChatException.asHttp(error);
    final dioError = error is DioException
        ? error
        : httpError?.cause is DioException
            ? httpError!.cause! as DioException
            : null;
    final searchable = [
      error,
      httpError?.message,
      httpError?.cause,
      dioError?.message,
      dioError?.error,
    ].whereType<Object>().map((value) => value.toString().toLowerCase()).join(
          ' ',
        );

    if (_containsAny(searchable, const [
      'failed host lookup',
      'no internet connection',
      'network is unreachable',
      'no route to host',
      'no address associated with hostname',
      'internet connection appears to be offline',
    ])) {
      return MessengerConnectionEdgeCase(
        type: MessengerConnectionEdgeCaseType.noInternet,
        error: error,
      );
    }

    final dioType = dioError?.type ?? httpError?.dioType;
    if (dioType == DioExceptionType.connectionTimeout ||
        dioType == DioExceptionType.receiveTimeout ||
        dioType == DioExceptionType.sendTimeout ||
        _containsAny(searchable, const [
          'connection timeout',
          'receive timeout',
          'send timeout',
          'timed out',
        ])) {
      return MessengerConnectionEdgeCase(
        type: MessengerConnectionEdgeCaseType.timeout,
        error: error,
      );
    }

    return MessengerConnectionEdgeCase(
      type: MessengerConnectionEdgeCaseType.unavailable,
      error: error,
    );
  }

  static bool _containsAny(String value, List<String> candidates) {
    return candidates.any(value.contains);
  }
}

typedef MessengerConnectionEdgeCaseBuilder = Widget Function(
  BuildContext context,
  MessengerConnectionEdgeCase edgeCase,
);

/// Classifies a connection failure and delegates all visuals to the host app.
class MessengerConnectionEdgeCaseView extends StatelessWidget {
  const MessengerConnectionEdgeCaseView({
    super.key,
    required this.error,
    required this.builder,
  });

  final Object? error;
  final MessengerConnectionEdgeCaseBuilder builder;

  @override
  Widget build(BuildContext context) {
    return builder(context, MessengerConnectionEdgeCase.fromError(error));
  }
}
