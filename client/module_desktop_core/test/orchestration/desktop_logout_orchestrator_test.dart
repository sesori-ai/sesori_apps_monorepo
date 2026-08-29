import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _MockBridgeProcessService processService;
  late _MockAuthSession authSession;
  late _MockDesktopInstanceService instanceService;
  late DesktopLogoutTracker logoutTracker;
  late DesktopLogoutOrchestrator orchestrator;

  setUp(() {
    processService = _MockBridgeProcessService();
    authSession = _MockAuthSession();
    instanceService = _MockDesktopInstanceService();
    logoutTracker = DesktopLogoutTracker();
    when(
      () => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.off),
    ).thenAnswer((_) async {});
    orchestrator = DesktopLogoutOrchestrator(
      processService: processService,
      instanceService: instanceService,
      logoutTracker: logoutTracker,
      authSession: authSession,
    );
  });

  tearDown(() async {
    await logoutTracker.dispose();
  });

  test("cancels startup restore before stopping the helper and clearing the local session", () async {
    final List<String> operations = <String>[];
    when(() => instanceService.cancelPendingBridgeRestore()).thenAnswer((_) => operations.add("cancel"));
    when(() => processService.stop()).thenAnswer((_) async => operations.add("stop"));
    when(
      () => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.off),
    ).thenAnswer((_) async => operations.add("persist"));
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async => operations.add("logout"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.completed);
    expect(operations, <String>["cancel", "persist", "stop", "logout"]);
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
    when(() => processService.stop()).thenThrow(StateError("helper remained alive"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.bridgeStopFailed);
    verify(() => instanceService.cancelPendingBridgeRestore()).called(1);
    verify(() => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.off)).called(1);
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

class _MockAuthSession() extends Mock implements AuthSession;

class _MockDesktopInstanceService() extends Mock implements DesktopInstanceService;
