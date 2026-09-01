import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockAuthSession() extends Mock implements AuthSession;

class _MockDesktopLogoutOrchestrator() extends Mock implements DesktopLogoutOrchestrator;

class _MockDesktopRelayConnectionService() extends Mock implements DesktopRelayConnectionService;

const AuthUser _user = AuthUser(
  id: "user-1",
  provider: AuthProvider.github,
  providerUserId: "gh-1",
  providerUsername: "alex",
);

void main() {
  late _MockAuthSession authSession;
  late _MockDesktopLogoutOrchestrator logoutOrchestrator;
  late _MockDesktopRelayConnectionService relayConnectionService;
  late BehaviorSubject<AuthState> authStates;

  setUp(() {
    authSession = _MockAuthSession();
    logoutOrchestrator = _MockDesktopLogoutOrchestrator();
    relayConnectionService = _MockDesktopRelayConnectionService();
    authStates = BehaviorSubject<AuthState>.seeded(const AuthState.initial());
    when(() => authSession.authStateStream).thenAnswer((_) => authStates.stream);
    when(() => authSession.currentState).thenAnswer((_) => authStates.value);
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => false);
    when(() => authSession.restoreLocalSession()).thenAnswer((_) async => false);
    when(() => relayConnectionService.connectForAuthenticatedDestination()).thenAnswer((_) async {});
    when(() => logoutOrchestrator.logoutCurrentDevice()).thenAnswer((_) async {
      try {
        await authSession.logoutCurrentDevice();
        return DesktopLogoutOutcome.completed;
      } on Object {
        return DesktopLogoutOutcome.localSessionClearFailed;
      }
    });
  });

  tearDown(() async {
    await authStates.close();
  });

  Future<AuthGateCubit> pumpCubit() async {
    final AuthGateCubit cubit = AuthGateCubit(
      authSession: authSession,
      logoutOrchestrator: logoutOrchestrator,
      relayConnectionService: relayConnectionService,
    );
    addTearDown(cubit.close);
    // Let the async restore-and-subscribe bootstrap settle.
    await pumpEventQueue();
    return cubit;
  }

  test("cold start with no local session lands on signedOut", () async {
    final AuthGateCubit cubit = await pumpCubit();

    expect(cubit.state, const AuthGateState.signedOut());
  });

  test("cold start with a locally valid session lands on signedIn", () async {
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => true);
    when(() => authSession.restoreLocalSession()).thenAnswer((_) async {
      authStates.add(const AuthState.authenticated(user: _user));
      return true;
    });

    final AuthGateCubit cubit = await pumpCubit();

    expect(cubit.state, const AuthGateState.signedIn(user: _user));
  });

  test("a live sign-out flips the gate back to signedOut", () async {
    authStates.add(const AuthState.authenticated(user: _user));
    final AuthGateCubit cubit = await pumpCubit();
    expect(cubit.state, const AuthGateState.signedIn(user: _user));

    authStates.add(const AuthState.unauthenticated());
    await pumpEventQueue();

    expect(cubit.state, const AuthGateState.signedOut());
  });

  test("mid-login authenticating does not flip the gate", () async {
    final AuthGateCubit cubit = await pumpCubit();
    expect(cubit.state, const AuthGateState.signedOut());

    authStates.add(const AuthState.authenticating());
    await pumpEventQueue();

    expect(cubit.state, const AuthGateState.signedOut());
  });

  test("valid tokens with a missing cached user stay signed in and recover in the background", () async {
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => true);
    // Local restore cannot emit: the user record is missing.
    when(() => authSession.restoreLocalSession()).thenAnswer((_) async => false);
    when(() => authSession.restoreSession()).thenAnswer((_) async {
      authStates.add(const AuthState.authenticated(user: _user));
      return true;
    });

    final AuthGateCubit cubit = AuthGateCubit(
      authSession: authSession,
      logoutOrchestrator: logoutOrchestrator,
      relayConnectionService: relayConnectionService,
    );
    addTearDown(cubit.close);
    final List<AuthGateState> emitted = <AuthGateState>[];
    final StreamSubscription<AuthGateState> subscription = cubit.stream.listen(emitted.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    // No signedOut flash for a returning user: provisional signedIn(null)
    // first, then the recovered account.
    expect(emitted, const [AuthGateState.signedIn(user: null), AuthGateState.signedIn(user: _user)]);
    verify(() => authSession.restoreSession()).called(1);
  });

  test("sign out delegates immediately while background restore is pending", () async {
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => true);
    when(() => authSession.restoreLocalSession()).thenAnswer((_) async => false);
    final Completer<bool> restore = Completer<bool>();
    when(() => authSession.restoreSession()).thenAnswer((_) => restore.future);
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {
      authStates.add(const AuthState.unauthenticated());
    });

    final AuthGateCubit cubit = AuthGateCubit(
      authSession: authSession,
      logoutOrchestrator: logoutOrchestrator,
      relayConnectionService: relayConnectionService,
    );
    addTearDown(cubit.close);
    await pumpEventQueue();
    expect(cubit.state, const AuthGateState.signedIn(user: null));

    final outcome = await cubit.signOut();

    expect(outcome, DesktopLogoutOutcome.completed);
    expect(cubit.state, const AuthGateState.signedOut());
    verify(() => authSession.logoutCurrentDevice()).called(1);

    restore.complete(false);
    await pumpEventQueue();
  });

  test("an unconfirmed background restore stays provisionally signed in", () async {
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => true);
    when(() => authSession.restoreLocalSession()).thenAnswer((_) async => false);
    when(() => authSession.restoreSession()).thenAnswer((_) async => false);

    final AuthGateCubit cubit = await pumpCubit();

    expect(cubit.state, const AuthGateState.signedIn(user: null));
  });

  test("a failed background restore stays provisionally signed in", () async {
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => true);
    when(() => authSession.restoreLocalSession()).thenAnswer((_) async => false);
    when(() => authSession.restoreSession()).thenThrow(StateError("offline"));

    final AuthGateCubit cubit = await pumpCubit();

    expect(cubit.state, const AuthGateState.signedIn(user: null));
  });

  test("a failed restore degrades to the live stream state instead of throwing", () async {
    when(() => authSession.hasLocallyValidSession()).thenThrow(StateError("storage unavailable"));

    final AuthGateCubit cubit = await pumpCubit();

    expect(cubit.state, const AuthGateState.signedOut());
  });

  test("signed-in destination delegates relay startup", () async {
    final AuthGateCubit cubit = await pumpCubit();

    await cubit.onSignedInDestinationReady();

    verify(() => relayConnectionService.connectForAuthenticatedDestination()).called(1);
  });

  test("signOut delegates to the device-local logout and returns its outcome", () async {
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {});
    final AuthGateCubit cubit = await pumpCubit();

    final outcome = await cubit.signOut();

    expect(outcome, DesktopLogoutOutcome.completed);
    verify(() => authSession.logoutCurrentDevice()).called(1);
  });

  test("a failed sign-out is swallowed and leaves the gate unchanged", () async {
    when(() => authSession.logoutCurrentDevice()).thenThrow(StateError("boom"));
    authStates.add(const AuthState.authenticated(user: _user));
    final AuthGateCubit cubit = await pumpCubit();

    final outcome = await cubit.signOut();

    expect(outcome, DesktopLogoutOutcome.localSessionClearFailed);
    expect(cubit.state, const AuthGateState.signedIn(user: _user));
  });
}
