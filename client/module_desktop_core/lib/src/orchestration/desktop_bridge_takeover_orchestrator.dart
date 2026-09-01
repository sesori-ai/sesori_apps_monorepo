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
import "../trackers/desktop_logout_tracker.dart";

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
  required final DesktopLogoutTracker _logoutTracker,
  required final Duration _startupObservationTimeout,
}) {
  new({
    required BridgeProcessService processService,
    required ControlCommandService controlCommandService,
    required DesktopInstanceService instanceService,
    required BridgePromptTracker promptTracker,
    required BridgeStatusTracker statusTracker,
    required DesktopLogoutTracker logoutTracker,
  }) : this.forTesting(
         processService: processService,
         controlCommandService: controlCommandService,
         instanceService: instanceService,
         promptTracker: promptTracker,
         statusTracker: statusTracker,
         logoutTracker: logoutTracker,
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
    if (_logoutInProgress) {
      return;
    }
    // Persist the user's intent before stopping anything. A failed write leaves
    // the current helper untouched and gives the caller a retryable failure.
    await _instanceService.writeBridgeDesiredState(state: BridgeProcessDesiredState.on);
    if (_logoutInProgress) {
      return;
    }
    await _processService.stop();
    // Logout may join this ordinary stop. Its persisted Off and credential
    // clearing must win instead of this continuation respawning a helper.
    if (_logoutInProgress) {
      return;
    }
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
    _logoutTracker.statuses
        .where((status) => status.locksBridgeControls)
        .listen((_) => settleStartup())
        .addTo(subscriptions);

    try {
      // Ignore the replayed pre-takeover snapshot. Only states emitted after
      // this subscription belong to the fresh start and may settle its window.
      _processService.states
          .skip(1)
          .listen((state) {
            if (_isTerminalBeforeRegistration(state: state)) {
              settleStartup();
            }
          })
          .addTo(subscriptions);
      final Future<void> startOperation = _processService.start();
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

  bool get _logoutInProgress => _logoutTracker.status.locksBridgeControls;

  void _acceptReplacementPrompts({required List<ControlPromptRequest> prompts}) {
    if (_logoutInProgress) {
      return;
    }
    for (final ControlPromptRequest prompt in prompts) {
      if (prompt.kind != ControlPromptKind.replaceBridge ||
          !_promptTracker.prompts.any((pending) => identical(pending, prompt))) {
        continue;
      }
      try {
        _controlCommandService.answerPrompt(prompt: prompt, accepted: true);
      } on Object catch (error, stackTrace) {
        logw("Failed to accept the desktop bridge takeover prompt", error, stackTrace);
      }
      return;
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
