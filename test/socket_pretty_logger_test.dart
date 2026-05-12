import 'package:flutter_test/flutter_test.dart';
import 'package:health_messenger_ui/lib/health_messenger_client.dart';

void main() {
  test('log line includes level, category, and message (no ANSI)', () {
    final lines = <String>[];
    final fixed = DateTime(2024, 4, 6, 12, 0, 0, 0);
    final logger = SocketPrettyLogger(
      useAnsi: false,
      clock: () => fixed,
      sink: lines.add,
      category: 'test.SocketClient',
    );

    logger.log(
      SocketLogLevel.info,
      SocketLogKind.connected,
      'Socket connected',
      data: {'id': 'sid-1'},
    );

    expect(lines, isNotEmpty);
    expect(lines.first, contains('INFO'));
    expect(lines.first, contains('test.SocketClient'));
    expect(lines.first, contains('Socket connected'));
    expect(lines.first, contains('2024-04-06'));
    expect(lines.first, contains('---'));
    expect(lines.first, matches(RegExp(r'\d+ --- \[')));
  });

  test('asChatLogger maps kind and optional level override', () {
    final lines = <String>[];
    final logger = SocketPrettyLogger(
      useAnsi: false,
      clock: () => DateTime(2024, 1, 1),
      sink: lines.add,
    );
    final chatLog = logger.asChatLogger();
    chatLog(
      'Socket emit',
      data: {
        'kind': SocketLogKind.emit.name,
        'event': 'send_message',
        'payload': <String, dynamic>{'x': 1},
      },
    );

    expect(lines.first, contains('DEBUG'));
    expect(lines.first, contains('Socket emit'));
  });

  test('verboseData serializes redacted apiKey', () {
    final lines = <String>[];
    final logger = SocketPrettyLogger(
      useAnsi: false,
      verboseData: true,
      maxDataChars: 4000,
      clock: () => DateTime(2024, 1, 1),
      sink: lines.add,
    );
    logger.log(
      SocketLogLevel.info,
      SocketLogKind.connectRequest,
      'connect',
      data: {
        'apiKey': 'vfk_ak_012345678901234567890',
        'url': 'https://example.com',
      },
    );

    final blob = lines.skip(1).join('\n');
    expect(blob, isNot(contains('vfk_ak_012345678901234567890')));
    expect(blob, contains('vfk_'));
    expect(blob, contains('example.com'));
  });
}
