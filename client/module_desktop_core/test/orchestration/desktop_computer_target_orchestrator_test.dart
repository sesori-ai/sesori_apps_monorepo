import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

import "../support/bridge_id_storage.dart";

class _MockSelectedComputerService() extends Mock implements SelectedComputerService;

class _MockAuthSession() extends Mock implements AuthSession;

void main() {
  late BridgeStatusTracker tracker;
  late _MockSelectedComputerService selection;
  late BehaviorSubject<AuthState> authStates;
  late DesktopComputerTargetOrchestrator orchestrator;

  Future<void> start({required String? persistedBridgeId}) async {
    tracker = BridgeStatusTracker(bridgeIdStorage: MemoryBridgeIdStorage()..bridgeId = persistedBridgeId);
    addTearDown(tracker.dispose);
    await tracker.initialize();
    final authSession = _MockAuthSession();
    when(() => authSession.authStateStream).thenAnswer((_) => authStates.stream);
    orchestrator = DesktopComputerTargetOrchestrator(
      statusTracker: tracker,
      selectedComputerService: selection,
      authSession: authSession,
    );
    addTearDown(orchestrator.dispose);
    await orchestrator.start();
  }

  setUp(() {
    selection = _MockSelectedComputerService();
    authStates = BehaviorSubject<AuthState>.seeded(const AuthState.initial());
    addTearDown(authStates.close);
    when(() => selection.ensureInitialTarget(localBridgeId: any(named: "localBridgeId"))).thenAnswer((_) async {});
    when(() => selection.followLocalComputer(bridgeId: any(named: "bridgeId"))).thenAnswer((_) async {});
  });

  test("start resolves the initial target without following the id it already knows", () async {
    await start(persistedBridgeId: "local");
    // A helper start re-announces the same id.
    tracker.handleRegistered(bridgeId: "local", accountId: "account-a");
    await pumpEventQueue();

    verify(() => selection.ensureInitialTarget(localBridgeId: "local")).called(1);
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

  test("a sign-out forgets the user's pick", () async {
    await start(persistedBridgeId: "local");
    verifyNever(selection.forgetPick);

    authStates.add(const AuthState.unauthenticated());
    await pumpEventQueue();

    verify(selection.forgetPick).called(1);
  });

  test("a sign-in pins this computer again", () async {
    await start(persistedBridgeId: "local");
    clearInteractions(selection);

    authStates.add(const AuthState.unauthenticated());
    authStates.add(const AuthState.authenticated(user: _user));
    await pumpEventQueue();

    verify(() => selection.ensureInitialTarget(localBridgeId: "local")).called(1);
  });
}

const AuthUser _user = AuthUser(
  id: "account-a",
  provider: AuthProvider.github,
  providerUserId: "github-a",
  providerUsername: "account-a",
);
