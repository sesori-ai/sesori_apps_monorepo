import "dart:async";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/bridge_process_desired_state.dart";
import "../services/bridge_process_service.dart";
import "../services/bridge_process_state.dart";
import "../services/control_command_service.dart";
import "../services/desktop_instance_service.dart";
import "../trackers/bridge_prompt_tracker.dart";
import "../trackers/bridge_status_tracker.dart";

/// Layer-4 owner of the explicit desktop bridge takeover action.
///
/// A takeover is a deliberate stop-and-respawn. While the fresh helper is
/// negotiating local single-bridge ownership, this coordinator accepts only
/// its replacement prompts; ordinary starts remain non-interactive and still
/// fail closed when another bridge is present. The persisted desired state is
/// set to On before teardown so a failed or completed takeover remains
/// recoverable on the next app launch.
@lazySingleton
class DesktopBridgeTakeoverOrchestrator.forTesting({
  required final BridgeProcessService _processService,
  required final ControlCommandService _controlCommandService,
  required final DesktopInstanceService _instanceService,
  required final BridgePromptTracker _promptTracker,
  required final BridgeStatusTracker _statusTracker,
  required final Duration _startupObservationTimeout,
}) {
  new({
    required BridgeProcessService processService,
    required ControlCommandService controlCommandService,
    required DesktopInstanceService instanceService,
    required BridgePromptTracker promptTracker,
    required BridgeStatusTracker statusTracker,
  }) : this.forTesting(
         processService: processService,
         controlCommandService: controlCommandService,
         instanceService: instanceService,
         promptTracker: promptTracker,
         statusTracker: statusTracker,
         startupObservationTimeout: const Duration(minutes: 2),
       );

  @visibleForTesting
  this;

  Future<void>? _activeTakeover;

  /// Starts one explicit takeover operation. Concurrent callers join the same
  /// stop-and-respawn rather than issuing competing lifecycle commands.
  Future<void> takeOver() {
    final Future<void>? existing = _activeTakeover;
    if (existing != null) {
      return existing;
    }
    final Future<void> rawOperation = _performTakeover();
    late final Future<void> operation;
    operation = rawOperation.whenComplete(() {
      if (identical(_activeTakeover, operation)) {
        _activeTakeover = null;
      }
    });
    _activeTakeover = operation;
    return operation;
  }

  Future<void> _performTakeover() async {
    // Persist the user's intent before stopping anything. A failed write leaves
    // the current helper untouched and gives the caller a retryable failure.
    await _instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.on);
    await _processService.stop();
    // Prompts belong to a helper connection. Clear any prompt left by the
    // displaced helper before subscribing for the fresh spawn so takeover can
    // never answer an old replacement request.
    _promptTracker.clear();

    final Completer<void> startupSettled = Completer<void>();
    void settleStartup() {
      if (!startupSettled.isCompleted) {
        startupSettled.complete();
      }
    }

    final CompositeSubscription subscriptions = CompositeSubscription();
    _promptTracker.promptsStream.listen((prompts) => _acceptReplacementPrompts(prompts: prompts)).addTo(subscriptions);
    _statusTracker.registrationEvents.listen((_) => settleStartup()).addTo(subscriptions);

    try {
      // start() publishes Starting synchronously before its first await, so a
      // state subscription installed immediately after this call observes only
      // the fresh operation's later terminal states, not the prior contention
      // snapshot.
      final Future<void> startOperation = _processService.start();
      _processService.states
          .listen((state) {
            if (_isTerminalBeforeRegistration(state: state)) {
              settleStartup();
            }
          })
          .addTo(subscriptions);
      await startOperation;
      try {
        await startupSettled.future.timeout(_startupObservationTimeout);
      } on TimeoutException catch (error, stackTrace) {
        // The helper owns its own bounded prompt timeout and retry policy. The
        // GUI only needs to stop approving prompts once this observation window
        // ends; the process service remains the lifecycle authority.
        logw("Desktop bridge takeover did not reach registration before the observation deadline", error, stackTrace);
      }
    } finally {
      await subscriptions.cancel();
    }
  }

  void _acceptReplacementPrompts({required List<ControlPromptRequest> prompts}) {
    for (final ControlPromptRequest prompt in prompts) {
      if (prompt.kind != ControlPromptKind.replaceBridge) {
        continue;
      }
      try {
        _controlCommandService.answerPrompt(prompt: prompt, accepted: true);
      } on Object catch (error, stackTrace) {
        logw("Failed to accept the desktop bridge takeover prompt", error, stackTrace);
      }
    }
  }

  static bool _isTerminalBeforeRegistration({required BridgeProcessState state}) {
    return switch (state) {
      BridgeProcessStopped() ||
      BridgeProcessLoginRequired() ||
      BridgeProcessContention() ||
      BridgeProcessCrashGiveUp() => true,
      BridgeProcessStarting() ||
      BridgeProcessRunning() ||
      BridgeProcessStopping() ||
      BridgeProcessCrashRetryScheduled() => false,
    };
  }
}
