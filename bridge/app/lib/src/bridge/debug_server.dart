import "dart:async";
import "dart:convert";
import "dart:io";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Console, Log;
import "package:sesori_shared/sesori_shared.dart";

import "../server/services/bridge_restart_service.dart";
import "routing/request_router.dart";

class DebugServer {
  final Stream<SesoriSseEvent> _localWireEvents;
  final RequestRouter _router;
  final FailureReporter _failureReporter;
  final BridgeRestartService _restartService;
  final Future<void> Function() _restartHandoff;
  final int port;
  final List<HttpResponse> _sseClients = [];
  // ignore: cancel_subscriptions - cancelled by the failure-isolated drain.
  final CompositeSubscription _compositeSubscription = CompositeSubscription();

  HttpServer? _server;
  // ignore: cancel_subscriptions - cancelled by the failure-isolated drain.
  StreamSubscription<void>? _localWireEventsSub;
  final Set<Future<void>> _inFlightRequests = <Future<void>>{};
  final Completer<void> _shutdownSignal = Completer<void>();
  Future<void>? _serverClose;
  Future<void>? _drainFuture;

  int _nextRequestId = 1;

  DebugServer({
    required Stream<SesoriSseEvent> localWireEvents,
    required RequestRouter router,
    required this.port,
    required FailureReporter failureReporter,
    required BridgeRestartService restartService,
    required Future<void> Function() restartHandoff,
  }) : _localWireEvents = localWireEvents,
       _router = router,
       _failureReporter = failureReporter,
       _restartService = restartService,
       _restartHandoff = restartHandoff;

  int? get boundPort => _server?.port;
  RequestRouter get router => _router;

  Future<void> start() async {
    if (_server != null) {
      return;
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;

    Console.message("Debug server listening on http://127.0.0.1:${server.port}");
    server
        .listen((request) {
          late final Future<void> operation;
          operation = _handleRequest(request).whenComplete(() => _inFlightRequests.remove(operation));
          _inFlightRequests.add(operation);
          unawaited(
            operation.catchError((Object error, StackTrace stackTrace) {
              Log.w("debug server request failed", error, stackTrace);
            }),
          );
        })
        .addTo(_compositeSubscription);
  }

  void beginShutdown() {
    if (!_shutdownSignal.isCompleted) _shutdownSignal.complete();
    final server = _server;
    _server = null;
    _serverClose ??= server?.close() ?? Future<void>.value();
  }

  Future<void> drain() => _drainFuture ??= _drain();

  Future<void> stop() {
    beginShutdown();
    return drain();
  }

  Future<void> _drain() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> attempt(FutureOr<void> Function() action) async {
      try {
        await action();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    final localWireEventsSub = _localWireEventsSub;
    _localWireEventsSub = null;
    final clients = List<HttpResponse>.from(_sseClients);
    _sseClients.clear();
    await Future.wait([
      attempt(_compositeSubscription.cancel),
      if (localWireEventsSub != null) attempt(localWireEventsSub.cancel),
      for (final client in clients) attempt(client.close),
      attempt(() => Future.wait(_inFlightRequests.toList(growable: false))),
      attempt(() async {
        await _serverClose;
      }),
    ]);
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path == "/global/event") {
      await _handleSSE(request);
      return;
    }

    await _handleHTTP(request);
  }

  Future<void> _handleHTTP(HttpRequest request) async {
    // Whether the request just routed armed a bridge restart. Consumed
    // synchronously right after routing so a concurrently-handled relay request
    // cannot steal the shared flag before this handler triggers the handoff.
    bool restartRequested = false;
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

      final message = await Future.any<RelayResponse?>([
        _router.route(relayRequest),
        _shutdownSignal.future.then<RelayResponse?>((_) => null),
      ]);
      if (message == null) return;
      // The RestartBridgeHandler arms the shared restart flag during routing;
      // consume it now, attributed to this request, mirroring the relay path.
      restartRequested = _restartService.consumeRestartRequest();
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

    // Drive the handoff only after the `{restarting:true}` reply has been
    // flushed and closed, so the debug client receives the response before this
    // process spawns its successor and shuts down. The handoff itself is owned
    // by the orchestrator and injected as an action, so a debug
    // `POST /global/restart` behaves identically to a phone-triggered restart.
    if (restartRequested) {
      // The response is already closed, so a handoff failure has nowhere to go —
      // log it instead of letting it escape this listen callback unhandled.
      try {
        await _restartHandoff();
      } on Object catch (error, stackTrace) {
        Log.w("debug server restart handoff failed: $error", error, stackTrace);
      }
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

      _localWireEventsSub ??= _localWireEvents
          .asyncMap((event) => _fanOutEvent(jsonEncode(event.toJson())))
          .listen(
            (_) {},
            onError: (Object e, StackTrace st) {
              Log.w("debug SSE stream error: $e");
              unawaited(
                _failureReporter.recordFailure(
                  error: e,
                  stackTrace: st,
                  uniqueIdentifier: "bridge.debug_server.sse",
                  fatal: false,
                  reason: "debug SSE stream failure",
                  information: const [],
                ),
              );
            },
          );

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
      final sub = _localWireEventsSub;
      _localWireEventsSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }
}
