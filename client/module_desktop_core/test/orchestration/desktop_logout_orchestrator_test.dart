import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

import "../support/bridge_id_storage.dart";

void main() {
  late _MockBridgeProcessService processService;
  late _MockControlCommandService controlCommandService;
  late _MockBridgeRepository bridgeRepository;
  late _MockAuthSession authSession;
  late _MockDesktopInstanceService instanceService;
  late MemoryBridgeIdStorage bridgeIdStorage;
  late BridgeStatusTracker statusTracker;
  late DesktopLogoutTracker logoutTracker;
  late DesktopLogoutOrchestrator orchestrator;

  setUp(() {
    processService = _MockBridgeProcessService();
    controlCommandService = _MockControlCommandService();
    bridgeRepository = _MockBridgeRepository();
    authSession = _MockAuthSession();
    instanceService = _MockDesktopInstanceService();
    bridgeIdStorage = MemoryBridgeIdStorage();
    statusTracker = BridgeStatusTracker(bridgeIdStorage: bridgeIdStorage);
    logoutTracker = DesktopLogoutTracker();
    when(
      () => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.off),
    ).thenAnswer((_) async {});
    orchestrator = DesktopLogoutOrchestrator(
      processService: processService,
      controlCommandService: controlCommandService,
      instanceService: instanceService,
      bridgeRepository: bridgeRepository,
      statusTracker: statusTracker,
      logoutTracker: logoutTracker,
      authSession: authSession,
    );
  });

  tearDown(() async {
    await statusTracker.dispose();
    await logoutTracker.dispose();
  });

  test("cancels startup restore before stopping the helper and clearing the local session", () async {
    final List<String> operations = <String>[];
    when(() => instanceService.cancelPendingBridgeRestore()).thenAnswer((_) => operations.add("cancel"));
    when(() => controlCommandService.unregisterAndExit()).thenAnswer((_) => operations.add("unregister"));
    when(() => processService.stop()).thenAnswer((_) async => operations.add("stop"));
    when(
      () => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.off),
    ).thenAnswer((_) async => operations.add("persist"));
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async => operations.add("logout"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.completed);
    expect(operations, <String>["cancel", "persist", "unregister", "stop", "logout"]);
  });

  test("unregisters through the helper, then confirms deletion before local logout", () async {
    final List<String> operations = <String>[];
    statusTracker.handleRegistered(bridgeId: "bridge-1");
    await pumpEventQueue();
    when(() => controlCommandService.unregisterAndExit()).thenAnswer((_) => operations.add("unregister"));
    when(() => processService.stop()).thenAnswer((_) async => operations.add("stop"));
    when(() => bridgeRepository.deleteBridge(bridgeId: "bridge-1")).thenAnswer((_) async {
      operations.add("delete");
      return ApiResponse.success(null);
    });
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async => operations.add("logout"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.completed);
    expect(operations, <String>["unregister", "stop", "delete", "logout"]);
    expect(bridgeIdStorage.bridgeId, isNull);
    expect(statusTracker.status.bridgeId, isNull);
  });

  test("attempts GUI deletion even when the helper stop fails", () async {
    statusTracker.handleRegistered(bridgeId: "bridge-stuck");
    await pumpEventQueue();
    when(() => controlCommandService.unregisterAndExit()).thenThrow(const ControlHelperNotConnectedException());
    when(() => processService.stop()).thenThrow(StateError("helper remained alive"));
    when(() => bridgeRepository.deleteBridge(bridgeId: "bridge-stuck")).thenAnswer((_) async {
      return ApiResponse.success(null);
    });

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.bridgeStopFailed);
    verify(() => bridgeRepository.deleteBridge(bridgeId: "bridge-stuck")).called(1);
    verifyNever(() => authSession.logoutCurrentDevice());
    expect(bridgeIdStorage.bridgeId, isNull);
  });

  test("continues local logout when GUI deletion is offline", () async {
    statusTracker.handleRegistered(bridgeId: "bridge-offline");
    await pumpEventQueue();
    when(() => controlCommandService.unregisterAndExit()).thenAnswer((_) {});
    when(() => processService.stop()).thenAnswer((_) async {});
    when(() => bridgeRepository.deleteBridge(bridgeId: "bridge-offline")).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {});

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.completed);
    verify(() => bridgeRepository.deleteBridge(bridgeId: "bridge-offline")).called(1);
    verify(() => authSession.logoutCurrentDevice()).called(1);
    // Retain the id when the server could not confirm deletion, so a later
    // explicitly-triggered logout can retry the fallback.
    expect(bridgeIdStorage.bridgeId, "bridge-offline");
  });

  test("keeps controls locked through token clearing and shares concurrent logout", () async {
    final Completer<void> tokenClear = Completer<void>();
    when(() => processService.stop()).thenAnswer((_) async {});
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) => tokenClear.future);

    final Future<DesktopLogoutOutcome> first = orchestrator.logoutCurrentDevice();
    final Future<DesktopLogoutOutcome> second = orchestrator.logoutCurrentDevice();
    await pumpEventQueue();

    expect(identical(first, second), isTrue);
    expect(logoutTracker.status, DesktopLogoutStatus.inProgress);
    verify(() => processService.stop()).called(1);

    tokenClear.complete();
    expect(await first, DesktopLogoutOutcome.completed);
    expect(logoutTracker.status, DesktopLogoutStatus.idle);
  });

  test("does not stop the helper or clear authentication when Off cannot be persisted", () async {
    when(
      () => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.off),
    ).thenThrow(StateError("application support is read-only"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.desiredStatePersistenceFailed);
    verifyNever(() => processService.stop());
    verifyNever(() => authSession.logoutCurrentDevice());
  });

  test("does not clear authentication when the helper cannot stop", () async {
    when(() => controlCommandService.unregisterAndExit()).thenAnswer((_) {});
    when(() => processService.stop()).thenThrow(StateError("helper remained alive"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.bridgeStopFailed);
    verify(() => instanceService.cancelPendingBridgeRestore()).called(1);
    verify(() => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.off)).called(1);
    verify(() => controlCommandService.unregisterAndExit()).called(1);
    verifyNever(() => authSession.logoutCurrentDevice());
  });

  test("reports a local-session failure after a successful helper stop", () async {
    when(() => processService.stop()).thenAnswer((_) async {});
    when(() => authSession.logoutCurrentDevice()).thenThrow(StateError("secure storage unavailable"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.localSessionClearFailed);
    verify(() => processService.stop()).called(1);
  });
}

class _MockBridgeProcessService() extends Mock implements BridgeProcessService;

class _MockControlCommandService() extends Mock implements ControlCommandService;

class _MockBridgeRepository() extends Mock implements BridgeRepository;

class _MockAuthSession() extends Mock implements AuthSession;

class _MockDesktopInstanceService() extends Mock implements DesktopInstanceService;
