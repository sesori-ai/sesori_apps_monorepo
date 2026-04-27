import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/server_health_signal.dart";

/// Returns true if [error] is a ClientException whose message embeds a
/// SocketException with "Connection refused" and errno 61 — the typical
/// symptom of the target server not being running.
///
/// ClientException.message has the form:
/// "SocketException: Connection refused (OS Error: Connection refused, errno = 61), ..."
/// so we detect it by pattern rather than a typed field.
bool _isConnectionRefused(Object error) {
  if (error is http.ClientException) {
    final msg = error.message;
    // errno 61 = ECONNREFUSED on macOS and Linux
    return msg.contains("Connection refused") && msg.contains("errno = 61");
  }
  return false;
}

class SseConnection {
  final String _targetUrl;
  final String? _password;
  final void Function(String rawData) _onEvent;
  final Future<void> Function()? _onReconnect;

  bool _active = false;
  int _generation = 0;
  http.Client? _currentClient;
  final StreamController<ServerHealthSignal> _healthSignalController =
      StreamController<ServerHealthSignal>.broadcast();
  /// True once a connection has succeeded at least once. While false (e.g.
  /// during waitReady polling or before the first connection), connection-
  /// refused errors are logged at debug level only. After the first
  /// successful connection, the next failure emits a user-facing warning.
  bool _serverWasEverReachable = false;
  /// Set to true after the first user-facing "server unavailable" warning is
  /// emitted. Reset to false when a connection succeeds so the next failure
  /// gets a fresh warning.
  bool _hasWarnedServerUnavailable = false;

  SseConnection({
    required String targetUrl,
    required String? password,
    required void Function(String rawData) onEvent,
    Future<void> Function()? onReconnect,
  }) : _targetUrl = targetUrl,
       _password = password,
       _onEvent = onEvent,
       _onReconnect = onReconnect;

  Stream<ServerHealthSignal> get healthSignals => _healthSignalController.stream;

  void start() {
    if (_active) return;
    _active = true;
    _generation++;
    unawaited(_streamLoop(_generation));
  }

  void stop() {
    _active = false;
    _generation++;
    _currentClient?.close();
    _currentClient = null;
    if (!_healthSignalController.isClosed) {
      unawaited(_healthSignalController.close());
    }
  }

  Future<void> _streamLoop(int generation) async {
    var isFirstConnect = true;
    var reconnectDelay = const Duration(seconds: 1);

    while (_active && _generation == generation) {
      final client = http.Client();
      _currentClient = client;

      try {
        final request = http.Request(
          "GET",
          Uri.parse("$_targetUrl/global/event"),
        );
        request.headers["Accept"] = "text/event-stream";
        request.headers["Cache-Control"] = "no-cache";

        if (_password != null) {
          final creds = base64.encode(utf8.encode("opencode:$_password"));
          request.headers["Authorization"] = "Basic $creds";
        }

        final response = await client.send(request);
        final contentType = response.headers["content-type"] ?? "";
        if (!contentType.contains("text/event-stream")) {
          throw StateError("Unexpected SSE content type: $contentType");
        }
        if (!_active || _generation != generation) return;

        final wasReconnect = !isFirstConnect;
        if (wasReconnect) {
          await _onReconnect?.call();
        }
        isFirstConnect = false;
        reconnectDelay = const Duration(seconds: 1);
        _hasWarnedServerUnavailable = false;
        _serverWasEverReachable = true;
        if (wasReconnect) {
          _healthSignalController.add(
            const ServerHealthSignal(type: ServerHealthSignalType.serverReachable),
          );
        }
        await _readStream(response, generation);
      } catch (e, st) {
        if (!_active || _generation != generation) return;

        if (_isConnectionRefused(e)) {
          // "Connection refused" means the server is not running on that host/port.
          // If the server was never reachable (e.g. --no-auto-start with no server,
          // or during waitReady polling), stay silent at info level so the
          // terminal isn't flooded during startup. After the first successful
          // connection, emit a one-time user-facing warning; subsequent retries
          // log only at debug level.
          if (_serverWasEverReachable) {
            if (!_hasWarnedServerUnavailable) {
              _hasWarnedServerUnavailable = true;
              _healthSignalController.add(
                const ServerHealthSignal(type: ServerHealthSignalType.serverUnreachable),
              );
              Log.w("[sse-conn] OpenCode server is not running at $_targetUrl. "
                  "Start it with: opencode serve");
            } else {
              Log.d("[sse-conn] connection refused (server still unavailable), retrying...");
            }
          } else {
            Log.d("[sse-conn] connection refused (server not yet reachable), retrying...");
          }
        } else {
          Log.e("[sse-conn] stream loop error: $e\n$st");
        }
      } finally {
        client.close();
        if (_currentClient == client) _currentClient = null;
      }

      if (!_active || _generation != generation) return;

      await Future<void>.delayed(reconnectDelay);
      final doubled = reconnectDelay.inSeconds * 2;
      reconnectDelay = Duration(seconds: doubled > 30 ? 30 : doubled);
    }
  }

  Future<void> _readStream(http.StreamedResponse response, int generation) async {
    final dataLines = <String>[];
    final lineBuf = StringBuffer();

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      if (!_active || _generation != generation) return;

      lineBuf.write(chunk);
      final text = lineBuf.toString();
      final parts = text.split("\n");

      lineBuf.clear();
      lineBuf.write(parts.last);

      for (var i = 0; i < parts.length - 1; i++) {
        final raw = parts[i];
        final line = raw.endsWith("\r") ? raw.substring(0, raw.length - 1) : raw;

        if (line.isEmpty) {
          if (dataLines.isNotEmpty) {
            try {
              _onEvent(dataLines.join("\n"));
            } catch (e, st) {
              Log.e("[sse-conn] onEvent callback error: $e\n$st");
            }
            dataLines.clear();
          }
          continue;
        }

        if (line.startsWith("data:")) {
          final rawValue = line.substring(5);
          final value = rawValue.startsWith(" ") ? rawValue.substring(1) : rawValue;
          dataLines.add(value);
        }
      }
    }

    if (dataLines.isNotEmpty) {
      try {
        _onEvent(dataLines.join("\n"));
      } catch (e, st) {
        Log.e("[sse-conn] onEvent callback error: $e\n$st");
      }
      dataLines.clear();
    }
  }
}
