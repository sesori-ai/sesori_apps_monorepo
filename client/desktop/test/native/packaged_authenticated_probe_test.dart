import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "packaged_authenticated_probe.dart" as probe;

class _Auth() extends Mock implements AuthSession;

class _Instance() extends Mock implements DesktopInstanceService;

const _email = "fixture@example.invalid";
const _user = AuthUser(id: "fixture", provider: AuthProvider.email, providerUserId: _email, providerUsername: null);

void main() {
  late _Auth auth;
  late _Instance instance;

  setUpAll(() => registerFallbackValue(BridgeProcessDesiredState.off));
  setUp(() {
    auth = _Auth();
    instance = _Instance();
    when(() => auth.currentState).thenReturn(const AuthState.authenticated(user: _user));
    when(() => auth.hasLocallyValidSession()).thenAnswer((_) async => true);
    when(() => auth.restoreLocalSession()).thenAnswer((_) async => true);
    when(() => instance.writeBridgeDesiredState(state: any(named: "state"))).thenAnswer((_) async {});
  });

  test("only initial login consumes a password and writes initial On intent", () async {
    when(() => auth.hasLocallyValidSession()).thenAnswer((_) async => false);
    when(() => auth.loginWithEmail(email: _email, password: "fixture-password")).thenAnswer(
      (_) async => const AuthLoginResult(user: _user, accountStatus: AccountStatus.existing),
    );
    final lines = [_email, "fixture-password"];
    await probe.exerciseAuthenticatedProbe(
      phase: probe.AuthenticatedProbePhase.loginOn,
      auth: auth,
      instance: instance,
      readInput: () => lines.removeAt(0),
    );
    expect(lines, isEmpty);
    verify(() => auth.loginWithEmail(email: _email, password: "fixture-password")).called(1);
    verify(() => instance.writeBridgeDesiredState(state: BridgeProcessDesiredState.on)).called(1);
    verifyNever(() => auth.restoreLocalSession());
  });

  test("preservation checks are local and verify old intent before setting the next intent", () async {
    for (final (phase, oldIntent, nextIntent) in [
      (probe.AuthenticatedProbePhase.onToOff, BridgeProcessDesiredState.on, BridgeProcessDesiredState.off),
      (probe.AuthenticatedProbePhase.offToOn, BridgeProcessDesiredState.off, BridgeProcessDesiredState.on),
    ]) {
      when(() => instance.readBridgeDesiredStateForRestore()).thenAnswer((_) async => oldIntent);
      final lines = [_email];
      await probe.exerciseAuthenticatedProbe(
        phase: phase,
        auth: auth,
        instance: instance,
        readInput: () => lines.removeAt(0),
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
    when(() => auth.hasLocallyValidSession()).thenAnswer((_) async => false);
    await expectLater(
      probe.exerciseAuthenticatedProbe(
        phase: probe.AuthenticatedProbePhase.onToOff,
        auth: auth,
        instance: instance,
        readInput: () => _email,
      ),
      throwsStateError,
    );
    verifyNever(() => instance.writeBridgeDesiredState(state: any(named: "state")));
    when(() => auth.hasLocallyValidSession()).thenAnswer((_) async => true);
    when(() => instance.readBridgeDesiredStateForRestore()).thenAnswer((_) async => BridgeProcessDesiredState.off);
    await expectLater(
      probe.exerciseAuthenticatedProbe(
        phase: probe.AuthenticatedProbePhase.onToOff,
        auth: auth,
        instance: instance,
        readInput: () => _email,
      ),
      throwsStateError,
    );
    verifyNever(() => instance.writeBridgeDesiredState(state: any(named: "state")));
  });

  test("cleanup logs out only this device, never all account sessions", () async {
    var valid = true;
    when(() => auth.hasLocallyValidSession()).thenAnswer((_) async => valid);
    when(() => auth.logoutCurrentDevice()).thenAnswer((_) async => valid = false);
    when(() => instance.readBridgeDesiredStateForRestore()).thenAnswer((_) async => BridgeProcessDesiredState.on);
    await probe.exerciseAuthenticatedProbe(
      phase: probe.AuthenticatedProbePhase.onToLogout,
      auth: auth,
      instance: instance,
      readInput: () => _email,
    );
    verify(() => auth.logoutCurrentDevice()).called(1);
    verifyNever(() => auth.invalidateAllSessions());
  });
}
