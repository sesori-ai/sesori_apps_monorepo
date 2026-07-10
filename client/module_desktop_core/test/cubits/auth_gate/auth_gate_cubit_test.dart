import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockAuthSession extends Mock implements AuthSession {}

const AuthUser _user = AuthUser(
  id: "user-1",
  provider: AuthProvider.github,
  providerUserId: "gh-1",
  providerUsername: "alex",
);

void main() {
  late _MockAuthSession authSession;
  late BehaviorSubject<AuthState> authStates;

  setUp(() {
    authSession = _MockAuthSession();
    authStates = BehaviorSubject<AuthState>.seeded(const AuthState.initial());
    when(() => authSession.authStateStream).thenAnswer((_) => authStates.stream);
    when(() => authSession.currentState).thenAnswer((_) => authStates.value);
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => false);
    when(() => authSession.restoreLocalSession()).thenAnswer((_) async => false);
  });

  tearDown(() async {
    await authStates.close();
  });

  Future<AuthGateCubit> pumpCubit() async {
    final AuthGateCubit cubit = AuthGateCubit(authSession);
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

    final AuthGateCubit cubit = AuthGateCubit(authSession);
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

  test("signing out during token-only recovery cannot be undone by the in-flight restore", () async {
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => true);
    when(() => authSession.restoreLocalSession()).thenAnswer((_) async => false);
    final Completer<bool> restore = Completer<bool>();
    when(() => authSession.restoreSession()).thenAnswer(
      (_) => restore.future.then((confirmed) {
        if (confirmed) {
          authStates.add(const AuthState.authenticated(user: _user));
        }
        return confirmed;
      }),
    );
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {
      authStates.add(const AuthState.unauthenticated());
    });
    final AuthGateCubit cubit = AuthGateCubit(authSession);
    addTearDown(cubit.close);
    await pumpEventQueue();
    expect(cubit.state, const AuthGateState.signedIn(user: null));

    final Future<void> signOut = cubit.signOut();
    // The /auth/me confirmation lands only AFTER the user clicked sign out.
    restore.complete(true);
    await signOut;
    await pumpEventQueue();

    expect(cubit.state, const AuthGateState.signedOut());
  });

  test("a restore outliving the sign-out fence is re-cleared when it settles", () async {
    bool tokensStored = true;
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => tokensStored);
    when(() => authSession.restoreLocalSession()).thenAnswer((_) async => false);
    final Completer<bool> hungRestore = Completer<bool>();
    when(() => authSession.restoreSession()).thenAnswer(
      (_) => hungRestore.future.then((confirmed) {
        if (confirmed) {
          authStates.add(const AuthState.authenticated(user: _user));
        }
        return confirmed;
      }),
    );
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {
      tokensStored = false;
      authStates.add(const AuthState.unauthenticated());
    });
    final AuthGateCubit cubit = AuthGateCubit(
      authSession,
      signOutRestoreFence: const Duration(milliseconds: 20),
    );
    addTearDown(cubit.close);
    await pumpEventQueue();

    // The fence times out on the hung restore and the sign-out proceeds.
    await cubit.signOut();
    expect(cubit.state, const AuthGateState.signedOut());

    // The hung /auth/me finally lands and re-emits authenticated — the
    // chained re-clear must flip it back to signed out (no fresh tokens
    // exist, so this is the stale session).
    hungRestore.complete(true);
    await pumpEventQueue();

    expect(cubit.state, const AuthGateState.signedOut());
    verify(() => authSession.logoutCurrentDevice()).called(2);
  });

  test("the delayed re-clear is unconditional — a sign-in inside the window is bounced once", () async {
    // Deliberate correctness-first trade (see the plan's risk register): the
    // stale restore's own token refresh can re-persist tokens post-logout,
    // so no local check can tell it apart from a fresh sign-in. The re-clear
    // therefore always runs; a fresh sign-in completing inside this
    // pathological window is signed out once more (visible, recoverable)
    // instead of ever leaving a sign-out silently undone.
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => true);
    when(() => authSession.restoreLocalSession()).thenAnswer((_) async => false);
    final Completer<bool> hungRestore = Completer<bool>();
    when(() => authSession.restoreSession()).thenAnswer((_) => hungRestore.future);
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {
      authStates.add(const AuthState.unauthenticated());
    });
    final AuthGateCubit cubit = AuthGateCubit(
      authSession,
      signOutRestoreFence: const Duration(milliseconds: 20),
    );
    addTearDown(cubit.close);
    await pumpEventQueue();
    await cubit.signOut();
    expect(cubit.state, const AuthGateState.signedOut());

    // The user signs back in BEFORE the hung restore settles…
    authStates.add(const AuthState.authenticated(user: _user));
    await pumpEventQueue();
    hungRestore.complete(false);
    await pumpEventQueue();

    // …and is bounced once by the unconditional re-clear.
    expect(cubit.state, const AuthGateState.signedOut());
    verify(() => authSession.logoutCurrentDevice()).called(2);
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

  test("signOut delegates to the device-local logout", () async {
    when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {});
    final AuthGateCubit cubit = await pumpCubit();

    await cubit.signOut();

    verify(() => authSession.logoutCurrentDevice()).called(1);
  });

  test("a failed sign-out is swallowed and leaves the gate unchanged", () async {
    when(() => authSession.logoutCurrentDevice()).thenThrow(StateError("boom"));
    authStates.add(const AuthState.authenticated(user: _user));
    final AuthGateCubit cubit = await pumpCubit();

    await cubit.signOut();

    expect(cubit.state, const AuthGateState.signedIn(user: _user));
  });
}
