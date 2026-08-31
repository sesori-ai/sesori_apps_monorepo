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
    when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _userA));
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
    when(() => processService.requestStopForLogout()).thenReturn(
      BridgeProcessStopRequest(
        mode: BridgeProcessStopMode.unregister,
        completion: Future<void>(() => operations.add("stop")),
      ),
    );
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
    statusTracker.handleRegistered(bridgeId: "bridge-1", accountId: _userA.id);
    await pumpEventQueue();
    when(() => controlCommandService.unregisterAndExit()).thenAnswer((_) => operations.add("unregister"));
    when(() => processService.requestStopForLogout()).thenReturn(
      BridgeProcessStopRequest(
        mode: BridgeProcessStopMode.unregister,
        completion: Future<void>(() => operations.add("stop")),
      ),
    );
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

  test("falls back to ordinary shutdown when unregister delivery fails", () async {
    final List<String> operations = <String>[];
    statusTracker.handleRegistered(bridgeId: "bridge-delivery-failed", accountId: _userA.id);
    await pumpEventQueue();
    when(() => processService.requestStopForLogout()).thenReturn(
      BridgeProcessStopRequest(
        mode: BridgeProcessStopMode.unregister,
        completion: Future<void>(() => operations.add("stop")),
      ),
    );
    when(() => controlCommandService.unregisterAndExit()).thenThrow(const ControlHelperNotConnectedException());
    when(() => processService.fallbackStopAfterUnregisterFailure()).thenAnswer((_) async => operations.add("fallback"));
    when(() => bridgeRepository.deleteBridge(bridgeId: "bridge-delivery-failed")).thenAnswer((_) async {
      operations.add("delete");
      return ApiResponse.success(null);
    });
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async => operations.add("logout"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.completed);
    expect(operations, <String>["fallback", "stop", "delete", "logout"]);
    verify(() => processService.fallbackStopAfterUnregisterFailure()).called(1);
  });

  test("joins an ordinary stop without sending a late unregister command", () async {
    final List<String> operations = <String>[];
    when(() => processService.requestStopForLogout()).thenReturn(
      BridgeProcessStopRequest(
        mode: BridgeProcessStopMode.ordinary,
        completion: Future<void>(() => operations.add("stop")),
      ),
    );
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async => operations.add("logout"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.completed);
    expect(operations, <String>["stop", "logout"]);
    verifyNever(() => controlCommandService.unregisterAndExit());
  });

  test("attempts GUI deletion even when the helper stop fails", () async {
    statusTracker.handleRegistered(bridgeId: "bridge-stuck", accountId: _userA.id);
    await pumpEventQueue();
    when(() => processService.requestStopForLogout()).thenThrow(StateError("helper remained alive"));
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
    statusTracker.handleRegistered(bridgeId: "bridge-offline", accountId: _userA.id);
    await pumpEventQueue();
    when(() => controlCommandService.unregisterAndExit()).thenAnswer((_) {});
    when(() => processService.requestStopForLogout()).thenReturn(_unregisterStopRequest());
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

  test("deletes a registration for a verified token-only signed-in session", () async {
    statusTracker.handleRegistered(bridgeId: "bridge-token-only", accountId: _userA.id);
    await pumpEventQueue();
    when(() => authSession.currentState).thenReturn(const AuthState.initial());
    when(() => authSession.getCurrentUser()).thenAnswer((_) async => _userA);
    when(() => processService.requestStopForLogout()).thenReturn(_unregisterStopRequest());
    when(() => controlCommandService.unregisterAndExit()).thenAnswer((_) {});
    when(() => bridgeRepository.deleteBridge(bridgeId: "bridge-token-only")).thenAnswer((_) async {
      return ApiResponse.success(null);
    });
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {});

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.completed);
    verify(() => authSession.getCurrentUser()).called(1);
    verify(() => bridgeRepository.deleteBridge(bridgeId: "bridge-token-only")).called(1);
    expect(bridgeIdStorage.registration, isNull);
  });

  test("does not submit or clear a persisted registration owned by another account", () async {
    statusTracker.handleRegistered(bridgeId: "bridge-account-a", accountId: _userA.id);
    await pumpEventQueue();
    when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _userB));
    when(() => controlCommandService.unregisterAndExit()).thenAnswer((_) {});
    when(() => processService.requestStopForLogout()).thenReturn(_unregisterStopRequest());
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {});

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.completed);
    verifyNever(() => bridgeRepository.deleteBridge(bridgeId: "bridge-account-a"));
    verify(() => authSession.logoutCurrentDevice()).called(1);
    expect(bridgeIdStorage.registration?.bridgeId, "bridge-account-a");
    expect(bridgeIdStorage.registration?.accountId, _userA.id);
  });

  test("keeps controls locked through token clearing and shares concurrent logout", () async {
    final Completer<void> tokenClear = Completer<void>();
    when(() => processService.requestStopForLogout()).thenReturn(_unregisterStopRequest());
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) => tokenClear.future);

    final Future<DesktopLogoutOutcome> first = orchestrator.logoutCurrentDevice();
    final Future<DesktopLogoutOutcome> second = orchestrator.logoutCurrentDevice();
    await pumpEventQueue();

    expect(identical(first, second), isTrue);
    expect(logoutTracker.status, DesktopLogoutStatus.inProgress);
    verify(() => processService.requestStopForLogout()).called(1);

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
    verifyNever(() => processService.requestStopForLogout());
    verifyNever(() => authSession.logoutCurrentDevice());
  });

  test("does not clear authentication when the helper cannot stop", () async {
    when(() => processService.requestStopForLogout()).thenThrow(StateError("helper remained alive"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.bridgeStopFailed);
    verify(() => instanceService.cancelPendingBridgeRestore()).called(1);
    verify(() => instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.off)).called(1);
    verifyNever(() => controlCommandService.unregisterAndExit());
    verifyNever(() => authSession.logoutCurrentDevice());
  });

  test("reports a local-session failure after a successful helper stop", () async {
    when(() => processService.requestStopForLogout()).thenReturn(_unregisterStopRequest());
    when(() => authSession.logoutCurrentDevice()).thenThrow(StateError("secure storage unavailable"));

    final DesktopLogoutOutcome outcome = await orchestrator.logoutCurrentDevice();

    expect(outcome, DesktopLogoutOutcome.localSessionClearFailed);
    verify(() => processService.requestStopForLogout()).called(1);
  });
}

class _MockBridgeProcessService() extends Mock implements BridgeProcessService;

class _MockControlCommandService() extends Mock implements ControlCommandService;

class _MockBridgeRepository() extends Mock implements BridgeRepository;

class _MockAuthSession() extends Mock implements AuthSession;

class _MockDesktopInstanceService() extends Mock implements DesktopInstanceService;

BridgeProcessStopRequest _unregisterStopRequest() => BridgeProcessStopRequest(
  mode: BridgeProcessStopMode.unregister,
  completion: Future<void>.value(),
);

const AuthUser _userA = AuthUser(
  id: "account-a",
  provider: AuthProvider.github,
  providerUserId: "github-a",
  providerUsername: "account-a",
);

const AuthUser _userB = AuthUser(
  id: "account-b",
  provider: AuthProvider.github,
  providerUserId: "github-b",
  providerUsername: "account-b",
);
