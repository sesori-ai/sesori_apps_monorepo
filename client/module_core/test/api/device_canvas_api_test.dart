import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/device_canvas_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockRelayHttpApiClient() extends Mock implements RelayHttpApiClient;

void main() {
  late _MockRelayHttpApiClient client;
  late DeviceCanvasApi api;

  setUp(() {
    client = _MockRelayHttpApiClient();
    api = DeviceCanvasApi(client: client);
  });

  test("POST status uses the canonical session id body", () async {
    when(
      () => client.post<DeviceCanvasSessionStatusResponse>(
        "/device-canvas/status",
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(_status()));

    await api.getSessionStatus(sessionId: "session-1");

    final body = verify(
      () => client.post<DeviceCanvasSessionStatusResponse>(
        "/device-canvas/status",
        body: captureAny(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).captured.single;
    expect(body, const {"sessionId": "session-1"});
  });

  test("POST claim carries explicit reassignment intent", () async {
    when(
      () => client.post<DeviceCanvasMutationResponse>(
        "/device-canvas/claim",
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        DeviceCanvasMutationResponse(outcome: DeviceCanvasMutationOutcome.reassigned, status: _status()),
      ),
    );

    await api.claim(
      expectedBridgeId: "bridge-1",
      sessionId: "session-1",
      deviceKey: "device-1",
      reassign: true,
      expectedOwnerSessionId: "session-2",
      expectedClaimRevision: 7,
    );

    final body = verify(
      () => client.post<DeviceCanvasMutationResponse>(
        "/device-canvas/claim",
        body: captureAny(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).captured.single;
    expect(body, const {
      "expectedBridgeId": "bridge-1",
      "sessionId": "session-1",
      "deviceKey": "device-1",
      "reassign": true,
      "expectedOwnerSessionId": "session-2",
      "expectedClaimRevision": 7,
    });
  });

  test("POST release carries session and device identity", () async {
    when(
      () => client.post<DeviceCanvasMutationResponse>(
        "/device-canvas/release",
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        DeviceCanvasMutationResponse(outcome: DeviceCanvasMutationOutcome.released, status: _status()),
      ),
    );

    await api.release(
      expectedBridgeId: "bridge-1",
      sessionId: "session-1",
      deviceKey: "device-1",
      expectedClaimRevision: 7,
    );

    final body = verify(
      () => client.post<DeviceCanvasMutationResponse>(
        "/device-canvas/release",
        body: captureAny(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).captured.single;
    expect(body, const {
      "expectedBridgeId": "bridge-1",
      "sessionId": "session-1",
      "deviceKey": "device-1",
      "expectedClaimRevision": 7,
    });
  });

  test("POST stream start uses the bounded timeout and typed request body", () async {
    final request = _startRequest();
    when(
      () => client.postWithTimeout<DeviceCanvasStreamStartResponse>(
        "/device-canvas/stream/start",
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
        timeout: const Duration(seconds: 20),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        const DeviceCanvasStreamStartResponse(
          outcome: DeviceCanvasStreamStartOutcome.unavailable,
          leaseId: null,
          expiresAt: null,
          answer: null,
          turn: null,
        ),
      ),
    );

    await api.startStream(request: request);

    final parser =
        verify(
              () => client.postWithTimeout<DeviceCanvasStreamStartResponse>(
                "/device-canvas/stream/start",
                body: request.toJson(),
                fromJson: captureAny(named: "fromJson"),
                timeout: const Duration(seconds: 20),
              ),
            ).captured.single
            as DeviceCanvasStreamStartResponse Function(Map<String, dynamic>);
    expect(
      () => parser(const <String, dynamic>{"outcome": "started"}),
      throwsFormatException,
    );
  });

  test("POST stream prepare uses the bounded timeout and typed request body", () async {
    const request = DeviceCanvasStreamPrepareRequest(
      expectedBridgeId: "bridge-1",
      sessionId: "session-1",
      deviceKey: "device-1",
      expectedClaimRevision: 7,
      operationId: "operation-1",
      leaseId: "lease-1",
      control: true,
    );
    when(
      () => client.postWithTimeout<DeviceCanvasStreamPrepareResponse>(
        "/device-canvas/stream/prepare",
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
        timeout: const Duration(seconds: 20),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        const DeviceCanvasStreamPrepareResponse(
          outcome: DeviceCanvasStreamPrepareOutcome.unavailable,
          leaseId: null,
          expiresAt: null,
          turn: null,
        ),
      ),
    );

    await api.prepareStream(request: request);

    final parser =
        verify(
              () => client.postWithTimeout<DeviceCanvasStreamPrepareResponse>(
                "/device-canvas/stream/prepare",
                body: request.toJson(),
                fromJson: captureAny(named: "fromJson"),
                timeout: const Duration(seconds: 20),
              ),
            ).captured.single
            as DeviceCanvasStreamPrepareResponse Function(Map<String, dynamic>);
    expect(
      () => parser(const <String, dynamic>{"outcome": "prepared"}),
      throwsFormatException,
    );
  });

  test("POST stream status uses the bounded timeout and typed request body", () async {
    const request = DeviceCanvasStreamStatusRequest(
      expectedBridgeId: "bridge-1",
      sessionId: "session-1",
      deviceKey: "device-1",
      expectedClaimRevision: 7,
      operationId: "operation-1",
    );
    when(
      () => client.postWithTimeout<DeviceCanvasStreamStatusResponse>(
        "/device-canvas/stream/status",
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
        timeout: const Duration(seconds: 20),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        const DeviceCanvasStreamStatusResponse(
          outcome: DeviceCanvasStreamStatusOutcome.inactive,
          leaseId: null,
          expiresAt: null,
          answer: null,
          turn: null,
          offerFingerprint: null,
        ),
      ),
    );

    await api.statusStream(request: request);

    verify(
      () => client.postWithTimeout<DeviceCanvasStreamStatusResponse>(
        "/device-canvas/stream/status",
        body: request.toJson(),
        fromJson: any(named: "fromJson"),
        timeout: const Duration(seconds: 20),
      ),
    ).called(1);
  });

  test("POST stream stop uses the bounded timeout and typed request body", () async {
    const request = DeviceCanvasStreamStopRequest(
      expectedBridgeId: "bridge-1",
      sessionId: "session-1",
      deviceKey: "device-1",
      expectedClaimRevision: 7,
      leaseId: "lease-1",
    );
    when(
      () => client.postWithTimeout<DeviceCanvasStreamStopResponse>(
        "/device-canvas/stream/stop",
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
        timeout: const Duration(seconds: 20),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        const DeviceCanvasStreamStopResponse(outcome: DeviceCanvasStreamStopOutcome.stopped),
      ),
    );

    await api.stopStream(request: request);

    verify(
      () => client.postWithTimeout<DeviceCanvasStreamStopResponse>(
        "/device-canvas/stream/stop",
        body: request.toJson(),
        fromJson: any(named: "fromJson"),
        timeout: const Duration(seconds: 20),
      ),
    ).called(1);
  });
}

DeviceCanvasSessionStatusResponse _status() => const DeviceCanvasSessionStatusResponse(
  bridgeId: "bridge-1",
  sessionId: "session-1",
  sessionAvailable: true,
  projectId: "project-1",
);

const _fingerprint =
    "sha-256 00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:10:21:32:43:54:65:76:87:98:A9:BA:CB:DC:ED:FE:0F";

DeviceCanvasStreamStartRequest _startRequest() => const DeviceCanvasStreamStartRequest(
  expectedBridgeId: "bridge-1",
  sessionId: "session-1",
  deviceKey: "device-1",
  expectedClaimRevision: 7,
  operationId: "operation-1",
  leaseId: null,
  control: true,
  offer: DeviceCanvasRtcDescription(
    type: DeviceCanvasRtcDescriptionType.offer,
    sdp: "v=0\na=fingerprint:$_fingerprint\n",
    fingerprint: _fingerprint,
  ),
);
