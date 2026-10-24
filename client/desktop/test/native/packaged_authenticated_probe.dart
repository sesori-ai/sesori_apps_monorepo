// CI-only auth/persistence fixture, never packaged or used as product GUI evidence.
import "dart:io";

import "package:flutter/widgets.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Each transition verifies existing persisted state before changing the next intent.
enum AuthenticatedProbePhase() {
  loginOn,
  onToOff,
  offToOn,
  onToLogout,
  cleanup,
}

/// Closed diagnostic codes only; original errors and account data stay in the owned home.
enum AuthenticatedProbeFailureReason() {
  sessionAlreadyExists,
  sessionUnavailable,
  localRestoreFailed,
  accountProviderChanged,
  accountChanged,
  intentChanged,
  registrationMissing,
  registrationOwnerChanged,
  logoutPersistenceFailed,
  logoutStopFailed,
  logoutSessionClearFailed,
  registrationNotCleared,
  bridgeDeletionPending,
  bridgeDeletionNotAuthenticated,
  bridgeDeletionHttpFailed,
  bridgeDeletionInvalidResponse,
  bridgeDeletionTransportFailed,
  bridgeDeletionUnexpected,
  sessionNotCleared,
  privateInputMissing,
  unexpected,
}

class const AuthenticatedProbeFailure({required final AuthenticatedProbeFailureReason reason}) implements Exception {
  @override
  String toString() => "AuthenticatedProbeFailure: ${reason.name}";
}

/// Absence means no pending/error observation, not confirmed registration cleanup.
sealed class const AuthenticatedProbeDeletionDiagnostic();

class const AuthenticatedProbeDeletionPending() extends AuthenticatedProbeDeletionDiagnostic;

class const AuthenticatedProbeDeletionError({required final Object innerError})
    extends AuthenticatedProbeDeletionDiagnostic;

/// Observes the real repository result without changing requests, 404 handling or logout ownership.
class AuthenticatedProbeBridgeRepository({required super.api}) extends BridgeRepository {
  AuthenticatedProbeDeletionDiagnostic? _deletionDiagnostic;

  AuthenticatedProbeDeletionDiagnostic? get deletionDiagnostic => _deletionDiagnostic;

  @override
  Future<ApiResponse<void>> deleteBridge({required String bridgeId}) async {
    _deletionDiagnostic = const AuthenticatedProbeDeletionPending();
    try {
      final response = await super.deleteBridge(bridgeId: bridgeId);
      _deletionDiagnostic = switch (response) {
        ErrorResponse(:final error) => AuthenticatedProbeDeletionError(innerError: error),
        SuccessResponse() => null,
      };
      return response;
    } on Object catch (error) {
      _deletionDiagnostic = AuthenticatedProbeDeletionError(innerError: error);
      rethrow;
    }
  }
}

class AuthenticatedProbeDeletionFailure({required final Object innerError}) extends AuthenticatedProbeFailure {
  this : super(reason: _deletionFailureReason(error: innerError));
}

AuthenticatedProbeFailureReason _deletionFailureReason({required Object error}) => switch (error) {
  NotAuthenticatedError() => AuthenticatedProbeFailureReason.bridgeDeletionNotAuthenticated,
  NonSuccessCodeError() => AuthenticatedProbeFailureReason.bridgeDeletionHttpFailed,
  JsonParsingError() || EmptyResponseError() => AuthenticatedProbeFailureReason.bridgeDeletionInvalidResponse,
  DartHttpClientError() ||
  SocketException() ||
  HandshakeException() => AuthenticatedProbeFailureReason.bridgeDeletionTransportFailed,
  _ => AuthenticatedProbeFailureReason.bridgeDeletionUnexpected,
};

String authenticatedProbeFailureReceipt({required AuthenticatedProbePhase phase, required Object error}) {
  final reason = error is AuthenticatedProbeFailure ? error.reason : AuthenticatedProbeFailureReason.unexpected;
  final status = switch (error) {
    AuthenticatedProbeDeletionFailure(innerError: NonSuccessCodeError(:final errorCode)) => " $errorCode",
    _ => "",
  };
  return "FAIL ${phase.name} ${reason.name}$status\n";
}

