import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";
import "dart:typed_data";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginAgentTool, PluginAgentToolHost, PluginAgentToolMcpCapability, pluginAgentToolDefinitions;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../../services/device_canvas_agent_tool_service.dart";
import "agent_tool_protocol.dart";
import "agent_tool_rendezvous_repository.dart";

const int _maxRequestBodyBytes = 8 * 1024;
const Duration _requestReadTimeout = Duration(seconds: 5);
const String _mcpProtocolVersion = "2025-06-18";
const Set<String> _supportedMcpProtocolVersions = {_mcpProtocolVersion};
const String _jsonRpcVersion = "2.0";

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
  final Map<String, _McpCapabilityBinding> _mcpCapabilities = {};
  var _nextCapabilityScope = 0;

  int? get boundPort => _server?.port;

  PluginAgentToolHost pluginHost({required String pluginId}) {
    if (pluginId.isEmpty) throw ArgumentError.value(pluginId, "pluginId", "must not be empty");
    return _BoundPluginAgentToolHost(
      server: this,
      pluginId: pluginId,
      scope: ++_nextCapabilityScope,
    );
  }

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
    for (final binding in _mcpCapabilities.values) {
      binding.markRevoked();
    }
    _mcpCapabilities.clear();
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
      if (request.uri.path == "/mcp") {
        await _handleMcp(request);
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

  Future<void> _handleMcp(HttpRequest request) async {
    if (request.headers.value("Origin") != null) {
      request.response.statusCode = HttpStatus.forbidden;
      return;
    }
    final token = _requestBearerToken(request);
    if (token == null) {
      request.response.statusCode = HttpStatus.unauthorized;
      return;
    }
    final binding = _mcpCapabilities[token];
    if (binding == null) {
      request.response.statusCode = HttpStatus.unauthorized;
      return;
    }

    Map<String, dynamic> body;
    try {
      body = await _readJsonBody(request);
    } on Object {
      await _sendMcpError(request.response, id: null, code: -32700, message: "Parse error");
      return;
    }
    final id = body["id"];
    final method = body["method"];
    if (body["jsonrpc"] != _jsonRpcVersion || method is! String) {
      await _sendMcpError(request.response, id: id, code: -32600, message: "Invalid Request");
      return;
    }
    if (method != "initialize" &&
        !_supportedMcpProtocolVersions.contains(request.headers.value("MCP-Protocol-Version"))) {
      request.response.statusCode = HttpStatus.badRequest;
      return;
    }

    if (method == "notifications/initialized" || method == "notifications/cancelled") {
      request.response.statusCode = HttpStatus.accepted;
      return;
    }

    final Object? result;
    switch (method) {
      case "initialize":
        final params = body["params"];
        final requestedVersion = params is Map ? params["protocolVersion"] : null;
        result = {
          "protocolVersion": requestedVersion is String && _supportedMcpProtocolVersions.contains(requestedVersion)
              ? requestedVersion
              : _mcpProtocolVersion,
          "capabilities": {
            "tools": {"listChanged": false},
          },
          "serverInfo": {"name": "sesori-device-canvas", "version": "1.0.0"},
          "instructions": "Use these tools only to list, claim, or release Device Canvas simulators for this session.",
        };
      case "ping":
        result = const <String, dynamic>{};
      case "tools/list":
        result = {
          "tools": [
            for (final definition in pluginAgentToolDefinitions)
              {
                "name": definition.tool.wireName,
                "description": definition.description,
                "inputSchema": definition.inputSchema,
              },
          ],
        };
      case "tools/call":
        final params = body["params"];
        final paramsMap = params is Map ? params.cast<String, dynamic>() : null;
        final name = paramsMap?["name"];
        final rawArguments = paramsMap?["arguments"];
        final tool = name is String ? PluginAgentTool.fromWireName(name) : null;
        if (tool == null || rawArguments != null && rawArguments is! Map) {
          await _sendMcpError(request.response, id: id, code: -32602, message: "Invalid params");
          return;
        }
        final arguments = rawArguments is Map ? rawArguments.cast<String, dynamic>() : const <String, dynamic>{};
        if (_mcpCapabilities[token] != binding || !binding.beginInvocation()) {
          request.response.statusCode = HttpStatus.unauthorized;
          return;
        }
        late final Map<String, dynamic> outcome;
        var isError = false;
        try {
          final backendSessionId = binding.backendSessionId;
          outcome = backendSessionId == null
              ? const DeviceCanvasAgentToolResponse.sessionUnavailable().toJson()
              : await _invoke(
                  pluginId: binding.pluginId,
                  backendSessionId: backendSessionId,
                  tool: tool,
                  arguments: arguments,
                );
        } on Object {
          Log.w("Device Canvas MCP tool invocation failed");
          outcome = const DeviceCanvasAgentToolResponse.internalError().toJson();
          isError = true;
        } finally {
          binding.endInvocation();
        }
        result = {
          "content": [
            {"type": "text", "text": jsonEncode(outcome)},
          ],
          "structuredContent": outcome,
          "isError": isError,
        };
      default:
        await _sendMcpError(request.response, id: id, code: -32601, message: "Method not found");
        return;
    }

    if (id == null) {
      request.response.statusCode = HttpStatus.accepted;
      return;
    }
    await _sendJson(
      request.response,
      statusCode: HttpStatus.ok,
      body: <String, dynamic>{"jsonrpc": _jsonRpcVersion, "id": id, "result": result},
    );
  }

  String? _requestBearerToken(HttpRequest request) {
    final authorization = request.headers.value(HttpHeaders.authorizationHeader);
    const prefix = "Bearer ";
    if (authorization == null || !authorization.startsWith(prefix)) return null;
    final token = authorization.substring(prefix.length);
    return token.isEmpty ? null : token;
  }

  Future<void> _sendMcpError(
    HttpResponse response, {
    required Object? id,
    required int code,
    required String message,
  }) => _sendJson(
    response,
    statusCode: HttpStatus.ok,
    body: <String, dynamic>{
      "jsonrpc": _jsonRpcVersion,
      "id": id,
      "error": {"code": code, "message": message},
    },
  );

  Future<Map<String, dynamic>> _invoke({
    required String pluginId,
    required String backendSessionId,
    required PluginAgentTool tool,
    required Map<String, dynamic> arguments,
  }) async {
    if (_server == null) return const DeviceCanvasAgentToolResponse.bridgeUnavailable().toJson();
    final DeviceCanvasAgentToolResult result;
    switch (tool) {
      case PluginAgentTool.listSimulators:
        if (arguments.isNotEmpty) return const DeviceCanvasAgentToolResponse.invalidRequest().toJson();
        result = await _service.listSimulators(pluginId: pluginId, backendSessionId: backendSessionId);
      case PluginAgentTool.claimSimulator:
      case PluginAgentTool.releaseSimulator:
        final deviceKey = arguments["deviceKey"];
        if (arguments.length != 1 || deviceKey is! String) {
          return const DeviceCanvasAgentToolResponse.invalidRequest().toJson();
        }
        result = tool == PluginAgentTool.claimSimulator
            ? await _service.claimSimulator(
                pluginId: pluginId,
                backendSessionId: backendSessionId,
                deviceKey: deviceKey,
              )
            : await _service.releaseSimulator(
                pluginId: pluginId,
                backendSessionId: backendSessionId,
                deviceKey: deviceKey,
              );
    }
    return _mapResult(result).toJson();
  }

  PluginAgentToolMcpCapability _provisionMcp({
    required String pluginId,
    required int scope,
    required String? backendSessionId,
  }) {
    final port = boundPort;
    if (port == null) throw StateError("Device Canvas agent-tool server is unavailable");
    late String token;
    do {
      token = generateDeviceCanvasAgentToolSecret();
    } while (_mcpCapabilities.containsKey(token));
    _mcpCapabilities[token] = _McpCapabilityBinding(
      pluginId: pluginId,
      scope: scope,
      backendSessionId: backendSessionId,
    );
    return PluginAgentToolMcpCapability(
      id: token,
      url: "http://127.0.0.1:$port/mcp",
      bearerToken: token,
    );
  }

  void _bindMcp({
    required String pluginId,
    required int scope,
    required PluginAgentToolMcpCapability capability,
    required String backendSessionId,
  }) {
    if (backendSessionId.isEmpty || backendSessionId.length > 2048) {
      throw ArgumentError.value(backendSessionId, "backendSessionId", "is invalid");
    }
    final current = _mcpCapabilities[capability.id];
    if (current == null || current.pluginId != pluginId || current.scope != scope) {
      throw StateError("Device Canvas MCP capability is not owned by this plugin generation");
    }
    if (current.backendSessionId != null) {
      throw StateError("Device Canvas MCP capability is already bound");
    }
    current.backendSessionId = backendSessionId;
  }

  Future<void> _revokeMcp({required int scope, required PluginAgentToolMcpCapability capability}) async {
    final current = _mcpCapabilities[capability.id];
    if (current?.scope != scope) return;
    _mcpCapabilities.remove(capability.id);
    await current!.revoke();
  }

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

class _McpCapabilityBinding({
  required final String pluginId,
  required final int scope,
  required String? backendSessionId,
}) {
  String? backendSessionId = backendSessionId;
  var _activeInvocations = 0;
  var _revoked = false;
  Completer<void>? _drained;

  bool beginInvocation() {
    if (_revoked) return false;
    _activeInvocations++;
    return true;
  }

  void endInvocation() {
    _activeInvocations--;
    if (_activeInvocations == 0) _drained?.complete();
  }

  void markRevoked() {
    _revoked = true;
  }

  Future<void> revoke() {
    markRevoked();
    if (_activeInvocations == 0) return Future<void>.value();
    return (_drained ??= Completer<void>()).future;
  }
}

class _BoundPluginAgentToolHost({
  required final DeviceCanvasAgentToolServer server,
  required final String pluginId,
  required final int scope,
}) implements PluginAgentToolHost {
  final Set<String> _issuedCapabilityIds = {};
  bool _disposed = false;
  int _activeNativeInvocations = 0;
  Completer<void>? _nativeInvocationsDrained;
  Future<void>? _disposeFuture;

  @override
  Future<Map<String, dynamic>> invoke({
    required String backendSessionId,
    required PluginAgentTool tool,
    required Map<String, dynamic> arguments,
  }) async {
    if (_disposed) return const DeviceCanvasAgentToolResponse.bridgeUnavailable().toJson();
    _activeNativeInvocations++;
    try {
      return await server._invoke(
        pluginId: pluginId,
        backendSessionId: backendSessionId,
        tool: tool,
        arguments: arguments,
      );
    } finally {
      _activeNativeInvocations--;
      if (_activeNativeInvocations == 0) _nativeInvocationsDrained?.complete();
    }
  }

  @override
  Future<PluginAgentToolMcpCapability> provisionMcp({required String? backendSessionId}) async {
    if (_disposed) throw StateError("Plugin agent-tool host is disposed");
    final capability = server._provisionMcp(
      pluginId: pluginId,
      scope: scope,
      backendSessionId: backendSessionId,
    );
    _issuedCapabilityIds.add(capability.id);
    return capability;
  }

  @override
  Future<void> bindMcp({
    required PluginAgentToolMcpCapability capability,
    required String backendSessionId,
  }) async {
    if (_disposed || !_issuedCapabilityIds.contains(capability.id)) {
      throw StateError("Device Canvas MCP capability is not owned by this plugin generation");
    }
    server._bindMcp(
      pluginId: pluginId,
      scope: scope,
      capability: capability,
      backendSessionId: backendSessionId,
    );
  }

  @override
  Future<void> revokeMcp({required PluginAgentToolMcpCapability capability}) async {
    _issuedCapabilityIds.remove(capability.id);
    await server._revokeMcp(scope: scope, capability: capability);
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    final capabilities = _issuedCapabilityIds.toList(growable: false);
    _issuedCapabilityIds.clear();
    final nativeDrain = _activeNativeInvocations == 0
        ? Future<void>.value()
        : (_nativeInvocationsDrained ??= Completer<void>()).future;
    await Future.wait([
      nativeDrain,
      for (final id in capabilities)
        server._revokeMcp(
          scope: scope,
          capability: PluginAgentToolMcpCapability(id: id, url: "", bearerToken: ""),
        ),
    ]);
  }
}
