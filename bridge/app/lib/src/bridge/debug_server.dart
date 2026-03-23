import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

class DebugServer {
  final BridgePlugin _plugin;
  final int port;
  HttpServer? _server;
  final List<HttpResponse> _sseClients = [];
  StreamSubscription<BridgeSseEvent>? _pluginEventsSub;

  int _nextRequestId = 1;

  DebugServer(BridgePlugin plugin, {required this.port}) : _plugin = plugin;

  int? get boundPort => _server?.port;

  Future<void> start() async {
    if (_server != null) {
      return;
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;

    Log.i("Debug server listening on http://127.0.0.1:${server.port}");
    server.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _pluginEventsSub?.cancel();
    _pluginEventsSub = null;
    final clients = List<HttpResponse>.from(_sseClients);
    _sseClients.clear();
    for (final client in clients) {
      try {
        await client.close();
      } catch (_) {}
    }
    final server = _server;
    _server = null;
    await server?.close();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path == "/global/event") {
      await _handleSSE(request);
      return;
    }

    await _handleHTTP(request);
  }

  Future<void> _handleHTTP(HttpRequest request) async {
    try {
      final rawBody = await utf8.decoder.bind(request).join();
      final body = rawBody.isEmpty ? null : rawBody;

      final headers = <String, String>{};
      request.headers.forEach((name, values) {
        headers[name] = values.join(", ");
      });

      final relayRequest =
          RelayMessage.request(
                id: (_nextRequestId++).toString(),
                method: request.method,
                path: request.uri.toString(),
                headers: headers,
                body: body,
              )
              as RelayRequest;

      final message = await _routeRequest(relayRequest);
      request.response.statusCode = message.status;
      // Skip hop-by-hop and length headers — dart:io sets them
      // automatically based on the actual response body written.
      const skipHeaders = {"content-length", "transfer-encoding", "connection"};
      message.headers.forEach((k, v) {
        if (!skipHeaders.contains(k.toLowerCase())) {
          request.response.headers.set(k, v);
        }
      });
      if (message.body != null) {
        // Write as UTF-8 bytes — dart:io defaults to Latin1 which
        // cannot represent the full range of characters in JSON payloads.
        request.response.add(utf8.encode(message.body!));
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.badGateway;
      request.response.add(utf8.encode("Debug server proxy error: $e"));
    } finally {
      await request.response.close();
    }
  }

  Future<RelayResponse> _routeRequest(RelayRequest request) async {
    final path = request.path.split("?").first;

    if (request.method == "GET" && path == "/project") {
      final projects = await _plugin.getProjects();
      final body = jsonEncode(projects.map((p) => p.toJson()).toList());
      return RelayResponse(
        id: request.id,
        status: 200,
        headers: {"content-type": "application/json"},
        body: body,
      );
    }

    if (request.method == "GET" && path == "/session") {
      String? worktree;
      for (final entry in request.headers.entries) {
        if (entry.key.toLowerCase() == "x-opencode-directory") {
          worktree = entry.value;
          break;
        }
      }
      if (worktree == null || worktree.isEmpty) {
        return RelayResponse(
          id: request.id,
          status: 400,
          headers: {},
          body: "missing x-opencode-directory header",
        );
      }
      final uri = Uri.parse(request.path);
      final start = uri.queryParameters["start"] != null ? int.tryParse(uri.queryParameters["start"]!) : null;
      final limit = uri.queryParameters["limit"] != null ? int.tryParse(uri.queryParameters["limit"]!) : null;
      final sessions = await _plugin.getSessions(worktree, start: start, limit: limit);
      final body = jsonEncode(sessions.map((s) => s.toJson()).toList());
      return RelayResponse(
        id: request.id,
        status: 200,
        headers: {"content-type": "application/json"},
        body: body,
      );
    }

    final sessionMsgPattern = RegExp(r"^/session/[^/]+/message$");
    if (request.method == "GET" && sessionMsgPattern.hasMatch(path)) {
      Log.v("[dbg] getting messages for session $path");
      final segments = path.split("/");
      final sessionId = segments[2];
      final messages = await _plugin.getSessionMessages(sessionId);
      final body = jsonEncode(messages.map((m) => m.toJson()).toList());
      return RelayResponse(
        id: request.id,
        status: 200,
        headers: {"content-type": "application/json"},
        body: body,
      );
    }

    // Fallback: explicit handlers not implemented for this route yet.
    return RelayResponse(
      id: request.id,
      status: 404,
      headers: {},
      body: "route not handled",
    );
  }

  Future<void> _handleSSE(HttpRequest request) async {
    final response = request.response;

    request.response.headers.set("content-type", "text/event-stream");
    request.response.headers.set("cache-control", "no-cache");
    request.response.headers.set("connection", "keep-alive");
    request.response.bufferOutput = false;

    try {
      response.write(": ok\n\n");
      await response.flush();

      _sseClients.add(response);

      _pluginEventsSub ??= _plugin.events.listen((event) {
        unawaited(_fanOutEvent(jsonEncode({"type": event.runtimeType.toString()})));
      });

      final disconnected = Completer<void>();
      unawaited(
        response.done.whenComplete(() {
          if (!disconnected.isCompleted) {
            disconnected.complete();
          }
        }),
      );

      await disconnected.future;
    } catch (_) {
    } finally {
      _removeSseClient(response);
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _fanOutEvent(String eventData) async {
    final clients = List<HttpResponse>.from(_sseClients);
    for (final client in clients) {
      try {
        client.write("data: $eventData\n\n");
        await client.flush();
      } catch (_) {
        _removeSseClient(client);
        try {
          await client.close();
        } catch (_) {}
      }
    }
  }

  void _removeSseClient(HttpResponse client) {
    _sseClients.remove(client);
    if (_sseClients.isEmpty) {
      final sub = _pluginEventsSub;
      _pluginEventsSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }
}
