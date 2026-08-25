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
}

DeviceCanvasSessionStatusResponse _status() => const DeviceCanvasSessionStatusResponse(
  bridgeId: "bridge-1",
  sessionId: "session-1",
  sessionAvailable: true,
  projectId: "project-1",
);
