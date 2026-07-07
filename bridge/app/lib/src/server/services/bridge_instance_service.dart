import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';

import '../foundation/bridge_replace_prompt.dart';
import '../foundation/process_match.dart';
import '../foundation/terminal_prompt_decision.dart';
import '../models/bridge_startup_lock.dart';
import '../repositories/bridge_instance_repository.dart';
import '../repositories/process_repository.dart';

const Duration _bridgeShutdownWait = Duration(seconds: 5);

enum BridgeInstanceResolutionStatus { allowed, declined, nonInteractive }

class BridgeInstanceResolution {
  const BridgeInstanceResolution({
    required this.status,
    required this.existingBridges,
    required this.terminatedBridges,
  });

  final BridgeInstanceResolutionStatus status;
  final List<ProcessIdentity> existingBridges;
  final List<ProcessIdentity> terminatedBridges;
}

class BridgeInstanceService {
  BridgeInstanceService({
    required BridgeInstanceRepository bridgeInstanceRepository,
    required BridgeReplacePrompt replacePrompt,
    required ProcessRepository processRepository,
    required ServerClock clock,
  }) : _bridgeInstanceRepository = bridgeInstanceRepository,
       _replacePrompt = replacePrompt,
       _processRepository = processRepository,
       _clock = clock;

  final BridgeInstanceRepository _bridgeInstanceRepository;
  final BridgeReplacePrompt _replacePrompt;
  final ProcessRepository _processRepository;
  final ServerClock _clock;

  /// Waits for a restart predecessor (the bridge that spawned this one) to
  /// exit before single-live-bridge enforcement runs, so a restart hands off
  /// cleanly instead of prompting/aborting on the still-exiting predecessor.
  ///
  /// Polls the predecessor's identity on a short interval — a bounded startup
  /// wait, not data polling — and returns as soon as it is gone (or no longer a
  /// Sesori bridge), or when [timeout] elapses.
  Future<void> awaitPredecessorBridgeExit({
    required int predecessorPid,
    required Duration timeout,
  }) async {
    final DateTime deadline = _clock.now().add(timeout);
    while (true) {
      final ProcessMatch? match;
      try {
        match = await _processRepository.inspectProcessMatch(pid: predecessorPid);
      } on Object catch (error, stackTrace) {
        // A transient process-inspection failure (e.g. ps/tasklist erroring)
        // must not hard-fail startup. Stop waiting and let single-live-bridge
        // enforcement take over.
        Log.w('Failed to inspect restart predecessor pid $predecessorPid; proceeding', error, stackTrace);
        return;
      }
      // We were handed the exact predecessor pid, so matching it to a live
      // Sesori bridge is sufficient. We deliberately do NOT also require
      // `isCurrentUserProcess`: when the current user can't be resolved (the
      // runner allows that), every match is flagged as not-current-user, which
      // would make us treat the still-running predecessor as gone and race it.
      final bool stillLive = match != null && match.kind == ProcessMatchKind.sesoriBridge;
      if (!stillLive) {
        return;
      }
      if (!_clock.now().isBefore(deadline)) {
        Log.w(
          'Restart predecessor pid $predecessorPid still running after ${timeout.inSeconds}s; '
          'proceeding with single-live-bridge enforcement.',
        );
        return;
      }
      await _clock.delay(duration: const Duration(milliseconds: 250));
    }
  }

