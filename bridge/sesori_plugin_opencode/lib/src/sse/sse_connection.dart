import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class SseConnection {
  final String _targetUrl;
  final String? _password;
  final void Function(String rawData) _onEvent;
  final Future<void> Function()? _onReconnect;
  final void Function()? _onConnected;
  final void Function()? _onDisconnected;

  bool _active = false;
  int _generation = 0;
  http.Client? _currentClient;

  SseConnection({
    required String targetUrl,
    required String? password,
    required void Function(String rawData) onEvent,
    Future<void> Function()? onReconnect,
    void Function()? onConnected,
    void Function()? onDisconnected,
  }) : _targetUrl = targetUrl,
       _password = password,
       _onEvent = onEvent,
       _onReconnect = onReconnect,
       _onConnected = onConnected,
       _onDisconnected = onDisconnected;

  void start() {
    if (_active) return;
    _active = true;
    _generation++;
    unawaited(_streamLoop(_generation));
  }

  void stop() {
    Log.v("[shutdown] SseConnection.stop: active=$_active -> false, closing current client");
    _active = false;
    _generation++;
    _currentClient?.close();
    _currentClient = null;
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

        // The transport is live: signal connected on the first connect and on
        // every reconnect (the lifecycle status follows the live stream).
        _onConnected?.call();

        if (!isFirstConnect) {
          final reconnectSw = Stopwatch()..start();
          Log.v("[sse-conn] reconnect: running onReconnect cold-start");
          await _onReconnect?.call();
          if (!_active || _generation != generation) {
            Log.v("[sse-conn] reconnect: shutdown requested during onReconnect, dropping");
            return;
          }
          Log.v("[sse-conn] reconnect: onReconnect cold-start finished in ${reconnectSw.elapsedMilliseconds}ms");
        }
        isFirstConnect = false;
        reconnectDelay = const Duration(seconds: 1);
        await _readStream(response, generation);
      } catch (e, st) {
        if (!_active || _generation != generation) return;
        Log.e("[sse-conn] stream loop error: $e\n$st");
      } finally {
        client.close();
        if (_currentClient == client) _currentClient = null;
      }

      if (!_active || _generation != generation) return;

      // The stream is not live right now — it either dropped after connecting or
      // the connection attempt failed (including the very first attempt, after
      // the descriptor already reported Ready off a successful cold-start). Fire
      // onDisconnected so the lifecycle status can debounce to degraded; a
      // deliberate stop() returns above and never reports disconnect. The status
      // reporter debounces, so a quick reconnect cancels it before it surfaces.
      _onDisconnected?.call();

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
