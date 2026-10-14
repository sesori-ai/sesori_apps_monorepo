import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class _MockSelectedComputerService() extends Mock implements SelectedComputerService;

ConnectionStatus _reconnectingTo({required String? bridgeId}) => ConnectionStatus.reconnecting(
  config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "t", bridgeId: bridgeId),
);

void main() {
  late MockRegisteredBridgesService registeredBridges;
  late MockConnectionService connection;
  late BehaviorSubject<ConnectionStatus> status;
  late _MockSelectedComputerService selectedComputer;
  String? storedTarget;

  setUp(() {
    registeredBridges = MockRegisteredBridgesService();
    connection = MockConnectionService();
    status = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
    selectedComputer = _MockSelectedComputerService();
    storedTarget = null;
    when(() => connection.status).thenAnswer((_) => status.stream);
    when(() => connection.currentStatus).thenAnswer((_) => status.value);
    when(selectedComputer.targetBridgeId).thenAnswer((_) async => status.value.targetBridgeId ?? storedTarget);
  });

  tearDown(() => status.close());

  ComputerSwitcherCubit build() {
    final cubit = ComputerSwitcherCubit(
      registeredBridgesService: registeredBridges,
      connectionService: connection,
      selectedComputerService: selectedComputer,
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
    expect(ComputerSwitcherState(computers: state.computers, targetId: "b").currentId, "b");
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