  Future<BridgeInstanceResolution> enforceSingleLiveBridge({required int currentPid}) async {
    final existingBridges = await _bridgeInstanceRepository.listLiveBridgeCandidates(currentPid: currentPid);
    if (existingBridges.isEmpty) {
      return const BridgeInstanceResolution(
        status: BridgeInstanceResolutionStatus.allowed,
        existingBridges: <ProcessIdentity>[],
        terminatedBridges: <ProcessIdentity>[],
      );
    }

    final decision = await _replacePrompt.askReplaceExistingBridge(bridgeCount: existingBridges.length);
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
        final terminatedBridges = await terminateBridges(
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

  Future<BridgeInstanceResolutionStatus> resolveStartupLockContention({
    required BridgeStartupLock lock,
    required ProcessMatch holder,
    required int currentPid,
  }) async {
    if (lock.bridgePid == currentPid) {
      return BridgeInstanceResolutionStatus.allowed;
    }

    final decision = await _replacePrompt.askReplaceStartingBridge(holderPid: holder.identity.pid);
    switch (decision) {
      case TerminalPromptDecision.nonInteractive:
        return BridgeInstanceResolutionStatus.nonInteractive;
      case TerminalPromptDecision.decline:
        return BridgeInstanceResolutionStatus.declined;
      case TerminalPromptDecision.replace:
        final revalidated = await _processRepository.inspectProcessMatch(pid: lock.bridgePid);
        if (revalidated == null) {
          return BridgeInstanceResolutionStatus.allowed;
        }
        if (!_matchesLockedBridge(lock: lock, match: revalidated)) {
          Log.w(
            'Startup lock holder pid ${lock.bridgePid} no longer matches the recorded Sesori bridge; treating the lock as stale without signaling.',
          );
          return BridgeInstanceResolutionStatus.allowed;
        }

        try {
          await _processRepository.sendGracefulSignal(pid: lock.bridgePid);
        } on Object catch (err, st) {
          Log.w('Failed to send graceful signal to startup lock holder pid ${lock.bridgePid}', err, st);
        }
        await _clock.delay(duration: _bridgeShutdownWait);

        final afterGraceful = await _processRepository.inspectProcessMatch(pid: lock.bridgePid);
        if (afterGraceful == null || !_matchesLockedBridge(lock: lock, match: afterGraceful)) {
          return BridgeInstanceResolutionStatus.allowed;
        }

        try {
          await _processRepository.sendForceSignal(pid: lock.bridgePid);
        } on Object catch (err, st) {
          Log.w('Failed to send force signal to startup lock holder pid ${lock.bridgePid}', err, st);
        }
        await _clock.delay(duration: const Duration(seconds: 1));

        final afterForce = await _processRepository.inspectProcessMatch(pid: lock.bridgePid);
        if (afterForce == null || !_matchesLockedBridge(lock: lock, match: afterForce)) {
          return BridgeInstanceResolutionStatus.allowed;
        }

        Log.e('Failed to kill Sesori bridge startup lock holder pid ${lock.bridgePid}');
        return BridgeInstanceResolutionStatus.declined;
    }
  }

  Future<List<ProcessIdentity>> terminateBridges({
    required int currentPid,
    required List<ProcessIdentity> existingBridges,
  }) async {
    if (existingBridges.isEmpty) {
      // early exit ; nothing to stop
      return existingBridges;
    }

    final terminatedBridges = <ProcessIdentity>[];

    // send graceful termination for all bridges
    try {
      await Future.wait(
        existingBridges.map((bridge) => _processRepository.sendGracefulSignal(pid: bridge.pid)),
      ).timeout(_bridgeShutdownWait);
    } catch (err, st) {
      Log.w("Failed to gracefully stop existing bridge(s)", err, st);
    }

    // Always wait for graceful shutdown, even if some signals failed.
    await _clock.delay(duration: _bridgeShutdownWait);

    final bridgesThatSurvivedGracefulShutdown = await _bridgeInstanceRepository.listLiveBridgeCandidates(
      currentPid: currentPid,
    );

    if (bridgesThatSurvivedGracefulShutdown.isEmpty) {
      // All bridges shutdown
      return existingBridges;
    }

    // some bridges did not gracefully terminate so we need to force kill them
    var forceSignalsSent = false;
    for (final bridge in existingBridges) {
      if (_containsSameIdentity(candidates: bridgesThatSurvivedGracefulShutdown, bridge: bridge)) {
        forceSignalsSent = true;
        try {
          await _processRepository.sendForceSignal(pid: bridge.pid).timeout(_bridgeShutdownWait);
        } catch (err, st) {
          Log.w("Failed to force kill existing bridge", err, st);
        }
      }
    }

    final bridgesThatSurvivedForcedShutdown = forceSignalsSent
        ? await _bridgeInstanceRepository.listLiveBridgeCandidates(currentPid: currentPid)
        : bridgesThatSurvivedGracefulShutdown;

    final List<ProcessIdentity> bridgesThatSurvivedAllKillAttempts = [];
    for (final bridge in existingBridges) {
      if (!_containsPid(candidates: bridgesThatSurvivedForcedShutdown, pid: bridge.pid)) {
        terminatedBridges.add(bridge);
      } else {
        bridgesThatSurvivedAllKillAttempts.add(bridge);
      }
    }

    if (bridgesThatSurvivedAllKillAttempts.isNotEmpty) {
      Log.e("Failed to kill ${bridgesThatSurvivedAllKillAttempts.length} running bridges");
    }

    return terminatedBridges;
  }

  bool _containsSameIdentity({
    required List<ProcessIdentity> candidates,
    required ProcessIdentity bridge,
  }) => candidates.any(bridge.hasSameIdentityAs);

  bool _containsPid({
    required List<ProcessIdentity> candidates,
    required int pid,
  }) {
    return candidates.any((candidate) => candidate.pid == pid);
  }

  bool _matchesLockedBridge({
    required BridgeStartupLock lock,
    required ProcessMatch match,
  }) {
    if (match.kind != ProcessMatchKind.sesoriBridge || !match.isCurrentUserProcess) {
      return false;
    }

    return lock.matchesStartMarkerOf(identity: match.identity);
  }
}
