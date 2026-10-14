import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

import "../support/bridge_id_storage.dart";

class _MockSelectedComputerService() extends Mock implements SelectedComputerService;

void main() {
  late BridgeStatusTracker tracker;
  late _MockSelectedComputerService selection;
  late DesktopComputerTargetOrchestrator orchestrator;

  Future<void> start({required String? persistedBridgeId}) async {
    tracker = BridgeStatusTracker(bridgeIdStorage: MemoryBridgeIdStorage()..bridgeId = persistedBridgeId);
    addTearDown(tracker.dispose);
    await tracker.initialize();
    orchestrator = DesktopComputerTargetOrchestrator(statusTracker: tracker, selectedComputerService: selection);
    addTearDown(orchestrator.dispose);
    await orchestrator.start();
  }

  setUp(() {
    selection = _MockSelectedComputerService();
    when(() => selection.ensureInitialTarget()).thenAnswer((_) async {});
    when(() => selection.followLocalComputer(bridgeId: any(named: "bridgeId"))).thenAnswer((_) async {});
  });

  test("start resolves the initial target without following the id it already knows", () async {
    await start(persistedBridgeId: "local");
    // A helper start re-announces the same id.
    tracker.handleRegistered(bridgeId: "local", accountId: "account-a");
    await pumpEventQueue();

    verify(() => selection.ensureInitialTarget()).called(1);
    verifyNever(() => selection.followLocalComputer(bridgeId: any(named: "bridgeId")));
  });

  test("an id that appears is followed", () async {
    await start(persistedBridgeId: null);

    tracker.handleRegistered(bridgeId: "local", accountId: "account-a");
    await pumpEventQueue();

    verify(() => selection.followLocalComputer(bridgeId: "local")).called(1);
  });

  test("an id that changes is followed", () async {
    await start(persistedBridgeId: "old");

    tracker.handleRegistered(bridgeId: "new", accountId: "account-a");
    await pumpEventQueue();

    verify(() => selection.followLocalComputer(bridgeId: "new")).called(1);
  });

  test("a cleared id is not followed", () async {
    await start(persistedBridgeId: null);
    tracker.handleRegistered(bridgeId: "local", accountId: "account-a");
    await pumpEventQueue();
    clearInteractions(selection);

    await tracker.clearBridgeId(
      registration: const BridgeRegistrationRecord(bridgeId: "local", accountId: "account-a"),
    );
    await pumpEventQueue();

    verifyNever(() => selection.followLocalComputer(bridgeId: any(named: "bridgeId")));
  });
}
