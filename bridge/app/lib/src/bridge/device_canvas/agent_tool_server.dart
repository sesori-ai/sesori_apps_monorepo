import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";
import "dart:typed_data";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../../services/device_canvas_agent_tool_service.dart";
import "agent_tool_protocol.dart";
import "agent_tool_rendezvous_repository.dart";

const int _maxRequestBodyBytes = 8 * 1024;
const Duration _requestReadTimeout = Duration(seconds: 5);

String generateDeviceCanvasAgentToolSecret({Random? random}) {
  final secureRandom = random ?? Random.secure();
  return List<int>.generate(
    32,
    (_) => secureRandom.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
}

class DeviceCanvasAgentToolServer({
  required final DeviceCanvasAgentToolService _service,
  required final DeviceCanvasAgentToolRendezvousRepository _rendezvousRepository,
  required final String _pluginId,
  required final String _bootstrapSecret,
}) {
  final PendingOperations _pendingRequests = PendingOperations();
  HttpServer? _server;
  Future<void>? _serverClose;
  Future<void>? _drainFuture;
  String? _bearerToken;

  int? get boundPort => _server?.port;

  Future<void> start() async {
    if (_server != null) return;
    await _rendezvousRepository.remove();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      await _rendezvousRepository.publish(
        DeviceCanvasAgentToolRendezvous(protocolVersion: deviceCanvasAgentToolProtocolVersion, port: server.port),
      );
    } on Object {
      await server.close(force: true);
      await _rendezvousRepository.remove();
      rethrow;
    }
    _server = server;
    server.listen((request) {
      late final Future<void> operation;
      operation = _pendingRequests.track(operation: _handleRequest(request));
      unawaited(
        operation.catchError((Object error, StackTrace stackTrace) {
          Log.w("Device Canvas agent-tool request failed", error, stackTrace);
        }),
      );
    });
  }

  void beginShutdown() {
    final server = _server;
    _server = null;
    _bearerToken = null;
    _serverClose ??= server?.close(force: true) ?? Future<void>.value();
  }

  Future<void> drain() => _drainFuture ??= _drain();

  Future<void> dispose() {
    beginShutdown();
    return drain();
  }

  Future<void> _drain() async {
    beginShutdown();
    await _serverClose;
    await _pendingRequests.drain();
    await _rendezvousRepository.remove();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method != "POST") {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      if (request.uri.path == "/register") {
        await _handleRegistration(request);
        return;
      }
      if (!_isAuthorized(request, _bearerToken)) {
        request.response.statusCode = HttpStatus.unauthorized;
        return;
      }

      final result = switch (request.uri.path) {
        "/list" => await _list(request),
        "/claim" => await _claim(request),
        "/release" => await _release(request),
        _ => null,
      };
      if (result == null) {
        request.response.statusCode = HttpStatus.notFound;
        return;
      }
      await _sendJson(request.response, statusCode: HttpStatus.ok, body: result.toJson());
    } on TimeoutException {
      await _sendJson(
        request.response,
        statusCode: HttpStatus.requestTimeout,
        body: const DeviceCanvasAgentToolResponse.invalidRequest().toJson(),
      );
    } on _InvalidAgentToolRequest {
      await _sendJson(
        request.response,
        statusCode: HttpStatus.badRequest,
        body: const DeviceCanvasAgentToolResponse.invalidRequest().toJson(),
      );
    } on Object catch (error, stackTrace) {
      Log.w("Device Canvas agent-tool operation failed", error, stackTrace);
      await _sendJson(
        request.response,
        statusCode: HttpStatus.internalServerError,
        body: const DeviceCanvasAgentToolResponse.internalError().toJson(),
      );
    } finally {
      try {
        await request.response.close();
      } on Object catch (error, stackTrace) {
        Log.w("Device Canvas agent-tool response close failed", error, stackTrace);
      }
    }
  }

  Future<void> _handleRegistration(HttpRequest request) async {
    if (!_isAuthorized(request, _bootstrapSecret)) {
      request.response.statusCode = HttpStatus.unauthorized;
      return;
    }
    final token = generateDeviceCanvasAgentToolSecret();
    _bearerToken = token;
    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: DeviceCanvasAgentToolRegistrationResponse(bearerToken: token).toJson(),
    );
  }

  bool _isAuthorized(HttpRequest request, String? secret) =>
      secret != null && request.headers.value(HttpHeaders.authorizationHeader) == "Bearer $secret";

  Future<DeviceCanvasAgentToolResponse> _list(HttpRequest request) async {
    final body = DeviceCanvasAgentToolListRequest.fromJson(await _readJsonBody(request));
    if (!body.isValid) throw const _InvalidAgentToolRequest();
    return _mapResult(
      await _service.listSimulators(pluginId: _pluginId, backendSessionId: body.backendSessionId),
    );
  }

  Future<DeviceCanvasAgentToolResponse> _claim(HttpRequest request) async {
    final body = DeviceCanvasAgentToolMutationRequest.fromJson(await _readJsonBody(request));
    if (!body.isValid) throw const _InvalidAgentToolRequest();
    return _mapResult(
      await _service.claimSimulator(
        pluginId: _pluginId,
        backendSessionId: body.backendSessionId,
        deviceKey: body.deviceKey,
      ),
    );
  }

  Future<DeviceCanvasAgentToolResponse> _release(HttpRequest request) async {
    final body = DeviceCanvasAgentToolMutationRequest.fromJson(await _readJsonBody(request));
    if (!body.isValid) throw const _InvalidAgentToolRequest();
    return _mapResult(
      await _service.releaseSimulator(
        pluginId: _pluginId,
        backendSessionId: body.backendSessionId,
        deviceKey: body.deviceKey,
      ),
    );
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    if (request.contentLength > _maxRequestBodyBytes) throw const _InvalidAgentToolRequest();
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in request.timeout(_requestReadTimeout)) {
      bytes.add(chunk);
      if (bytes.length > _maxRequestBodyBytes) throw const _InvalidAgentToolRequest();
    }
    try {
      return jsonDecodeMap(utf8.decode(bytes.takeBytes()));
    } on Object {
      throw const _InvalidAgentToolRequest();
    }
  }

  DeviceCanvasAgentToolResponse _mapResult(DeviceCanvasAgentToolResult result) {
    return switch (result) {
      DeviceCanvasAgentSimulatorsListed(:final devices, :final truncated) => DeviceCanvasAgentToolResponse.listed(
        devices: devices.map(_mapDevice).toList(growable: false),
        truncated: truncated,
      ),
      DeviceCanvasAgentSimulatorClaimed(:final deviceKey) => DeviceCanvasAgentToolResponse.claimed(
        deviceKey: deviceKey,
      ),
      DeviceCanvasAgentSimulatorAlreadyOwned(:final deviceKey) => DeviceCanvasAgentToolResponse.alreadyOwned(
        deviceKey: deviceKey,
      ),
      DeviceCanvasAgentSimulatorReleased(:final deviceKey) => DeviceCanvasAgentToolResponse.released(
        deviceKey: deviceKey,
      ),
      DeviceCanvasAgentSimulatorAlreadyReleased(:final deviceKey) => DeviceCanvasAgentToolResponse.alreadyReleased(
        deviceKey: deviceKey,
      ),
      DeviceCanvasAgentSimulatorConflict(:final deviceKey) => DeviceCanvasAgentToolResponse.conflict(
        deviceKey: deviceKey,
      ),
      DeviceCanvasAgentSimulatorUnavailable(:final deviceKey) => DeviceCanvasAgentToolResponse.deviceUnavailable(
        deviceKey: deviceKey,
      ),
      DeviceCanvasAgentSessionUnavailable() => const DeviceCanvasAgentToolResponse.sessionUnavailable(),
      DeviceCanvasAgentIntegrationUnavailable() => const DeviceCanvasAgentToolResponse.integrationUnavailable(),
      DeviceCanvasAgentBridgeUnavailable() => const DeviceCanvasAgentToolResponse.bridgeUnavailable(),
    };
  }

  DeviceCanvasAgentToolDevice _mapDevice(DeviceCanvasAgentDevice device) {
    return DeviceCanvasAgentToolDevice(
      deviceKey: device.deviceKey,
      platform: device.platform.name,
      displayName: device.displayName,
      runtimeDescription: device.runtimeDescription,
      modelDescription: device.modelDescription,
      ownership: switch (device.ownership) {
        DeviceCanvasAgentDeviceOwnership.unclaimed => DeviceCanvasAgentToolDeviceOwnership.unclaimed,
        DeviceCanvasAgentDeviceOwnership.currentSession => DeviceCanvasAgentToolDeviceOwnership.currentSession,
        DeviceCanvasAgentDeviceOwnership.anotherSession => DeviceCanvasAgentToolDeviceOwnership.anotherSession,
      },
    );
  }

  Future<void> _sendJson(
    HttpResponse response, {
    required int statusCode,
    required Map<String, dynamic> body,
  }) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.add(utf8.encode(jsonEncode(body)));
  }
}

class const _InvalidAgentToolRequest() implements Exception;
