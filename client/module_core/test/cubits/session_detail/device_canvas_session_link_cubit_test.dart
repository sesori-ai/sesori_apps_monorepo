import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/session_detail/device_canvas_session_link_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_detail/device_canvas_session_link_state.dart";
import "package:sesori_dart_core/src/repositories/models/device_canvas_result.dart";
import "package:sesori_dart_core/src/services/device_canvas_service.dart";
import "package:sesori_dart_core/src/services/registered_bridges_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockDeviceCanvasService() extends Mock implements DeviceCanvasService;

class _MockConnectionService() extends Mock implements ConnectionService;

class _MockRegisteredBridgesService() extends Mock implements RegisteredBridgesService;

const _config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token");
const _health = HealthResponse(healthy: true, version: "1.0.0", filesystemAccessDegraded: null);
const _connected = ConnectionStatus.connected(config: _config, health: _health);

void main() {
  late _MockDeviceCanvasService service;
  late _MockConnectionService connectionService;
  late _MockRegisteredBridgesService registeredBridgesService;
  late BehaviorSubject<ConnectionStatus> connection;
  late StreamController<SseEvent> events;
  late DeviceCanvasSessionLinkCubit cubit;

  setUp(() {
    service = _MockDeviceCanvasService();
    connectionService = _MockConnectionService();
    registeredBridgesService = _MockRegisteredBridgesService();
    connection = BehaviorSubject.seeded(_connected);
    events = StreamController<SseEvent>.broadcast();
    when(() => connectionService.status).thenAnswer((_) => connection.stream);
    when(() => connectionService.events).thenAnswer((_) => events.stream);
    when(() => registeredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);
  });

  tearDown(() async {
    await cubit.close();
    await connection.close();
    await events.close();
  });

  DeviceCanvasSessionLinkCubit createCubit({String? projectId}) => DeviceCanvasSessionLinkCubit(
    service: service,
    registeredBridgesService: registeredBridgesService,
    connectionService: connectionService,
    bridgeId: "bridge-1",
    projectId: projectId,
    sessionId: "session-1",
  );

  test("verifies an exact bridge and session match with a resolved project", () async {
    when(
      () => service.getSessionStatus(sessionId: "session-1"),
    ).thenAnswer((_) async => DeviceCanvasStatusSupported(status: _status()));

    cubit = createCubit();
    await _settle();

    expect(cubit.state, isA<DeviceCanvasSessionLinkVerified>());
    expect((cubit.state as DeviceCanvasSessionLinkVerified).status.bridgeId, "bridge-1");
  });

  test("rejects a status from another bridge or account", () async {
    when(
      () => service.getSessionStatus(sessionId: "session-1"),
    ).thenAnswer(
      (_) async => DeviceCanvasStatusSupported(
        status: _status(bridgeId: "bridge-2", projectId: "project-2"),
      ),
    );

    cubit = createCubit();
    await _settle();

    expect(cubit.state, isA<DeviceCanvasSessionLinkUnavailable>());
  });

  test("waits when another bridge is active but the target remains registered", () async {
    when(
      () => service.getSessionStatus(sessionId: "session-1"),
    ).thenAnswer((_) async => DeviceCanvasStatusSupported(status: _status(bridgeId: "bridge-2")));
    when(() => registeredBridgesService.getRegisteredBridges()).thenAnswer(
      (_) async => [
        BridgeSummary(
          id: "bridge-1",
          name: "Offline Mac",
          platform: "macos",
          addedAt: DateTime.fromMillisecondsSinceEpoch(1),
          lastSeenAt: DateTime.fromMillisecondsSinceEpoch(2),
        ),
      ],
    );

    cubit = createCubit();
    await _settle();

    expect(cubit.state, isA<DeviceCanvasSessionLinkWaiting>());
  });

  test("verifies after the registered target bridge becomes active", () async {
    var requests = 0;
    when(() => service.getSessionStatus(sessionId: "session-1")).thenAnswer((_) async {
      requests++;
      return DeviceCanvasStatusSupported(
        status: _status(bridgeId: requests == 1 ? "bridge-2" : "bridge-1"),
      );
    });
    when(() => registeredBridgesService.getRegisteredBridges()).thenAnswer(
      (_) async => [
        BridgeSummary(
          id: "bridge-1",
          name: "Target Mac",
          platform: "macos",
          addedAt: DateTime.fromMillisecondsSinceEpoch(1),
          lastSeenAt: DateTime.fromMillisecondsSinceEpoch(2),
        ),
      ],
    );
    cubit = createCubit();
    await _settle();
    expect(cubit.state, isA<DeviceCanvasSessionLinkWaiting>());

    connection.add(const ConnectionStatus.disconnected());
    connection.add(_connected);
    await _settle();

    expect(cubit.state, isA<DeviceCanvasSessionLinkVerified>());
    expect(requests, 2);
  });

  test("rejects a status for another or unavailable session", () async {
    when(() => service.getSessionStatus(sessionId: "session-1")).thenAnswer(
      (_) async => DeviceCanvasStatusSupported(status: _status(sessionId: "session-2")),
    );
    cubit = createCubit();
    await _settle();
    expect(cubit.state, isA<DeviceCanvasSessionLinkUnavailable>());
    await cubit.close();

    when(() => service.getSessionStatus(sessionId: "session-1")).thenAnswer(
      (_) async => DeviceCanvasStatusSupported(status: _status(sessionAvailable: false)),
    );
    cubit = createCubit();
    await _settle();
    expect(cubit.state, isA<DeviceCanvasSessionLinkUnavailable>());
  });

  test("rejects a status without a resolved project", () async {
    when(() => service.getSessionStatus(sessionId: "session-1")).thenAnswer(
      (_) async => DeviceCanvasStatusSupported(status: _status(projectId: null)),
    );

    cubit = createCubit();
    await _settle();

    expect(cubit.state, isA<DeviceCanvasSessionLinkUnavailable>());
  });

  test("rejects a status from another project", () async {
    when(() => service.getSessionStatus(sessionId: "session-1")).thenAnswer(
      (_) async => DeviceCanvasStatusSupported(status: _status(projectId: "project-2")),
    );

    cubit = createCubit(projectId: "project-1");
    await _settle();

    expect(cubit.state, isA<DeviceCanvasSessionLinkUnavailable>());
  });

  test("recovers after relay reconnection", () async {
    var requests = 0;
    when(() => service.getSessionStatus(sessionId: "session-1")).thenAnswer((_) async {
      requests++;
      return requests == 1
          ? DeviceCanvasStatusFailure(error: ApiError.generic())
          : DeviceCanvasStatusSupported(status: _status());
    });
    cubit = createCubit();
    await _settle();
    expect(cubit.state, isA<DeviceCanvasSessionLinkUnavailable>());

    connection.add(const ConnectionStatus.disconnected());
    await _settle();
    expect(cubit.state, isA<DeviceCanvasSessionLinkWaiting>());
    connection.add(_connected);
    await _settle();

    expect(cubit.state, isA<DeviceCanvasSessionLinkVerified>());
    expect(requests, 2);
  });

  test("ignores a verification response that arrives after disconnect", () async {
    final result = Completer<DeviceCanvasStatusResult>();
    when(
      () => service.getSessionStatus(sessionId: "session-1"),
    ).thenAnswer((_) => result.future);
    cubit = createCubit();
    await _settle();

    connection.add(const ConnectionStatus.disconnected());
    await _settle();
    result.complete(DeviceCanvasStatusSupported(status: _status()));
    await _settle();

    expect(cubit.state, isA<DeviceCanvasSessionLinkWaiting>());
  });

  test("starts a fresh verification when reconnect beats the stale response", () async {
    final staleResult = Completer<DeviceCanvasStatusResult>();
    var requests = 0;
    when(() => service.getSessionStatus(sessionId: "session-1")).thenAnswer((_) {
      requests++;
      return requests == 1 ? staleResult.future : Future.value(DeviceCanvasStatusSupported(status: _status()));
    });
    cubit = createCubit();
    await _settle();

    connection.add(const ConnectionStatus.disconnected());
    connection.add(_connected);
    await _settle();
    expect(cubit.state, isA<DeviceCanvasSessionLinkVerified>());
    expect(requests, 2);

    staleResult.complete(const DeviceCanvasStatusUnsupported());
    await _settle();
    expect(cubit.state, isA<DeviceCanvasSessionLinkVerified>());
  });

  test("re-verifies when a Device Canvas change arrives during verification", () async {
    final initialResult = Completer<DeviceCanvasStatusResult>();
    var requests = 0;
    when(() => service.getSessionStatus(sessionId: "session-1")).thenAnswer((_) {
      requests++;
      return requests == 1
          ? initialResult.future
          : Future.value(
              DeviceCanvasStatusSupported(status: _status(bridgeId: "bridge-2")),
            );
    });
    cubit = createCubit();
    await _settle();

    events.add(SseEvent(data: const SesoriSseEvent.deviceCanvasChanged()));
    initialResult.complete(DeviceCanvasStatusSupported(status: _status()));
    await _settle();
    await _settle();

    expect(requests, 2);
    expect(cubit.state, isA<DeviceCanvasSessionLinkUnavailable>());
  });
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

DeviceCanvasSessionStatusResponse _status({
  String bridgeId = "bridge-1",
  String sessionId = "session-1",
  bool sessionAvailable = true,
  String? projectId = "project-1",
}) => DeviceCanvasSessionStatusResponse(
  bridgeId: bridgeId,
  sessionId: sessionId,
  sessionAvailable: sessionAvailable,
  projectId: projectId,
  connection: DeviceCanvasClientConnectionStatus.connected,
);
