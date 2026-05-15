import '../foundation/bridge_instance_candidate.dart';
import '../foundation/process_identity.dart';
import '../foundation/server_clock.dart';
import '../foundation/terminal_prompt_decision.dart';
import '../repositories/bridge_instance_repository.dart';
import '../repositories/process_repository.dart';
import '../repositories/terminal_prompt_repository.dart';

const Duration _bridgeShutdownWait = Duration(seconds: 5);

enum BridgeInstanceResolutionStatus { allowed, declined, nonInteractive }

class BridgeInstanceResolution {
  const BridgeInstanceResolution({
    required this.status,
    required this.existingBridges,
    required this.terminatedBridges,
  });

  final BridgeInstanceResolutionStatus status;
  final List<BridgeInstanceCandidate> existingBridges;
  final List<ProcessIdentity> terminatedBridges;
}

class BridgeInstanceService {
  BridgeInstanceService({
    required BridgeInstanceRepository bridgeInstanceRepository,
    required TerminalPromptRepository terminalPromptRepository,
    required ProcessRepository processRepository,
    required ServerClock clock,
  }) : _bridgeInstanceRepository = bridgeInstanceRepository,
       _terminalPromptRepository = terminalPromptRepository,
       _processRepository = processRepository,
       _clock = clock;

  final BridgeInstanceRepository _bridgeInstanceRepository;
  final TerminalPromptRepository _terminalPromptRepository;
  final ProcessRepository _processRepository;
  final ServerClock _clock;

  Future<BridgeInstanceResolution> enforceSingleLiveBridge({required int currentPid}) async {
    final existingBridges = await _bridgeInstanceRepository.listLiveBridgeCandidates(currentPid: currentPid);
    if (existingBridges.isEmpty) {
      return const BridgeInstanceResolution(
          status: BridgeInstanceResolutionStatus.allowed,
          existingBridges: <BridgeInstanceCandidate>[],
          terminatedBridges: <ProcessIdentity>[],
      );
    }

    final decision = await _terminalPromptRepository.askReplaceExistingBridge(bridgeCount: existingBridges.length);
    switch (decision) {
      case TerminalPromptDecision.nonInteractive:
        return BridgeInstanceResolution(
          status: BridgeInstanceResolutionStatus.nonInteractive,
          existingBridges: existingBridges,
          terminatedBridges: const <ProcessIdentity>[],
        );
      case TerminalPromptDecision.decline:
        return BridgeInstanceResolution(
          status: BridgeInstanceResolutionStatus.declined,
          existingBridges: existingBridges,
          terminatedBridges: const <ProcessIdentity>[],
        );
      case TerminalPromptDecision.replace:
        final terminatedBridges = await _terminateExistingBridges(
          currentPid: currentPid,
          existingBridges: existingBridges,
        );
        return BridgeInstanceResolution(
          status: BridgeInstanceResolutionStatus.allowed,
          existingBridges: existingBridges,
          terminatedBridges: terminatedBridges,
        );
    }
  }

  Future<List<ProcessIdentity>> _terminateExistingBridges({
    required int currentPid,
    required List<BridgeInstanceCandidate> existingBridges,
  }) async {
    final terminatedBridges = <ProcessIdentity>[];
    for (final bridge in existingBridges) {
      await _processRepository.sendGracefulSignal(pid: bridge.pid);
      await _clock.delay(duration: _bridgeShutdownWait);

      var liveBridges = await _bridgeInstanceRepository.listLiveBridgeCandidates(currentPid: currentPid);
      if (_containsSameIdentity(candidates: liveBridges, bridge: bridge)) {
        await _processRepository.sendForceSignal(pid: bridge.pid);
        liveBridges = await _bridgeInstanceRepository.listLiveBridgeCandidates(currentPid: currentPid);
      }

      if (!_containsPid(candidates: liveBridges, pid: bridge.pid)) {
        terminatedBridges.add(_toIdentity(candidate: bridge));
      }
    }
    return terminatedBridges;
  }

  bool _containsSameIdentity({
    required List<BridgeInstanceCandidate> candidates,
    required BridgeInstanceCandidate bridge,
  }) {
    return candidates.any((candidate) => _isSameIdentity(candidate: candidate, bridge: bridge));
  }

  bool _containsPid({
    required List<BridgeInstanceCandidate> candidates,
    required int pid,
  }) {
    return candidates.any((candidate) => candidate.pid == pid);
  }

  bool _isSameIdentity({
    required BridgeInstanceCandidate candidate,
    required BridgeInstanceCandidate bridge,
  }) {
    if (candidate.pid != bridge.pid) {
      return false;
    }
    if (bridge.startMarker != null || candidate.startMarker != null) {
      return candidate.startMarker == bridge.startMarker;
    }
    return candidate.commandLine == bridge.commandLine && candidate.executablePath == bridge.executablePath;
  }

  ProcessIdentity _toIdentity({required BridgeInstanceCandidate candidate}) {
    return ProcessIdentity(
      pid: candidate.pid,
      startMarker: candidate.startMarker,
      executablePath: candidate.executablePath,
      commandLine: candidate.commandLine,
      ownerUser: candidate.ownerUser,
      platform: candidate.platform,
      capturedAt: candidate.capturedAt,
    );
  }
}
