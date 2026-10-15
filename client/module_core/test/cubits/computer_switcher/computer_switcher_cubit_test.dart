import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class _MockSelectedComputerService() extends Mock implements SelectedComputerService;

class _Locality({required final BehaviorSubject<String?> _localId}) implements ActiveBridgeLocality {
  @override
  String? get localBridgeId => _localId.value;

  @override
  Stream<String?> get localBridgeIdStream => _localId.stream;

  @override
  bool isLocalBridge({required String bridgeId}) => bridgeId == _localId.value;
}

ConnectionStatus _reconnectingTo({required String? bridgeId}) => ConnectionStatus.reconnecting(
  config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "t", bridgeId: bridgeId),
);

void main() {
  late MockRegisteredBridgesService registeredBridges;
  late MockConnectionService connection;
  late BehaviorSubject<ConnectionStatus> status;
  late _MockSelectedComputerService selectedComputer;
  late BehaviorSubject<String?> localId;
  String? storedTarget;

  setUp(() {
    registeredBridges = MockRegisteredBridgesService();
    connection = MockConnectionService();
    status = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
    selectedComputer = _MockSelectedComputerService();
    localId = BehaviorSubject<String?>.seeded(null);
    storedTarget = null;
    when(() => connection.status).thenAnswer((_) => status.stream);
    when(() => connection.currentStatus).thenAnswer((_) => status.value);
    when(selectedComputer.targetBridgeId).thenAnswer((_) async => status.value.targetBridgeId ?? storedTarget);
  });

  tearDown(() async {
    await status.close();
    await localId.close();
  });

  ComputerSwitcherCubit build() {
    final cubit = ComputerSwitcherCubit(
      registeredBridgesService: registeredBridges,
      connectionService: connection,
      selectedComputerService: selectedComputer,
      activeBridgeLocality: _Locality(localId: localId),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test("starts from the held list and the live target", () {
    final computers = [testBridgeSummary(id: "a"), testBridgeSummary(id: "b")];
    registeredBridges.emitBridges(bridges: computers);
    status.add(_reconnectingTo(bridgeId: "b"));

    final cubit = build();

    expect(cubit.state.computers, computers);
    expect(cubit.state.targetId, "b");
  });

  test("takes the stored pick while no connection names a target", () async {
    storedTarget = "a";

    final cubit = build();
    expect(cubit.state.targetId, isNull);
    await pumpEventQueue();

    expect(cubit.state.targetId, "a");
  });

  test("marks the list's first computer while no target is known, as the relay serves it", () {
    registeredBridges.emitBridges(bridges: [testBridgeSummary(id: "a"), testBridgeSummary(id: "b")]);

    final state = build().state;

    expect(state.targetId, isNull);
    expect(state.currentId, "a");
    expect(ComputerSwitcherState(computers: state.computers, targetId: "b", localId: null).currentId, "b");
  });

  test("without a target it views this computer, never another one", () async {
    registeredBridges.emitBridges(
      bridges: [
        testBridgeSummary(id: "other"),
        testBridgeSummary(id: "local"),
      ],
    );
    localId.add("local");

    final cubit = build();

    expect(cubit.state.currentId, "local");
    expect(cubit.state.viewsAnotherComputer, isFalse);

    localId.add(null);
    await pumpEventQueue();
    expect(cubit.state.viewsAnotherComputer, isFalse);
  });

  test("follows this computer's id and tells another computer's target apart", () async {
    status.add(_reconnectingTo(bridgeId: "local"));
    final cubit = build();
    expect(cubit.state.viewsAnotherComputer, isTrue);

    localId.add("local");
    await pumpEventQueue();
    expect(cubit.state.localId, "local");
    expect(cubit.state.viewsAnotherComputer, isFalse);

    status.add(_reconnectingTo(bridgeId: "other"));
    await pumpEventQueue();
    expect(cubit.state.viewsAnotherComputer, isTrue);
  });

  test("follows the list and the connection's target", () async {
    final cubit = build();
    await pumpEventQueue();

    final computers = [testBridgeSummary(id: "a")];
    registeredBridges.emitBridges(bridges: computers);
    status.add(_reconnectingTo(bridgeId: "a"));
    await pumpEventQueue();
    expect(cubit.state.computers, computers);
    expect(cubit.state.targetId, "a");

    status.add(_reconnectingTo(bridgeId: "b"));
    await pumpEventQueue();
    expect(cubit.state.targetId, "b");
  });

  test("a connection without a target keeps the picked computer", () async {
    status.add(_reconnectingTo(bridgeId: "a"));
    final cubit = build();

    status.add(const ConnectionStatus.disconnected());
    await pumpEventQueue();

    expect(cubit.state.targetId, "a");
  });
}