Future<String> exerciseAuthenticatedProbe({
  required AuthenticatedProbePhase phase,
  required AuthSession auth,
  required DesktopInstanceService instance,
  required Future<void> Function({required String accountId, required AuthenticatedProbePhase phase})
  unregisterAndLogout,
  required String Function() readInput,
}) async {
  // Initial login takes email/password; later phases take only its returned stable account id.
  final input = readInput();
  if (phase == AuthenticatedProbePhase.loginOn) {
    _require(
      condition: !await auth.hasLocallyValidSession(),
      reason: AuthenticatedProbeFailureReason.sessionAlreadyExists,
    );
    await auth.loginWithEmail(email: input, password: readInput());
  } else {
    // Cleanup must still attempt unregistration after a failed preservation check.
    if (phase != AuthenticatedProbePhase.cleanup) {
      _require(
        condition: await auth.hasLocallyValidSession(),
        reason: AuthenticatedProbeFailureReason.sessionUnavailable,
      );
    }
    final restored = await auth.restoreLocalSession();
    if (phase != AuthenticatedProbePhase.cleanup) {
      _require(condition: restored, reason: AuthenticatedProbeFailureReason.localRestoreFailed);
    }
  }
  final String accountId;
  if (phase == AuthenticatedProbePhase.cleanup) {
    accountId = input;
  } else {
    final state = auth.currentState;
    if (state is! AuthAuthenticated || state.user.provider != AuthProvider.email) {
      throw const AuthenticatedProbeFailure(reason: AuthenticatedProbeFailureReason.accountProviderChanged);
    }
    accountId = state.user.id;
    if (phase != AuthenticatedProbePhase.loginOn) {
      _require(condition: accountId == input, reason: AuthenticatedProbeFailureReason.accountChanged);
    }
  }
  switch (phase) {
    case AuthenticatedProbePhase.loginOn:
      // Leave intent unset: the signed GUI's genuine first-run defaults admit On and register login launch.
      break;
    case AuthenticatedProbePhase.onToOff:
      await _requireIntent(instance: instance, expected: BridgeProcessDesiredState.on);
      await instance.writeBridgeDesiredState(state: BridgeProcessDesiredState.off);
    case AuthenticatedProbePhase.offToOn:
      await _requireIntent(instance: instance, expected: BridgeProcessDesiredState.off);
      await instance.writeBridgeDesiredState(state: BridgeProcessDesiredState.on);
    case AuthenticatedProbePhase.onToLogout:
    case AuthenticatedProbePhase.cleanup:
      if (phase == AuthenticatedProbePhase.onToLogout) {
        await _requireIntent(instance: instance, expected: BridgeProcessDesiredState.on);
      }
      await unregisterAndLogout(accountId: accountId, phase: phase);
      _require(
        condition: !await auth.hasLocallyValidSession(),
        reason: AuthenticatedProbeFailureReason.sessionNotCleared,
      );
  }
  return accountId;
}

Future<void> unregisterAndLogoutProbe({
  required String accountId,
  required AuthenticatedProbePhase phase,
  required BridgeStatusTracker status,
  required DesktopLogoutOrchestrator logout,
  required AuthenticatedProbeDeletionDiagnostic? Function() readDeletionDiagnostic,
}) async {
  await status.initialize();
  final registration = status.registeredBridge;
  _require(
    condition: phase != AuthenticatedProbePhase.onToLogout || registration != null,
    reason: AuthenticatedProbeFailureReason.registrationMissing,
  );
  _require(
    condition: registration == null || registration.accountId == accountId,
    reason: AuthenticatedProbeFailureReason.registrationOwnerChanged,
  );
  final outcome = await logout.logoutCurrentDevice();
  switch (outcome) {
    case DesktopLogoutOutcome.completed:
      break;
    case DesktopLogoutOutcome.desiredStatePersistenceFailed:
      throw const AuthenticatedProbeFailure(reason: AuthenticatedProbeFailureReason.logoutPersistenceFailed);
    case DesktopLogoutOutcome.bridgeStopFailed:
      throw const AuthenticatedProbeFailure(reason: AuthenticatedProbeFailureReason.logoutStopFailed);
    case DesktopLogoutOutcome.localSessionClearFailed:
      throw const AuthenticatedProbeFailure(reason: AuthenticatedProbeFailureReason.logoutSessionClearFailed);
  }
  if (status.registeredBridge != null) {
    switch (readDeletionDiagnostic()) {
      case AuthenticatedProbeDeletionPending():
        throw const AuthenticatedProbeFailure(reason: AuthenticatedProbeFailureReason.bridgeDeletionPending);
      case AuthenticatedProbeDeletionError(:final innerError):
        throw AuthenticatedProbeDeletionFailure(innerError: innerError);
      case null:
        throw const AuthenticatedProbeFailure(reason: AuthenticatedProbeFailureReason.registrationNotCleared);
    }
  }
}

