import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "packaged_authenticated_probe.dart" as probe;

class _Auth() extends Mock implements AuthSession;

class _Instance() extends Mock implements DesktopInstanceService;

class _Status() extends Mock implements BridgeStatusTracker;

class _Logout() extends Mock implements DesktopLogoutOrchestrator;

const _email = "fixture@example.invalid";
const _accountId = "account-1";
const _user = AuthUser(
  id: _accountId,
  provider: AuthProvider.email,
  providerUserId: "opaque-provider-1",
  providerUsername: null,
);
const _registration = BridgeRegistrationRecord(bridgeId: "fixture-bridge", accountId: _accountId);

void main() {
  late _Auth auth;
  late _Instance instance;
  late _Status status;
  late _Logout logout;
  late bool locallyValid;
  late BridgeRegistrationRecord? registration;

  Future<void> unregister({required String accountId}) => probe.unregisterAndLogoutProbe(
    accountId: accountId,
    status: status,
    logout: logout,
  );

  setUpAll(() => registerFallbackValue(BridgeProcessDesiredState.off));
  setUp(() {
    auth = _Auth();
    instance = _Instance();
    status = _Status();
    logout = _Logout();
    locallyValid = true;
    registration = _registration;
    when(() => auth.currentState).thenReturn(const AuthState.authenticated(user: _user));
    when(() => auth.hasLocallyValidSession()).thenAnswer((_) async => locallyValid);
    when(() => auth.restoreLocalSession()).thenAnswer((_) async => true);
    when(() => instance.writeBridgeDesiredState(state: any(named: "state"))).thenAnswer((_) async {});
    when(() => status.initialize()).thenAnswer((_) async {});
    when(() => status.registeredBridge).thenAnswer((_) => registration);
    when(() => logout.logoutCurrentDevice()).thenAnswer((_) async {
      registration = null;
      locallyValid = false;
      return DesktopLogoutOutcome.completed;
    });
  });

  test("initial email login accepts an opaque provider id and returns the stable account id", () async {
    locallyValid = false;
    when(() => auth.loginWithEmail(email: _email, password: "fixture-password")).thenAnswer(
      (_) async => const AuthLoginResult(user: _user, accountStatus: AccountStatus.existing),
    );
    final lines = [_email, "fixture-password"];
    final accountId = await probe.exerciseAuthenticatedProbe(
      phase: probe.AuthenticatedProbePhase.loginOn,
      auth: auth,
      instance: instance,
      unregisterAndLogout: unregister,
      readInput: () => lines.removeAt(0),
    );
    expect(accountId, _user.id);
    expect(lines, isEmpty);
    verify(() => auth.loginWithEmail(email: _email, password: "fixture-password")).called(1);
    verify(() => instance.writeBridgeDesiredState(state: BridgeProcessDesiredState.on)).called(1);
    verifyNever(() => auth.restoreLocalSession());
  });

  test("preservation compares stable identity and old intent locally before changing intent", () async {
    for (final (phase, oldIntent, nextIntent) in [
      (probe.AuthenticatedProbePhase.onToOff, BridgeProcessDesiredState.on, BridgeProcessDesiredState.off),
      (probe.AuthenticatedProbePhase.offToOn, BridgeProcessDesiredState.off, BridgeProcessDesiredState.on),
    ]) {
      when(() => instance.readBridgeDesiredStateForRestore()).thenAnswer((_) async => oldIntent);
      final lines = [_user.id];
      expect(
        await probe.exerciseAuthenticatedProbe(
          phase: phase,
          auth: auth,
          instance: instance,
          unregisterAndLogout: unregister,
          readInput: () => lines.removeAt(0),
        ),
        _user.id,
      );
      expect(lines, isEmpty);
      verifyInOrder([
        () => auth.hasLocallyValidSession(),
        () => auth.restoreLocalSession(),
        () => instance.readBridgeDesiredStateForRestore(),
        () => instance.writeBridgeDesiredState(state: nextIntent),
      ]);
    }
    verifyNever(() => auth.restoreSession());
    verifyNever(() => auth.getCurrentUser());
    verifyNever(
      () => auth.loginWithEmail(
        email: any(named: "email"),
        password: any(named: "password"),
      ),
    );
  });

  test("lost session or changed intent fails instead of repairing the fixture", () async {
    locallyValid = false;
    await expectLater(
      probe.exerciseAuthenticatedProbe(
        phase: probe.AuthenticatedProbePhase.onToOff,
        auth: auth,
        instance: instance,
        unregisterAndLogout: unregister,
        readInput: () => _user.id,
      ),
      throwsStateError,
    );
    verifyNever(() => instance.writeBridgeDesiredState(state: any(named: "state")));
    locallyValid = true;
    when(() => instance.readBridgeDesiredStateForRestore()).thenAnswer((_) async => BridgeProcessDesiredState.off);
    await expectLater(
      probe.exerciseAuthenticatedProbe(
        phase: probe.AuthenticatedProbePhase.onToOff,
        auth: auth,
        instance: instance,
        unregisterAndLogout: unregister,
        readInput: () => _user.id,
      ),
      throwsStateError,
    );
    verifyNever(() => instance.writeBridgeDesiredState(state: any(named: "state")));
  });

  test("a different stored account fails even with the same email provider identity", () async {
    when(() => auth.currentState).thenReturn(AuthState.authenticated(user: _user.copyWith(id: "different-account")));
    await expectLater(
      probe.exerciseAuthenticatedProbe(
        phase: probe.AuthenticatedProbePhase.offToOn,
        auth: auth,
        instance: instance,
        unregisterAndLogout: unregister,
        readInput: () => _user.id,
      ),
      throwsStateError,
    );
    verifyNever(() => instance.writeBridgeDesiredState(state: any(named: "state")));
  });

  test("logout loads the owned registration and uses the desktop unregistration owner", () async {
    when(() => instance.readBridgeDesiredStateForRestore()).thenAnswer((_) async => BridgeProcessDesiredState.on);
    await probe.exerciseAuthenticatedProbe(
      phase: probe.AuthenticatedProbePhase.onToLogout,
      auth: auth,
      instance: instance,
      unregisterAndLogout: unregister,
      readInput: () => _user.id,
    );
    verifyInOrder([() => status.initialize(), () => logout.logoutCurrentDevice(), () => auth.hasLocallyValidSession()]);
    expect(registration, isNull);
    verifyNever(() => auth.logoutCurrentDevice());
    verifyNever(() => auth.invalidateAllSessions());
  });

  test("failure cleanup attempts the existing logout owner even when preservation failed", () async {
    locallyValid = false;
    when(() => auth.restoreLocalSession()).thenAnswer((_) async => false);
    await probe.exerciseAuthenticatedProbe(
      phase: probe.AuthenticatedProbePhase.cleanup,
      auth: auth,
      instance: instance,
      unregisterAndLogout: unregister,
      readInput: () => _user.id,
    );
    verify(() => logout.logoutCurrentDevice()).called(1);
    verifyNever(() => instance.readBridgeDesiredStateForRestore());
    verifyNever(() => auth.invalidateAllSessions());
  });

  test("cleanup refuses a different registration owner or an unconfirmed deletion", () async {
    registration = _registration.copyWith(accountId: "another-account");
    await expectLater(unregister(accountId: _user.id), throwsStateError);
    verifyNever(() => logout.logoutCurrentDevice());
    registration = _registration;
    when(() => logout.logoutCurrentDevice()).thenAnswer((_) async => DesktopLogoutOutcome.completed);
    await expectLater(unregister(accountId: _user.id), throwsStateError);
  });
}
