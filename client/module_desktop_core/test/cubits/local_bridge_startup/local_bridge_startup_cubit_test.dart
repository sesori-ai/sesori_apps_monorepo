import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../support/bridge_id_storage.dart";

void main() {
  late BehaviorSubject<BridgeProcessState> processStates;
  late BehaviorSubject<ConnectionStatus> statuses;
  late BridgeStatusTracker statusTracker;
  late _MockBridgeProcessService processService;
  late _MockConnectionService connectionService;
  late List<LocalBridgeStartupCubit> cubits;

  setUp(() async {
    processStates = BehaviorSubject.seeded(const BridgeProcessStopped());
    statuses = BehaviorSubject.seeded(const ConnectionStatus.disconnected());
    processService = _MockBridgeProcessService();
    when(() => processService.states).thenAnswer((_) => processStates.stream);
    when(() => processService.state).thenAnswer((_) => processStates.value);
    connectionService = _MockConnectionService();
    when(() => connectionService.status).thenAnswer((_) => statuses.stream);
    when(() => connectionService.currentStatus).thenAnswer((_) => statuses.value);
    statusTracker = BridgeStatusTracker(
      bridgeIdStorage: MemoryBridgeIdStorage(
        initialRegistration: const BridgeRegistrationRecord(bridgeId: _localId, accountId: "account-a"),
      ),
    );
    await statusTracker.initialize();
    cubits = [];
  });

  tearDown(() async {
    for (final cubit in cubits) {
      await cubit.close();
    }
    await statusTracker.dispose();
    await processStates.close();
    await statuses.close();
  });

  LocalBridgeStartupCubit create() {
    final cubit = LocalBridgeStartupCubit(
      processService: processService,
      statusTracker: statusTracker,
      connectionService: connectionService,
    );
    cubits.add(cubit);
    return cubit;
  }

  Future<void> process(BridgeProcessState state) async {
    processStates.add(state);
    await pumpEventQueue();
  }

  Future<void> connection(ConnectionStatus status) async {
    statuses.add(status);
    await pumpEventQueue();
  }

  test("a cold start's launch stays loading until the app reaches this computer", () async {
    final cubit = create();
    expect(cubit.state, LocalBridgeStartupState.settled);

    await process(const BridgeProcessStarting());
    expect(cubit.state, LocalBridgeStartupState.starting);
    await connection(_bridgeOffline(targetId: _localId));
    // Running is published at spawn, long before the bridge reaches the relay.
    await process(const BridgeProcessRunning(pid: 7));
    expect(cubit.state, LocalBridgeStartupState.starting);
    // The relay's bridge-online notice drives a reconnect before Connected.
    await connection(_reconnecting(targetId: _localId));
    expect(cubit.state, LocalBridgeStartupState.starting);

    await connection(_connected(targetId: _localId));
    expect(cubit.state, LocalBridgeStartupState.settled);
  });

  test("a launch already under way when the app opens is still loading", () async {
    for (final processState in const [BridgeProcessStarting(), BridgeProcessRunning(pid: 7)]) {
      processStates.add(processState);
      statuses.add(_bridgeOffline(targetId: _localId));
      expect(create().state, LocalBridgeStartupState.starting, reason: "$processState");
    }
  });

  test("a bridge the app already reaches when it opens is not launching", () async {
    processStates.add(const BridgeProcessRunning(pid: 7));
    statuses.add(_connected(targetId: _localId));
    expect(create().state, LocalBridgeStartupState.settled);
  });

  test("a start that fails or stops shows the bridge as offline", () async {
    for (final failure in const <BridgeProcessState>[
      BridgeProcessStartFailed(message: "Reinstall Sesori"),
      BridgeProcessCrashRetryScheduled(exitCode: 1, crashCount: 1, delay: Duration(seconds: 1)),
      BridgeProcessCrashGiveUp(exitCode: 1, crashCount: 6),
      BridgeProcessContention(),
      BridgeProcessLoginRequired(),
      BridgeProcessStopping(pid: 7),
      BridgeProcessStopped(),
    ]) {
      processStates.add(const BridgeProcessStopped());
      statuses.add(_bridgeOffline(targetId: _localId));
      final cubit = create();
      await process(const BridgeProcessStarting());
      await process(const BridgeProcessRunning(pid: 7));
      expect(cubit.state, LocalBridgeStartupState.starting, reason: "$failure");

      await process(failure);
      expect(cubit.state, LocalBridgeStartupState.settled, reason: "$failure");
    }
  });

  test("a running bridge lost mid-session stays offline, through its crash restart", () async {
    final cubit = create();
    await process(const BridgeProcessStarting());
    await process(const BridgeProcessRunning(pid: 7));
    await connection(_connected(targetId: _localId));

    await connection(_bridgeOffline(targetId: _localId));
    expect(cubit.state, LocalBridgeStartupState.settled);

    await process(const BridgeProcessCrashRetryScheduled(exitCode: 1, crashCount: 1, delay: Duration(seconds: 1)));
    await process(const BridgeProcessStarting());
    await process(const BridgeProcessRunning(pid: 8));
    expect(cubit.state, LocalBridgeStartupState.settled);
  });

  test("starting the bridge again after a stop is a launch", () async {
    final cubit = create();
    await connection(_bridgeOffline(targetId: _localId));
    await process(const BridgeProcessStopped());
    expect(cubit.state, LocalBridgeStartupState.settled);

    await process(const BridgeProcessStarting());
    expect(cubit.state, LocalBridgeStartupState.starting);
  });

  test("another computer's offline bridge is never this computer's launch", () async {
    final cubit = create();
    await process(const BridgeProcessStarting());
    await connection(_bridgeOffline(targetId: _remoteId));
    expect(cubit.state, LocalBridgeStartupState.settled);

    // Reaching the other computer does not end this computer's launch.
    await connection(_connected(targetId: _remoteId));
    await connection(_reconnecting(targetId: _localId));
    expect(cubit.state, LocalBridgeStartupState.starting);
  });

  test("a connection without a target yet counts as this computer", () async {
    final cubit = create();
    await process(const BridgeProcessStarting());
    await connection(_reconnecting(targetId: null));
    expect(cubit.state, LocalBridgeStartupState.starting);
  });

  test("a fresh install follows the id its bridge registers", () async {
    await statusTracker.dispose();
    statusTracker = BridgeStatusTracker(bridgeIdStorage: MemoryBridgeIdStorage());
    await statusTracker.initialize();
    final cubit = create();
    await process(const BridgeProcessStarting());
    // The relay routed the unpinned connection to another computer first.
    await connection(_connected(targetId: _remoteId));
    expect(cubit.state, LocalBridgeStartupState.settled);

    statusTracker.handleRegistered(bridgeId: _localId, accountId: "account-a");
    await connection(_bridgeOffline(targetId: _localId));
    expect(cubit.state, LocalBridgeStartupState.starting);
    await connection(_connected(targetId: _localId));
    expect(cubit.state, LocalBridgeStartupState.settled);
  });
}

const _localId = "bridge-local";
const _remoteId = "bridge-remote";
const _health = HealthResponse(healthy: true, version: "1.9.2", filesystemAccessDegraded: false);

ServerConnectionConfig _config({required String? targetId}) =>
    ServerConnectionConfig(relayHost: "relay", authToken: "token", bridgeId: targetId);

ConnectionStatus _connected({required String targetId}) => ConnectionStatus.connected(
  config: _config(targetId: targetId),
  health: _health,
);

ConnectionStatus _bridgeOffline({required String targetId}) => ConnectionStatus.bridgeOffline(
  config: _config(targetId: targetId),
  health: _health,
);

ConnectionStatus _reconnecting({required String? targetId}) =>
    ConnectionStatus.reconnecting(config: _config(targetId: targetId));

class _MockBridgeProcessService() extends Mock implements BridgeProcessService;

class _MockConnectionService() extends Mock implements ConnectionService;
