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
}

Future<void> exerciseAuthenticatedProbe({
  required AuthenticatedProbePhase phase,
  required AuthSession auth,
  required DesktopInstanceService instance,
  required String Function() readInput,
}) async {
  final String email = readInput();
  if (phase == AuthenticatedProbePhase.loginOn) {
    _require(condition: !await auth.hasLocallyValidSession(), message: "Fixture already has a session");
    await auth.loginWithEmail(email: email, password: readInput());
  } else {
    // Never log in again or refresh before checking replacement preservation.
    _require(condition: await auth.hasLocallyValidSession(), message: "Persisted session is unavailable");
    _require(condition: await auth.restoreLocalSession(), message: "Local account restoration failed");
  }
  final state = auth.currentState;
  _require(
    condition:
        state is AuthAuthenticated && state.user.provider == AuthProvider.email && state.user.providerUserId == email,
    message: "Stored account differs from the dedicated QA account",
  );
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
      await _requireIntent(instance: instance, expected: BridgeProcessDesiredState.on);
      await auth.logoutCurrentDevice(); // Never invalidate other devices' sessions.
      _require(condition: !await auth.hasLocallyValidSession(), message: "Fixture logout failed");
  }
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
      await exerciseAuthenticatedProbe(
        phase: phase,
        auth: getIt<AuthSession>(),
        instance: getIt<DesktopInstanceService>(),
        readInput: _readPrivateLine,
      );
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
