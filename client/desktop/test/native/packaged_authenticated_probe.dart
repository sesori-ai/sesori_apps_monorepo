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
    _require(condition: !await auth.hasLocallyValidSession(), message: "Fixture already has a session");
    await auth.loginWithEmail(email: input, password: readInput());
  } else {
    // Cleanup must still attempt unregistration after a failed preservation check.
    if (phase != AuthenticatedProbePhase.cleanup) {
      _require(condition: await auth.hasLocallyValidSession(), message: "Persisted session is unavailable");
    }
    final restored = await auth.restoreLocalSession();
    if (phase != AuthenticatedProbePhase.cleanup) {
      _require(condition: restored, message: "Local account restoration failed");
    }
  }
  final String accountId;
  if (phase == AuthenticatedProbePhase.cleanup) {
    accountId = input;
  } else {
    final state = auth.currentState;
    if (state is! AuthAuthenticated || state.user.provider != AuthProvider.email) {
      throw StateError("Stored account is not an authenticated email account");
    }
    accountId = state.user.id;
    if (phase != AuthenticatedProbePhase.loginOn) {
      _require(condition: accountId == input, message: "Stored account differs from the initial QA login");
    }
  }
  switch (phase) {
    case AuthenticatedProbePhase.loginOn:
      await instance.writeBridgeDesiredState(state: BridgeProcessDesiredState.on);
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
      _require(condition: !await auth.hasLocallyValidSession(), message: "Fixture logout failed");
  }
  return accountId;
}

Future<void> unregisterAndLogoutProbe({
  required String accountId,
  required AuthenticatedProbePhase phase,
  required BridgeStatusTracker status,
  required DesktopLogoutOrchestrator logout,
}) async {
  await status.initialize();
  final registration = status.registeredBridge;
  _require(
    condition: phase != AuthenticatedProbePhase.onToLogout || registration != null,
    message: "Registered helper has no persisted bridge record",
  );
  _require(
    condition: registration == null || registration.accountId == accountId,
    message: "Temporary bridge registration belongs to a different account",
  );
  final outcome = await logout.logoutCurrentDevice();
  _require(
    condition: outcome == DesktopLogoutOutcome.completed && status.registeredBridge == null,
    message: "Temporary bridge unregistration/logout did not complete",
  );
}

Future<void> _requireIntent({
  required DesktopInstanceService instance,
  required BridgeProcessDesiredState expected,
}) async {
  _require(
    condition: await instance.readBridgeDesiredStateForRestore() == expected,
    message: "Persisted helper intent changed",
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
        unregisterAndLogout: ({required String accountId, required AuthenticatedProbePhase phase}) =>
            unregisterAndLogoutProbe(
              accountId: accountId,
              phase: phase,
              status: getIt<BridgeStatusTracker>(),
              logout: getIt<DesktopLogoutOrchestrator>(),
            ),
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
    await report.writeAsString("FAIL ${phase.name} (${error.runtimeType})\n");
    exit(1);
  }
}

String _readPrivateLine() {
  final value = stdin.readLineSync();
  if (value == null || value.isEmpty) throw StateError("Missing private fixture input");
  return value;
}

void _require({required bool condition, required String message}) {
  if (!condition) throw StateError(message);
}