Future<void> _requireIntent({
  required DesktopInstanceService instance,
  required BridgeProcessDesiredState expected,
}) async {
  _require(
    condition: await instance.readBridgeDesiredStateForRestore() == expected,
    reason: AuthenticatedProbeFailureReason.intentChanged,
  );
}

Future<void> main() async {
  if (!Platform.isLinux ||
      Platform.environment["GITHUB_ACTIONS"] != "true" ||
      Platform.environment["GITHUB_REF"] != "refs/heads/main" ||
      Platform.environment["GITHUB_EVENT_NAME"] != "workflow_dispatch") {
    throw StateError("Authenticated fixture requires a disposable main-only Linux Actions dispatch");
  }
  final phase = AuthenticatedProbePhase.values.byName(Platform.environment["SESORI_AUTHENTICATED_PROBE_PHASE"]!);
  final report = File(Platform.environment["SESORI_AUTHENTICATED_PROBE_OUTPUT"]!);
  try {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const SizedBox.shrink());
    final router = GoRouter(
      routes: [GoRoute(path: "/", builder: (_, _) => const SizedBox.shrink())],
    );
    configureDesktopDependencies(router: router, routerReady: Future<void>.value());
    try {
      final support = await getIt<DesktopApplicationSupportDirectory>().resolve();
      await File("${report.path}.support-path").writeAsString(support.path);
      final accountId = await exerciseAuthenticatedProbe(
        phase: phase,
        auth: getIt<AuthSession>(),
        instance: getIt<DesktopInstanceService>(),
        unregisterAndLogout: ({required String accountId, required AuthenticatedProbePhase phase}) async {
          final repository = AuthenticatedProbeBridgeRepository(api: getIt<BridgeApi>());
          await getIt.unregister<BridgeRepository>();
          getIt.registerSingleton<BridgeRepository>(repository);
          await unregisterAndLogoutProbe(
            accountId: accountId,
            phase: phase,
            status: getIt<BridgeStatusTracker>(),
            logout: getIt<DesktopLogoutOrchestrator>(),
            readDeletionDiagnostic: () => repository.deletionDiagnostic,
          );
        },
        readInput: _readPrivateLine,
      );
      await File("${report.path}.account-id").writeAsString(accountId);
      await report.writeAsString("PASS ${phase.name}\n");
    } finally {
      await getIt.reset();
      router.dispose();
    }
    exit(0); // Fixture only. Product Quit is exercised separately on the original signed GUI.
  } on Object catch (error, stackTrace) {
    // Both files remain inside the owned private home, never in the artifact allowlist.
    await File("${report.path}.private-error").writeAsString("$error\n$stackTrace\n");
    await report.writeAsString(authenticatedProbeFailureReceipt(phase: phase, error: error));
    exit(1);
  }
}

String _readPrivateLine() {
  final value = stdin.readLineSync();
  if (value == null || value.isEmpty) {
    throw const AuthenticatedProbeFailure(reason: AuthenticatedProbeFailureReason.privateInputMissing);
  }
  return value;
}

void _require({required bool condition, required AuthenticatedProbeFailureReason reason}) {
  if (!condition) throw AuthenticatedProbeFailure(reason: reason);
}
