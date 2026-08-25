import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/post_device_canvas_claim_handler.dart";
import "package:sesori_bridge/src/bridge/routing/post_device_canvas_release_handler.dart";
import "package:sesori_bridge/src/bridge/routing/post_device_canvas_status_handler.dart";
import "package:sesori_bridge/src/bridge/routing/request_handler.dart";
import "package:sesori_bridge/src/bridge/services/device_canvas_client_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  late _DeviceCanvasClientService service;
  late PostDeviceCanvasStatusHandler statusHandler;
  late PostDeviceCanvasClaimHandler claimHandler;
  late PostDeviceCanvasReleaseHandler releaseHandler;

  setUp(() {
    service = _DeviceCanvasClientService();
    statusHandler = PostDeviceCanvasStatusHandler(service: service);
    claimHandler = PostDeviceCanvasClaimHandler(service: service);
    releaseHandler = PostDeviceCanvasReleaseHandler(service: service);
  });

  test("registers only the canonical POST routes", () {
    expect(statusHandler.canHandle(makeRequest("POST", "/device-canvas/status")), isTrue);
    expect(claimHandler.canHandle(makeRequest("POST", "/device-canvas/claim")), isTrue);
    expect(releaseHandler.canHandle(makeRequest("POST", "/device-canvas/release")), isTrue);
    expect(statusHandler.canHandle(makeRequest("GET", "/device-canvas/status")), isFalse);
    expect(claimHandler.canHandle(makeRequest("POST", "/device-canvas/release")), isFalse);
  });

  test("rejects missing, malformed, and unbounded bodies", () async {
    final missing = await _route(
      handler: statusHandler,
      method: "POST",
      path: "/device-canvas/status",
      body: null,
    );
    final malformed = await _route(
      handler: claimHandler,
      method: "POST",
      path: "/device-canvas/claim",
      body: "not-json",
    );
    final unbounded = await _route(
      handler: releaseHandler,
      method: "POST",
      path: "/device-canvas/release",
      body: jsonEncode({
        "expectedBridgeId": "bridge-1",
        "sessionId": "session-1",
        "deviceKey": List.filled(maxDeviceCanvasClientDeviceKeyLength + 1, "x").join(),
        "expectedClaimRevision": 1,
      }),
    );
    final unfencedReassignment = await _route(
      handler: claimHandler,
      method: "POST",
      path: "/device-canvas/claim",
      body: jsonEncode(const {
        "expectedBridgeId": "bridge-1",
        "sessionId": "session-1",
        "deviceKey": "device-1",
        "reassign": true,
      }),
    );

    expect(missing.status, 400);
    expect(malformed.status, 400);
    expect(unbounded.status, 400);
    expect(unfencedReassignment.status, 400);
  });

  test("decodes requests and serializes typed responses", () async {
    final status = await _route(
      handler: statusHandler,
      method: "POST",
      path: "/device-canvas/status",
      body: jsonEncode(const {"sessionId": "session-1"}),
    );
    final claim = await _route(
      handler: claimHandler,
      method: "POST",
      path: "/device-canvas/claim",
      body: jsonEncode(const {
        "expectedBridgeId": "bridge-1",
        "sessionId": "session-1",
        "deviceKey": "device-1",
        "reassign": true,
        "expectedOwnerSessionId": "session-2",
        "expectedClaimRevision": 7,
      }),
    );
    final release = await _route(
      handler: releaseHandler,
      method: "POST",
      path: "/device-canvas/release",
      body: jsonEncode(const {
        "expectedBridgeId": "bridge-1",
        "sessionId": "session-1",
        "deviceKey": "device-1",
        "expectedClaimRevision": 7,
      }),
    );

    expect(status.status, 200);
    expect(jsonDecode(status.body!) as Map<String, dynamic>, containsPair("bridgeId", "bridge-1"));
    expect(service.claimRequest?.reassign, isTrue);
    expect(service.claimRequest?.expectedBridgeId, "bridge-1");
    expect(service.claimRequest?.expectedOwnerSessionId, "session-2");
    expect(service.claimRequest?.expectedClaimRevision, 7);
    expect(claim.status, 200);
    expect(service.releaseRequest?.deviceKey, "device-1");
    expect(service.releaseRequest?.expectedBridgeId, "bridge-1");
    expect(service.releaseRequest?.expectedClaimRevision, 7);
    expect(release.status, 200);
  });

  test("maps unavailable bridge identity to 503", () async {
    service.unavailable = true;

    final response = await _route(
      handler: statusHandler,
      method: "POST",
      path: "/device-canvas/status",
      body: jsonEncode(const {"sessionId": "session-1"}),
    );

    expect(response.status, 503);
  });
}

Future<RelayResponse> _route({
  required RequestHandlerBase handler,
  required String method,
  required String path,
  required String? body,
}) {
  final request = makeRequest(method, path, body: body);
  final params = handler.extractParams(request);
  return handler.handleInternal(
    request,
    pathParams: params.pathParams,
    queryParams: params.queryParams,
    fragment: params.fragment,
  );
}

class _DeviceCanvasClientService() implements DeviceCanvasClientService {
  bool unavailable = false;
  DeviceCanvasClaimRequest? claimRequest;
  DeviceCanvasReleaseRequest? releaseRequest;

  @override
  Future<DeviceCanvasSessionStatusResponse> status({required String sessionId}) async {
    if (unavailable) throw const DeviceCanvasClientBridgeUnavailable();
    return _status(sessionId);
  }

  @override
  Future<DeviceCanvasMutationResponse> claim({required DeviceCanvasClaimRequest request}) async {
    if (unavailable) throw const DeviceCanvasClientBridgeUnavailable();
    claimRequest = request;
    return DeviceCanvasMutationResponse(
      outcome: DeviceCanvasMutationOutcome.claimed,
      status: _status(request.sessionId),
    );
  }

  @override
  Future<DeviceCanvasMutationResponse> release({required DeviceCanvasReleaseRequest request}) async {
    if (unavailable) throw const DeviceCanvasClientBridgeUnavailable();
    releaseRequest = request;
    return DeviceCanvasMutationResponse(
      outcome: DeviceCanvasMutationOutcome.released,
      status: _status(request.sessionId),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError("Unexpected call: ${invocation.memberName}");
}

DeviceCanvasSessionStatusResponse _status(String sessionId) => DeviceCanvasSessionStatusResponse(
  bridgeId: "bridge-1",
  sessionId: sessionId,
  sessionAvailable: true,
  projectId: "project-1",
  connection: DeviceCanvasClientConnectionStatus.connected,
);
