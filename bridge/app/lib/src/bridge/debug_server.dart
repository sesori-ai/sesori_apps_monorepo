import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "metadata_service.dart";
import "persistence/daos/projects_dao.dart";
import "pr/gh_cli_service.dart";
import "pr/pr_sync_service.dart";
import "routing/request_router.dart";
import "sse/bridge_event_mapper.dart";

class DebugServer {
  final BridgePlugin _plugin;
  final RequestRouter _router;
  final BridgeEventMapper _mapper;
  final int port;
  HttpServer? _server;
  final List<HttpResponse> _sseClients = [];
  StreamSubscription<BridgeSseEvent>? _pluginEventsSub;

  int _nextRequestId = 1;

  DebugServer({
    required BridgePlugin plugin,
    required MetadataService metadataService,
    required ProjectsDao projectsDao,
    required this.port,
    required FailureReporter failureReporter,
  }) : _plugin = plugin,
       _router = (() {
         final database = projectsDao.attachedDatabase;
         final prSyncService = PrSyncService(
           ghCli: GhCliService(),
           prDao: database.pullRequestDao,
           sessionDao: database.sessionDao,
           processRunner: Process.run,
         );
         return RequestRouter(
           plugin: plugin,
           metadataService: metadataService,
           projectsDao: projectsDao,
           sessionDao: database.sessionDao,
           pullRequestDao: database.pullRequestDao,
           prSyncService: prSyncService,
         );
       })(),
       _mapper = BridgeEventMapper(plugin: plugin, failureReporter: failureReporter);

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
      } catch (e) {
        Log.d("stop: client close failed (ignored): $e");
      }
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

      final message = await _router.route(relayRequest);
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
        final mapped = _mapper.map(event);
        if (mapped != null) {
          unawaited(_fanOutEvent(jsonEncode(mapped.toJson())));
        }
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
    } catch (e) {
      Log.d("SSE handler: error during client lifecycle (ignored): $e");
    } finally {
      _removeSseClient(response);
      try {
        await response.close();
      } catch (e) {
        Log.d("SSE cleanup: response close failed (ignored): $e");
      }
    }
  }

  Future<void> _fanOutEvent(String eventData) async {
    final clients = List<HttpResponse>.from(_sseClients);
    for (final client in clients) {
      try {
        client.write("data: $eventData\n\n");
        await client.flush();
      } catch (e) {
        Log.d("fan-out: client write/flush failed, removing: $e");
        _removeSseClient(client);
        try {
          await client.close();
        } catch (e) {
          Log.d("fan-out cleanup: client close failed (ignored): $e");
        }
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
