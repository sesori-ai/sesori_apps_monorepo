import "dart:async";

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

class _BridgeApi() extends Mock implements BridgeApi;

const _email = "fixture@example.invalid";
const _accountId = "account-1";
const _user = AuthUser(
  id: _accountId,
  provider: AuthProvider.email,
  providerUserId: "opaque-provider-1",
  providerUsername: null,
);
const _registration = BridgeRegistrationRecord(bridgeId: "fixture-bridge", accountId: _accountId);

Matcher _throwsFailure({required probe.AuthenticatedProbeFailureReason reason}) => throwsA(
  isA<probe.AuthenticatedProbeFailure>().having((failure) => failure.reason, "reason", reason),
);

void main() {
  late _Auth auth;
  late _Instance instance;
  late _Status status;
  late _Logout logout;
  late bool locallyValid;
  late BridgeRegistrationRecord? registration;
  late probe.AuthenticatedProbeDeletionDiagnostic? deletionDiagnostic;

  Future<void> unregister({required String accountId, required probe.AuthenticatedProbePhase phase}) =>
      probe.unregisterAndLogoutProbe(
        accountId: accountId,
        phase: phase,
        status: status,
        logout: logout,
        readDeletionDiagnostic: () => deletionDiagnostic,
      );

  setUpAll(() => registerFallbackValue(BridgeProcessDesiredState.off));
  setUp(() {
    auth = _Auth();
    instance = _Instance();
    status = _Status();
    logout = _Logout();
    locallyValid = true;
    registration = _registration;
    deletionDiagnostic = null;
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
      _throwsFailure(reason: probe.AuthenticatedProbeFailureReason.sessionUnavailable),
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
      _throwsFailure(reason: probe.AuthenticatedProbeFailureReason.intentChanged),
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
      _throwsFailure(reason: probe.AuthenticatedProbeFailureReason.accountChanged),
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

  test("successful cleanup requires a registration; failed-run cleanup permits absence", () async {
    registration = null;
    when(() => instance.readBridgeDesiredStateForRestore()).thenAnswer((_) async => BridgeProcessDesiredState.on);
    await expectLater(
      probe.exerciseAuthenticatedProbe(
        phase: probe.AuthenticatedProbePhase.onToLogout,
        auth: auth,
        instance: instance,
        unregisterAndLogout: unregister,
        readInput: () => _user.id,
      ),
      _throwsFailure(reason: probe.AuthenticatedProbeFailureReason.registrationMissing),
    );
    verifyNever(() => logout.logoutCurrentDevice());
    expect(locallyValid, isTrue);
    await probe.exerciseAuthenticatedProbe(
      phase: probe.AuthenticatedProbePhase.cleanup,
      auth: auth,
      instance: instance,
      unregisterAndLogout: unregister,
      readInput: () => _user.id,
    );
    verify(() => logout.logoutCurrentDevice()).called(1);
  });

  test("cleanup refuses a different registration owner or an unconfirmed deletion", () async {
    registration = _registration.copyWith(accountId: "another-account");
    await expectLater(
      unregister(accountId: _user.id, phase: probe.AuthenticatedProbePhase.onToLogout),
      _throwsFailure(reason: probe.AuthenticatedProbeFailureReason.registrationOwnerChanged),
    );
    verifyNever(() => logout.logoutCurrentDevice());
    registration = _registration;
    when(() => logout.logoutCurrentDevice()).thenAnswer((_) async => DesktopLogoutOutcome.completed);
    await expectLater(
      unregister(accountId: _user.id, phase: probe.AuthenticatedProbePhase.onToLogout),
      _throwsFailure(reason: probe.AuthenticatedProbeFailureReason.registrationNotCleared),
    );
  });

  test("each failed logout outcome keeps a distinct bounded diagnostic", () async {
    for (final (outcome, reason) in [
      (
        DesktopLogoutOutcome.desiredStatePersistenceFailed,
        probe.AuthenticatedProbeFailureReason.logoutPersistenceFailed,
      ),
      (DesktopLogoutOutcome.bridgeStopFailed, probe.AuthenticatedProbeFailureReason.logoutStopFailed),
      (DesktopLogoutOutcome.localSessionClearFailed, probe.AuthenticatedProbeFailureReason.logoutSessionClearFailed),
    ]) {
      when(() => logout.logoutCurrentDevice()).thenAnswer((_) async => outcome);
      await expectLater(
        unregister(accountId: _user.id, phase: probe.AuthenticatedProbePhase.onToLogout),
        _throwsFailure(reason: reason),
      );
      expect(registration, _registration);
    }
  });

  test("repository observation preserves responses, including idempotent 404, without extra requests", () async {
    final api = _BridgeApi();
    final repository = probe.AuthenticatedProbeBridgeRepository(api: api);
    final rejected = ApiError.nonSuccessCode(errorCode: 403, rawErrorString: "fixture-private response");
    when(() => api.deleteBridge(bridgeId: _registration.bridgeId)).thenAnswer((_) async => ApiResponse.error(rejected));
    final response = await repository.deleteBridge(bridgeId: _registration.bridgeId);
    expect(response, isA<ErrorResponse<void>>().having((value) => value.error, "error", same(rejected)));
    expect(
      repository.deletionDiagnostic,
      isA<probe.AuthenticatedProbeDeletionError>().having((value) => value.innerError, "cause", same(rejected)),
    );
    when(() => api.deleteBridge(bridgeId: _registration.bridgeId)).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "fixture-private absent")),
    );
    expect(await repository.deleteBridge(bridgeId: _registration.bridgeId), isA<SuccessResponse<void>>());
    expect(repository.deletionDiagnostic, isNull);
    when(() => api.deleteBridge(bridgeId: _registration.bridgeId)).thenAnswer((_) async => ApiResponse.success(null));
    expect(await repository.deleteBridge(bridgeId: _registration.bridgeId), isA<SuccessResponse<void>>());
    expect(repository.deletionDiagnostic, isNull);
    verify(() => api.deleteBridge(bridgeId: _registration.bridgeId)).called(3);
  });

  test("repository observation rethrows and retains the original unexpected failure", () async {
    final api = _BridgeApi();
    final repository = probe.AuthenticatedProbeBridgeRepository(api: api);
    final original = StateError("fixture-private response");
    when(() => api.deleteBridge(bridgeId: _registration.bridgeId)).thenThrow(original);
    await expectLater(repository.deleteBridge(bridgeId: _registration.bridgeId), throwsA(same(original)));
    expect(
      repository.deletionDiagnostic,
      isA<probe.AuthenticatedProbeDeletionError>().having((value) => value.innerError, "cause", same(original)),
    );
    verify(() => api.deleteBridge(bridgeId: _registration.bridgeId)).called(1);
  });

  test("unfinished deletion stays distinct when local logout returns before the request", () async {
    final api = _BridgeApi();
    final repository = probe.AuthenticatedProbeBridgeRepository(api: api);
    final response = Completer<ApiResponse<void>>();
    when(() => api.deleteBridge(bridgeId: _registration.bridgeId)).thenAnswer((_) => response.future);
    final pending = repository.deleteBridge(bridgeId: _registration.bridgeId);
    when(() => logout.logoutCurrentDevice()).thenAnswer((_) async => DesktopLogoutOutcome.completed);
    try {
      expect(repository.deletionDiagnostic, isA<probe.AuthenticatedProbeDeletionPending>());
      await expectLater(
        probe.unregisterAndLogoutProbe(
          accountId: _accountId,
          phase: probe.AuthenticatedProbePhase.onToLogout,
          status: status,
          logout: logout,
          readDeletionDiagnostic: () => repository.deletionDiagnostic,
        ),
        _throwsFailure(reason: probe.AuthenticatedProbeFailureReason.bridgeDeletionPending),
      );
      expect(registration, _registration);
    } finally {
      response.complete(ApiResponse.success(null));
      await pending;
    }
    expect(repository.deletionDiagnostic, isNull);
    expect(registration, _registration);
    verify(() => api.deleteBridge(bridgeId: _registration.bridgeId)).called(1);
  });

  test("retained registration surfaces the actual deletion failure without accepting logout", () async {
    final original = ApiError.nonSuccessCode(errorCode: 403, rawErrorString: "fixture-private response");
    deletionDiagnostic = probe.AuthenticatedProbeDeletionError(innerError: original);
    when(() => logout.logoutCurrentDevice()).thenAnswer((_) async => DesktopLogoutOutcome.completed);
    await expectLater(
      unregister(accountId: _accountId, phase: probe.AuthenticatedProbePhase.onToLogout),
      throwsA(
        isA<probe.AuthenticatedProbeDeletionFailure>().having((error) => error.innerError, "cause", same(original)),
      ),
    );
    expect(registration, _registration);
  });

  test("deletion receipts expose only a closed category and optional HTTP status", () {
    for (final (original, reason, suffix) in [
      (ApiError.notAuthenticated(), probe.AuthenticatedProbeFailureReason.bridgeDeletionNotAuthenticated, ""),
      (
        ApiError.nonSuccessCode(errorCode: 403, rawErrorString: "fixture-private token account path"),
        probe.AuthenticatedProbeFailureReason.bridgeDeletionHttpFailed,
        " 403",
      ),
      (
        ApiError.jsonParsing(jsonString: "fixture-private response", innerError: StateError("fixture-private cause")),
        probe.AuthenticatedProbeFailureReason.bridgeDeletionInvalidResponse,
        "",
      ),
      (ApiError.emptyResponse(), probe.AuthenticatedProbeFailureReason.bridgeDeletionInvalidResponse, ""),
      (
        ApiError.dartHttpClient(StateError("fixture-private transport")),
        probe.AuthenticatedProbeFailureReason.bridgeDeletionTransportFailed,
        "",
      ),
      (ApiError.generic(), probe.AuthenticatedProbeFailureReason.bridgeDeletionUnexpected, ""),
      (StateError("fixture-private unexpected"), probe.AuthenticatedProbeFailureReason.bridgeDeletionUnexpected, ""),
    ]) {
      final failure = probe.AuthenticatedProbeDeletionFailure(innerError: original);
      expect(failure.reason, reason);
      expect(failure.innerError, same(original));
      expect(failure.toString(), isNot(contains("fixture-private")));
      expect(
        probe.authenticatedProbeFailureReceipt(phase: probe.AuthenticatedProbePhase.onToLogout, error: failure),
        "FAIL onToLogout ${reason.name}$suffix\n",
      );
    }
  });

  test("failure receipts contain only the phase and closed reason, never unexpected error text", () {
    for (final reason in probe.AuthenticatedProbeFailureReason.values) {
      expect(
        probe.authenticatedProbeFailureReceipt(
          phase: probe.AuthenticatedProbePhase.onToLogout,
          error: probe.AuthenticatedProbeFailure(reason: reason),
        ),
        "FAIL onToLogout ${reason.name}\n",
      );
    }
    expect(
      probe.authenticatedProbeFailureReceipt(
        phase: probe.AuthenticatedProbePhase.cleanup,
        error: StateError("fixture-token private@example.invalid /fixture/private/home\nFAIL cleanup forged"),
      ),
      "FAIL cleanup unexpected\n",
    );
  });
}
