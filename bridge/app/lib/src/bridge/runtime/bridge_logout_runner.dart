import 'dart:io';

import '../../auth/token.dart' as token_store;
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

  /// Deleting the token file failed; tokens may still be present.
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
    Future<void> Function() clearTokens = token_store.clearTokens,
  }) : _bridgeInstanceRepository = bridgeInstanceRepository,
       _bridgeInstanceService = bridgeInstanceService,
       _terminalPromptRepository = terminalPromptRepository,
       _clearTokens = clearTokens;

  final BridgeInstanceRepository _bridgeInstanceRepository;
  final BridgeInstanceService _bridgeInstanceService;
  final TerminalPromptRepository _terminalPromptRepository;
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
      status: runningBridgeCount > 0
          ? BridgeLogoutStatus.loggedOutWithRunningBridges
          : BridgeLogoutStatus.loggedOut,
      runningBridgeCount: runningBridgeCount,
    );
  }
}
