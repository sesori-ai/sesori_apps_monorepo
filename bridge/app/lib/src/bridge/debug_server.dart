import "dart:async";
import "dart:convert";
import "dart:io";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../listeners/command_dispatch_outcome_listener.dart";
import "../listeners/plugin_command_timeline_listener.dart";
import "../server/services/bridge_restart_service.dart";
import "repositories/session_repository.dart";
import "routing/request_router.dart";
import "sse/bridge_event_mapper.dart";
import "sse/command_timeline_sse_mapper.dart";

class DebugServer {
  static const CommandTimelineSseMapper _commandTimelineSseMapper = CommandTimelineSseMapper();

  final RequestRouter _router;
  final BridgeEventMapper _mapper;
  final SessionRepository _sessionRepository;
  final PluginCommandTimelineListener _pluginCommandTimelineListener;
  final CommandDispatchOutcomeListener _commandDispatchOutcomeListener;
  final FailureReporter _failureReporter;
  final BridgeRestartService _restartService;
  final Future<void> Function() _restartHandoff;
  final int port;
  final List<HttpResponse> _sseClients = [];
  final CompositeSubscription _compositeSubscription = CompositeSubscription();

  HttpServer? _server;
  StreamSubscription<void>? _pluginTimelineSub;
  StreamSubscription<void>? _dispatchTimelineSub;

  int _nextRequestId = 1;

  DebugServer({
    required RequestRouter router,
    required this.port,
    required FailureReporter failureReporter,
    required SessionRepository sessionRepository,
    required PluginCommandTimelineListener pluginCommandTimelineListener,
    required CommandDispatchOutcomeListener commandDispatchOutcomeListener,
    required BridgeRestartService restartService,
    required Future<void> Function() restartHandoff,
  }) : _router = router,
       _failureReporter = failureReporter,
       _sessionRepository = sessionRepository,
       _pluginCommandTimelineListener = pluginCommandTimelineListener,
       _commandDispatchOutcomeListener = commandDispatchOutcomeListener,
       _restartService = restartService,
       _restartHandoff = restartHandoff,
       _mapper = BridgeEventMapper(failureReporter: failureReporter);

  int? get boundPort => _server?.port;
  RequestRouter get router => _router;

  Future<void> start() async {
    if (_server != null) {
      return;
    }

    await _pluginCommandTimelineListener.start();
    await _commandDispatchOutcomeListener.start();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;

    Console.message("Debug server listening on http://127.0.0.1:${server.port}");
    server.listen(_handleRequest).addTo(_compositeSubscription);
  }

  Future<void> stop() async {
    await _compositeSubscription.cancel();
    await _pluginTimelineSub?.cancel();
    _pluginTimelineSub = null;
    await _dispatchTimelineSub?.cancel();
    _dispatchTimelineSub = null;
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

      final message = await _router.route(relayRequest);
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

      _pluginTimelineSub ??= _pluginCommandTimelineListener.outputs
          .asyncMap<List<SesoriSseEvent>>(_mapPluginTimelineOutput)
          .asyncMap(_fanOutEvents)
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
      _dispatchTimelineSub ??= _commandDispatchOutcomeListener.mutations
          .map<List<SesoriSseEvent>>(_commandTimelineSseMapper.mapAll)
          .asyncMap(_fanOutEvents)
          .listen(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              Log.w("debug accepted command SSE stream error", error, stackTrace);
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

  Future<SesoriSseEvent?> _buildProjectsSummary() async {
    try {
      return _mapper.buildProjectsSummaryEvent(
        projects: await _sessionRepository.getProjectActivitySummaries(),
      );
    } on Object catch (error, stackTrace) {
      Log.w("debug SSE projects-summary rebuild failed", error, stackTrace);
      unawaited(
        _failureReporter
            .recordFailure(
              error: error,
              stackTrace: stackTrace,
              uniqueIdentifier: "bridge.debug_server.projects_summary",
              fatal: false,
              reason: "debug SSE projects-summary rebuild failed",
              information: const [],
            )
            .catchError((Object reportError, StackTrace reportStackTrace) {
              Log.w(
                "debug SSE projects-summary failure report failed",
                reportError,
                reportStackTrace,
              );
            }),
      );
      return null;
    }
  }

  Future<void> _fanOutMappedEvent({required SesoriSseEvent? mapped}) async {
    if (mapped == null) {
      return;
    }
    await _fanOutEvent(jsonEncode(mapped.toJson()));
  }

  Future<List<SesoriSseEvent>> _mapPluginTimelineOutput(PluginCommandTimelineOutput output) async {
    return switch (output) {
      PluginCommandTimelineCanonical(:final mutations) => _commandTimelineSseMapper.mapAll(mutations),
      PluginCommandTimelinePassthrough(:final event) => switch (event) {
        BridgeSseProjectUpdated() => [await _buildProjectsSummary()].nonNulls.toList(growable: false),
        _ => [_mapper.map(event)].nonNulls.toList(growable: false),
      },
    };
  }

  Future<void> _fanOutEvents(List<SesoriSseEvent> events) async {
    for (final event in events) {
      await _fanOutMappedEvent(mapped: event);
    }
  }

  void _removeSseClient(HttpResponse client) {
    _sseClients.remove(client);
    if (_sseClients.isEmpty) {
      final sub = _pluginTimelineSub;
      _pluginTimelineSub = null;
      if (sub != null) unawaited(sub.cancel());
      final dispatchSub = _dispatchTimelineSub;
      _dispatchTimelineSub = null;
      if (dispatchSub != null) unawaited(dispatchSub.cancel());
    }
  }
}
