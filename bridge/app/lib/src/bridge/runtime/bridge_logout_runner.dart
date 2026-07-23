import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../../repositories/app_onboarding_state_repository.dart';
import '../../server/foundation/terminal_prompt_decision.dart';
import '../../server/repositories/bridge_instance_repository.dart';
import '../../server/repositories/terminal_prompt_repository.dart';
import '../../server/services/bridge_instance_service.dart';

enum BridgeLogoutStatus {
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

class BridgeLogoutResult {
  const BridgeLogoutResult({
    required this.status,
    this.runningBridgeCount = 0,
    this.error,
  });

  final BridgeLogoutStatus status;
  final int runningBridgeCount;
  final Object? error;
}

class BridgeLogoutRunner {
  BridgeLogoutRunner({
    required BridgeInstanceRepository bridgeInstanceRepository,
    required BridgeInstanceService bridgeInstanceService,
    required TerminalPromptRepository terminalPromptRepository,
    required Future<void> Function() unregisterBridge,
    required AppOnboardingStateRepository appOnboardingStateRepository,
    required Future<void> Function() clearTokens,
  }) : _bridgeInstanceRepository = bridgeInstanceRepository,
       _bridgeInstanceService = bridgeInstanceService,
       _terminalPromptRepository = terminalPromptRepository,
       _unregisterBridge = unregisterBridge,
       _appOnboardingStateRepository = appOnboardingStateRepository,
       _clearTokens = clearTokens;

  final BridgeInstanceRepository _bridgeInstanceRepository;
  final BridgeInstanceService _bridgeInstanceService;
  final TerminalPromptRepository _terminalPromptRepository;
  final Future<void> Function() _unregisterBridge;
  final AppOnboardingStateRepository _appOnboardingStateRepository;
  final Future<void> Function() _clearTokens;

  Future<BridgeLogoutResult> logout({required int currentPid}) async {
    final existingBridges = await _bridgeInstanceRepository.listLiveBridgeCandidates(currentPid: currentPid);

    var runningBridgeCount = 0;
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

    return _clearStoredState(runningBridgeCount: runningBridgeCount);
  }

  /// Clears one custom data directory after its source-run bridge has stopped.
  ///
  /// Source-run bridges are not part of native bridge process discovery. This
  /// path therefore skips host-wide termination so logging out a test account
  /// cannot stop an unrelated packaged bridge.
  Future<BridgeLogoutResult> logoutStoppedBridge() {
    return _clearStoredState(runningBridgeCount: 0);
  }

  Future<BridgeLogoutResult> _clearStoredState({required int runningBridgeCount}) async {
    try {
      await _appOnboardingStateRepository.clearAll();
    } on Object catch (error) {
      return BridgeLogoutResult(
        status: BridgeLogoutStatus.failed,
        runningBridgeCount: runningBridgeCount,
        error: error,
      );
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
