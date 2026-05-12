import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'chat_logger.dart';

import 'socket_pretty_logger_vm.dart'
    if (dart.library.html) 'socket_pretty_logger_js.dart';

/// Log severity for Spring-style console lines.
enum SocketLogLevel {
  trace,
  debug,
  info,
  warn,
  error,
}

/// Stable keys emitted by [SocketClient] into `data['kind']`.
enum SocketLogKind {
  connectRequest,
  connected,
  disconnect,
  connectError,
  socketError,
  reconnectAttempt,
  reconnect,
  reconnectFailed,
  emit,
  ack,
  ackTimeout,
  exception,
  inbound,
  clientDisconnect,
  connectTimeout,
  connectFailed,
  legacy,
}

SocketLogLevel _defaultLevelForKind(SocketLogKind kind) {
  switch (kind) {
    case SocketLogKind.reconnectAttempt:
    case SocketLogKind.emit:
    case SocketLogKind.inbound:
    case SocketLogKind.ack:
      return SocketLogLevel.debug;
    case SocketLogKind.reconnectFailed:
      return SocketLogLevel.warn;
    case SocketLogKind.connectError:
    case SocketLogKind.socketError:
    case SocketLogKind.exception:
    case SocketLogKind.connectTimeout:
    case SocketLogKind.connectFailed:
    case SocketLogKind.ackTimeout:
      return SocketLogLevel.error;
    case SocketLogKind.connectRequest:
    case SocketLogKind.connected:
    case SocketLogKind.disconnect:
    case SocketLogKind.reconnect:
    case SocketLogKind.clientDisconnect:
    case SocketLogKind.legacy:
      return SocketLogLevel.info;
  }
}

SocketLogKind? _parseKind(Object? raw) {
  if (raw == null) {
    return null;
  }
  final s = raw.toString();
  for (final k in SocketLogKind.values) {
    if (k.name == s) {
      return k;
    }
  }
  return null;
}

SocketLogLevel? _parseLevel(Object? raw) {
  if (raw == null) {
    return null;
  }
  final s = raw.toString();
  for (final e in SocketLogLevel.values) {
    if (e.name == s) {
      return e;
    }
  }
  return null;
}

/// Spring-style structured console logger for Socket.IO (ANSI optional).
class SocketPrettyLogger {
  SocketPrettyLogger({
    this.category = 'health_messenger.socket.SocketClient',
    this.verboseData = false,
    this.maxDataChars = 1800,
    bool? useAnsi,
    DateTime Function()? clock,
    void Function(String line)? sink,
  })  : _clock = clock ?? DateTime.now,
        _sink = sink ?? debugPrint,
        _useAnsiOverride = useAnsi;

  /// Category column (shortened logger name).
  final String category;

  /// When true, append redacted/truncated JSON for `data` on following lines.
  final bool verboseData;

  /// Max characters for serialized `data` block.
  final int maxDataChars;

  final DateTime Function() _clock;
  final void Function(String) _sink;
  final bool? _useAnsiOverride;

  static final DateFormat _isoWithOffset =
      DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS");

  bool get _effectiveUseAnsi {
    if (_useAnsiOverride != null) {
      return _useAnsiOverride;
    }
    if (kIsWeb) {
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return false;
    }
    return socketPrettyLoggerPlatformAnsi();
  }

  /// Implements [ChatLogger] for [ChatServiceConfig.socketLogger].
  ChatLogger asChatLogger() {
    return (String message, {Object? data}) {
      final map = <String, dynamic>{};
      if (data is Map) {
        map.addAll(Map<String, dynamic>.from(data));
      }
      final kindRaw = map.remove('kind');
      final kind = _parseKind(kindRaw) ?? SocketLogKind.legacy;

      SocketLogLevel level = _defaultLevelForKind(kind);
      final levelOverride = map.remove('level');
      final parsedLevel = _parseLevel(levelOverride);
      if (parsedLevel != null) {
        level = parsedLevel;
      }

      log(level, kind, message, data: map.isEmpty ? null : map);
    };
  }

  /// Emit one primary line (and optional data block).
  void log(
    SocketLogLevel level,
    SocketLogKind kind,
    String message, {
    Map<String, dynamic>? data,
  }) {
    final ts = _formatTimestamp(_clock().toLocal());
    final pid = socketPrettyLoggerPlatformPid();
    final thread = Isolate.current.debugName ?? 'main';
    final levelLabel = level.name.toUpperCase();
    final catTrunc = _truncate(category, 48);
    final msg = _singleLine(message);

    final useAnsi = _effectiveUseAnsi;
    final levelCol = useAnsi
        ? '${_ansiForLevel(level)}${levelLabel.padRight(5)}$_reset'
        : levelLabel.padRight(5);
    final catCol =
        useAnsi ? '$_cyan$catTrunc$_reset' : catTrunc;

    final line =
        '$ts $levelCol $pid --- [ $thread ] $catCol : $msg';
    _sink(line);

    if (verboseData && data != null && data.isNotEmpty) {
      final redacted = _redactDeep(data);
      var blob = const JsonEncoder.withIndent('  ').convert(redacted);
      if (blob.length > maxDataChars) {
        blob = '${blob.substring(0, maxDataChars)}… (truncated)';
      }
      for (final part in blob.split('\n')) {
        _sink('  $part');
      }
    }
  }

  static String _formatTimestamp(DateTime local) {
    final base = _isoWithOffset.format(local);
    final off = local.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final totalMinutes = off.inMinutes.abs();
    final hh = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final mm = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$base$sign$hh:$mm';
  }

  static String _singleLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _truncate(String s, int max) {
    if (s.length <= max) {
      return s;
    }
    return '${s.substring(0, max - 1)}…';
  }

  static const String _reset = '\x1B[0m';
  static const String _cyan = '\x1B[36m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _red = '\x1B[31m';

  static String _ansiForLevel(SocketLogLevel level) {
    switch (level) {
      case SocketLogLevel.trace:
      case SocketLogLevel.debug:
      case SocketLogLevel.info:
        return _green;
      case SocketLogLevel.warn:
        return _yellow;
      case SocketLogLevel.error:
        return _red;
    }
  }

  static Object? _redactDeep(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final e in value.entries) {
        final k = e.key.toString();
        final lk = k.toLowerCase();
        if (lk == 'apikey' || lk == 'x-api-key') {
          out[k] = redactApiKey(e.value?.toString() ?? '');
        } else if (lk == 'authorization' ||
            lk == 'auth' ||
            lk == 'accesstoken' ||
            lk == 'token') {
          out[k] = redactAuthorizationHeader(e.value?.toString() ?? '');
        } else {
          out[k] = _redactValue(e.value);
        }
      }
      return out;
    }
    if (value is List) {
      return value.map(_redactValue).toList();
    }
    return value.toString();
  }

  static Object? _redactValue(Object? v) {
    if (v is Map) {
      return _redactDeep(v);
    }
    if (v is List) {
      return v.map(_redactValue).toList();
    }
    return v;
  }
}
