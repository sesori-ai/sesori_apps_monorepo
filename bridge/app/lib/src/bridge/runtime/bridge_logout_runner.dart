import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../../repositories/app_onboarding_state_repository.dart';
import '../../server/foundation/terminal_prompt_decision.dart';
import '../../server/repositories/bridge_instance_repository.dart';
import '../../server/repositories/terminal_prompt_repository.dart';
import '../../server/services/bridge_instance_service.dart';

enum BridgeLogoutStatus() {
  /// Tokens cleared; no bridge instances left running.
  loggedOut,

  /// Tokens cleared, but bridge instances are still running and may
  /// re-persist tokens when they refresh their session.
  loggedOutWithRunningBridges,

  /// User declined to stop running bridges; tokens were not cleared.
  cancelled,

  /// Deleting onboarding state or the token file failed; tokens may still be present.
  failed,
}

class const BridgeLogoutResult({
    required final BridgeLogoutStatus status,
    final int runningBridgeCount = 0,
    final Object? error,
  });

class BridgeLogoutRunner({
    required final BridgeInstanceRepository _bridgeInstanceRepository,
    required final BridgeInstanceService _bridgeInstanceService,
    required final TerminalPromptRepository _terminalPromptRepository,
    required final Future<void> Function() _unregisterBridge,
    required final Future<void> Function() _cleanupBridgeClaims,
    required final AppOnboardingStateRepository _appOnboardingStateRepository,
    required final Future<void> Function() _clearTokens,
  }) {
  Future<BridgeLogoutResult> logout({
    required int currentPid,
    required bool manageRunningBridges,
  }) async {
    var runningBridgeCount = 0;
    if (manageRunningBridges) {
      final existingBridges = await _bridgeInstanceRepository.listLiveBridgeCandidates(currentPid: currentPid);
      if (existingBridges.isNotEmpty) {
        final decision = await _terminalPromptRepository.askStopBridgesBeforeLogout(
          bridgeCount: existingBridges.length,
        );
        switch (decision) {
          case TerminalPromptDecision.decline:
            return BridgeLogoutResult(
              status: BridgeLogoutStatus.cancelled,
              runningBridgeCount: existingBridges.length,
            );
          case TerminalPromptDecision.nonInteractive:
            runningBridgeCount = existingBridges.length;
          case TerminalPromptDecision.replace:
            final terminatedBridges = await _bridgeInstanceService.terminateBridges(
              currentPid: currentPid,
              existingBridges: existingBridges,
            );
            runningBridgeCount = existingBridges.length - terminatedBridges.length;
        }
      }
    }

    try {
      await _appOnboardingStateRepository.clearAll();
    } on Object catch (error) {
      return BridgeLogoutResult(
        status: BridgeLogoutStatus.failed,
        runningBridgeCount: runningBridgeCount,
        error: error,
      );
    }

    try {
      await _cleanupBridgeClaims();
    } on Object catch (error, stackTrace) {
      Log.w('Failed to remove local Device Canvas claims during logout (ignored)', error, stackTrace);
    }

    // Best-effort: remove this bridge's registration on the auth server while
    // we still have tokens. Logout must never block or fail because of this.
    try {
      await _unregisterBridge();
    } on Object catch (error, stackTrace) {
      Log.w('Failed to remove bridge registration on auth server (ignored)', error, stackTrace);
    }

    try {
      await _clearTokens();
    } on FileSystemException catch (error) {
      return BridgeLogoutResult(
        status: BridgeLogoutStatus.failed,
        runningBridgeCount: runningBridgeCount,
        error: error,
      );
    }

    return BridgeLogoutResult(
      status: runningBridgeCount > 0 ? BridgeLogoutStatus.loggedOutWithRunningBridges : BridgeLogoutStatus.loggedOut,
      runningBridgeCount: runningBridgeCount,
    );
  }
}
