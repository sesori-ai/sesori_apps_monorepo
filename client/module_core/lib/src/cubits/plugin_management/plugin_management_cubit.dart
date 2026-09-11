import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../platform/url_launcher.dart";
import "../../repositories/models/plugin_management_result.dart";
import "../../services/catalog_rescan_service.dart";
import "../../services/models/catalog_rescan_state.dart";
import "../../services/models/plugin_install_state.dart";
import "../../services/plugin_management_service.dart";
import "plugin_management_state.dart";

class PluginManagementCubit({
  required final PluginManagementService _service,
  required final UrlLauncher _urlLauncher,
  required final CatalogRescanService _catalogRescanService,
}) extends Cubit<PluginManagementState> {
  this : super(const PluginManagementState.loading()) {
    _subscriptions
      ..add(_service.snapshots.listen((snapshot) => _onSnapshot(snapshot: snapshot)))
      ..add(_service.installStates.listen((installs) => _onInstallStates(installs: installs)))
      ..add(_service.authenticationTerminal.listen(_onAuthenticationTerminal))
      ..add(_service.authenticationBrowserStates.listen(_onAuthenticationBrowserStates))
      ..add(_catalogRescanService.state.listen(_onCatalogScan));
  }

  final CompositeSubscription _subscriptions = CompositeSubscription();

  /// Harnesses this screen has started a scan for and not yet heard back about.
  ///
  /// A set rather than a flag, because more than one card can be started before
  /// the first finishes: a second harness being refused must not cancel the
  /// first harness's claim on the outcome. Only a run this screen began is
  /// announced here — a scan a list's pull started is already reported by the
  /// row above that list, and announcing it again on an unrelated screen would
  /// report one run in two places.
  final Set<String> _scanClaims = {};
  int _authenticationGeneration = 0;

  Future<void> refresh() => _service.refresh();

  Future<void> startAuthentication({required String pluginId}) async {
    final current = state;
    if (isClosed || current is! PluginManagementReady) return;
    if (current.authentication is! PluginAuthenticationPresentationIdle &&
        current.authentication is! PluginAuthenticationPresentationFailed &&
        current.authentication is! PluginAuthenticationPresentationSucceeded &&
        current.authentication is! PluginAuthenticationPresentationCancelled) {
      return;
    }
    if (current.harnessControlsBlocked(pluginId: pluginId)) return;
    final generation = ++_authenticationGeneration;
    emit(
      current.copyWith(
        authentication: PluginAuthenticationPresentationState.starting(pluginId: pluginId),
      ),
    );
    final result = await _service.startAuthentication(pluginId: pluginId);
    if (isClosed) return;
    final latest = state;
    if (latest is! PluginManagementReady) return;
    final currentAuthentication = latest.authentication;
    if (generation != _authenticationGeneration ||
        currentAuthentication is! PluginAuthenticationPresentationStarting ||
        currentAuthentication.pluginId != pluginId) {
      return;
    }
    switch (result) {
      case PluginAuthenticationStartChallenge():
        final challenge = _service.authenticationChallenges.valueOrNull?[pluginId];
        final presentation = challenge == null ? null : _presentationForChallenge(challenge);
        if (presentation == null) {
          _setAuthenticationFailure(
            pluginId: pluginId,
            error: const PluginAuthenticationPresentationError.invalidChallenge(),
          );
          return;
        }
        _setAuthentication(
          challenge is PluginAuthenticationBrowserChallenge
              ? _browserPresentation(
                  pluginId: pluginId,
                  challenge: challenge,
                  browserState: _service.authenticationBrowserStates.valueOrNull?[pluginId],
                )
              : PluginAuthenticationPresentationState.challenge(pluginId: pluginId, challenge: presentation),
        );
      case PluginAuthenticationStartFailed(:final failure):
        _setAuthenticationFailure(
          pluginId: pluginId,
          error: _presentationErrorFor(failure: failure),
        );
    }
  }

  Future<void> launchAuthenticationBrowser() async {
    final current = state;
    if (isClosed || current is! PluginManagementReady) return;
    final challenge = _authenticationChallengeData(current.authentication);
    if (challenge == null) return;
    switch (challenge.challenge) {
      case PluginAuthenticationBrowserChallenge():
        if (current.authentication is PluginAuthenticationPresentationBrowserLaunchFailedState) {
          await _service.retryBrowserAuthentication(pluginId: challenge.pluginId);
        }
      case PluginAuthenticationDeviceCodeChallenge(:final verificationUri):
        final generation = _authenticationGeneration;
        bool launched;
        try {
          launched = await _urlLauncher.launch(verificationUri);
        } on Object {
          launched = false;
        }
        if (isClosed || launched || generation != _authenticationGeneration) return;
        final latest = state;
        if (latest is! PluginManagementReady) return;
        final latestChallenge = _authenticationChallengeData(latest.authentication);
        if (latestChallenge?.pluginId != challenge.pluginId || latestChallenge?.challenge != challenge.challenge) {
          return;
        }
        if (latest.authentication is! PluginAuthenticationPresentationChallenge &&
            latest.authentication is! PluginAuthenticationPresentationBrowserLaunchFailedState) {
          return;
        }
        _setAuthentication(
          PluginAuthenticationPresentationState.browserLaunchFailed(
            pluginId: challenge.pluginId,
            challenge: challenge.challenge,
          ),
        );
      case PluginAuthenticationUnsupportedChallenge():
        return;
    }
  }

  Future<void> cancelAuthentication() async {
    final current = state;
    if (isClosed || current is! PluginManagementReady) return;
    if (current.authentication is PluginAuthenticationPresentationCancelling) return;
    final challenge = _authenticationChallengeData(current.authentication);
    if (challenge == null) return;
    final generation = _authenticationGeneration;
    _setAuthentication(
      PluginAuthenticationPresentationState.cancelling(
        pluginId: challenge.pluginId,
        challenge: challenge.challenge,
      ),
    );
    final result = await _service.cancelAuthentication(pluginId: challenge.pluginId);
    final latestAuthentication = switch (state) {
      PluginManagementReady(:final authentication) => authentication,
      PluginManagementLoading() || PluginManagementUnsupported() || PluginManagementFailure() => null,
    };
    if (isClosed ||
        generation != _authenticationGeneration ||
        latestAuthentication is! PluginAuthenticationPresentationCancelling ||
        latestAuthentication.pluginId != challenge.pluginId) {
      return;
    }
    switch (result) {
      case PluginAuthenticationCancelSuccess():
        break;
      // An uncertain cancel is not a failure: the request may still have
      // landed, so keep the challenge on screen in its uncertain form.
      case PluginAuthenticationCancelFailed(failure: PluginAuthenticationFailureUncertain()):
        _setAuthentication(
          PluginAuthenticationPresentationState.cancellingUncertain(
            pluginId: challenge.pluginId,
            challenge: challenge.challenge,
          ),
        );
      case PluginAuthenticationCancelFailed(:final failure):
        _setAuthenticationFailure(
          pluginId: challenge.pluginId,
          error: _presentationErrorFor(failure: failure),
        );
    }
  }

  /// Start and cancel present the same failures the same way.
  PluginAuthenticationPresentationError _presentationErrorFor({required PluginAuthenticationFailure failure}) {
    return switch (failure) {
      PluginAuthenticationFailureNotFound() => const PluginAuthenticationPresentationError.notFound(),
      PluginAuthenticationFailureConflict(:final conflict) => PluginAuthenticationPresentationError.conflict(
        conflict: conflict,
      ),
      PluginAuthenticationFailureUnsupported() => const PluginAuthenticationPresentationError.unsupported(),
      PluginAuthenticationFailureUncertain() => const PluginAuthenticationPresentationError.uncertain(),
      PluginAuthenticationFailureRequest(:final error) => PluginAuthenticationPresentationError.request(error: error),
    };
  }

  void dismissAuthentication() => _setAuthentication(const PluginAuthenticationPresentationState.idle());

  Future<void> enable({required String pluginId}) => _runCommand(
    pluginId: pluginId,
    request: const PluginLifecycleCommandRequest.enable(),
    forceAction: null,
    replacePendingConfirmation: false,
  );

  Future<void> disable({required String pluginId}) => _runCommand(
    pluginId: pluginId,
    request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
    forceAction: PluginManagementForceAction.disable,
    replacePendingConfirmation: false,
  );

  Future<void> restart({required String pluginId}) => _runCommand(
    pluginId: pluginId,
    request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
    forceAction: PluginManagementForceAction.restart,
    replacePendingConfirmation: false,
  );

  /// Rescans one harness's catalog, reporting a rejection on its own card.
  ///
  /// Unlike the lists' aggregate scan, the user named this harness, so a
  /// bridge that will not import from it has to say so here rather than let
  /// the fan-out skip it silently.
  Future<void> startCatalogScanFor({required String pluginId}) async {
    if (isClosed || state is! PluginManagementReady) return;
    // Drop any earlier rejection first, so a retry does not read as though it
    // had already failed again before the answer arrives.
    _setScanRejection(pluginId: pluginId, result: null);
    // Claimed before dispatch, not after: the run can reach a terminal state
    // while this request is still awaiting its own response.
    _scanClaims.add(pluginId);
    final result = await _catalogRescanService.start(pluginId: pluginId);
    if (isClosed) return;
    // A harness still in the live operation has no refusal to report. An
    // uncertain start keeps it a member precisely because the request may have
    // landed, so the card would otherwise pair a spinner with a line telling
    // the user to try again. That run belongs to the aggregate row.
    if (result is CatalogRescanStartAccepted || _scanningPluginIds.contains(pluginId)) {
      _setScanRejection(pluginId: pluginId, result: null);
      return;
    }
    // Membership alone cannot tell a refusal from a run that already finished:
    // a definite rejection settles the operation before this call returns, so
    // the harness has left the live set either way. The claim can, because an
    // announced outcome spends it. Without this, a bridge that answers with an
    // error produces both a finished-scan announcement and a could-not-start
    // line on the card for one attempt.
    if (!_scanClaims.remove(pluginId)) return;
    _setScanRejection(pluginId: pluginId, result: result);
  }

  /// Clears an outcome the screen has now reported, so it is announced once.
  void dismissCatalogScanOutcome() {
    final current = state;
    if (isClosed || current is! PluginManagementReady || current.scanOutcome == null) return;
    emit(current.copyWith(scanOutcome: null));
  }

  void _setScanRejection({required String pluginId, required CatalogRescanStartResult? result}) {
    final current = state;
    if (isClosed || current is! PluginManagementReady) return;
    if (current.scanRejections[pluginId] == result) return;
    final next = Map<String, CatalogRescanStartResult>.of(current.scanRejections);
    if (result == null) {
      next.remove(pluginId);
    } else {
      next[pluginId] = result;
    }
    emit(current.copyWith(scanRejections: next));
  }

  /// Installs the harness' managed runtime. The bridge accepts immediately;
  /// phase progress arrives through [PluginManagementReady.installs].
  Future<void> install({required String pluginId}) => _runCommand(
    pluginId: pluginId,
    request: const PluginLifecycleCommandRequest.install(),
    forceAction: null,
    replacePendingConfirmation: false,
  );

  Future<void> refreshSetup({required String pluginId}) => _runCommand(
    pluginId: pluginId,
    request: const PluginLifecycleCommandRequest.refresh(),
    forceAction: null,
    replacePendingConfirmation: false,
  );

  Future<void> applyIdleTimeoutToAll({required PluginManagementIdleTimeoutInput input}) => _runTimeoutPlan(
    target: const PluginManagementActionTarget.allHarnesses(),
    plan: _service.planApplyAllIdleTimeout(input: input),
  );

  Future<void> setIdleTimeoutOverride({
    required String pluginId,
    required PluginManagementIdleTimeoutInput input,
  }) => _runTimeoutPlan(
    target: PluginManagementActionTarget.harness(pluginId: pluginId),
    plan: _service.planSetIdleTimeoutOverride(pluginId: pluginId, input: input),
  );

  Future<void> clearIdleTimeoutOverride({required String pluginId}) => _runTimeoutPlan(
    target: PluginManagementActionTarget.harness(pluginId: pluginId),
    plan: _service.planClearIdleTimeoutOverride(pluginId: pluginId),
  );

  Future<void> confirmForce({required PluginManagementActionForceConfirmationRequired confirmation}) async {
    final target = PluginManagementActionTarget.harness(pluginId: confirmation.pluginId);
    if (!_ownsAction(target: target, action: confirmation)) return;
    await _runCommand(
      pluginId: confirmation.pluginId,
      request: confirmation.request,
      forceAction: null,
      replacePendingConfirmation: true,
    );
  }

  void dismissForceConfirmation({required PluginManagementActionForceConfirmationRequired confirmation}) {
    final target = PluginManagementActionTarget.harness(pluginId: confirmation.pluginId);
    if (!_ownsAction(target: target, action: confirmation)) return;
    _setAction(target: target, action: const PluginManagementActionState.idle());
  }

  void dismissActionError({required PluginManagementActionFailed failure}) {
    if (!_ownsAction(target: failure.target, action: failure)) return;
    _setAction(target: failure.target, action: const PluginManagementActionState.idle());
  }

  void dismissRefreshError() {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady || current.refresh is! PluginManagementRefreshFailed) return;
    emit(current.copyWith(refresh: const PluginManagementRefreshState.idle()));
  }

  Future<void> _runCommand({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
    required PluginManagementForceAction? forceAction,
    required bool replacePendingConfirmation,
  }) async {
    final target = PluginManagementActionTarget.harness(pluginId: pluginId);
    final pending = _beginAction(target: target, replacePendingConfirmation: replacePendingConfirmation);
    if (pending == null) return;

    final result = await _service.command(pluginId: pluginId, request: request);
    if (!_ownsAction(target: target, action: pending)) return;

    _setAction(
      target: target,
      action: _actionStateFor(
        result: result,
        target: target,
        force: forceAction == null ? null : _ForceContext(pluginId: pluginId, action: forceAction),
      ),
    );
  }

  Future<void> _runTimeoutPlan({
    required PluginManagementActionTarget target,
    required PluginManagementCommandPlan plan,
  }) async {
    switch (plan) {
      case PluginManagementCommandPlanInvalidInput():
        _emitImmediateFailure(
          target: target,
          error: const PluginManagementActionError.invalidIdleTimeout(),
        );
      case PluginManagementCommandPlanRequest(:final request):
        final pending = _beginAction(target: target, replacePendingConfirmation: false);
        if (pending == null) return;
        final result = await _service.updateIdleTimeout(request: request);
        if (!_ownsAction(target: target, action: pending)) return;
        // An idle-timeout update offers no force affordance, so a conflict here
        // is simply a failure.
        _setAction(
          target: target,
          action: _actionStateFor(result: result, target: target, force: null),
        );
    }
  }

  /// The one mutation-result to action-state mapping. [force] is non-null only
  /// where the caller can offer a force retry, and carries both values that
  /// offer needs so neither can go missing.
  PluginManagementActionState _actionStateFor({
    required PluginManagementMutationResult result,
    required PluginManagementActionTarget target,
    required _ForceContext? force,
  }) {
    return switch (result) {
      PluginManagementMutationResultSuccess() => const PluginManagementActionState.idle(),
      PluginManagementMutationResultNotFound() => PluginManagementActionState.failed(
        target: target,
        error: const PluginManagementActionError.notFound(),
      ),
      PluginManagementMutationResultConflict(:final conflict) => _conflictActionStateFor(
        conflict: conflict,
        target: target,
        force: force,
      ),
      PluginManagementMutationResultUncertain() => PluginManagementActionState.failed(
        target: target,
        error: const PluginManagementActionError.uncertain(),
      ),
      PluginManagementMutationResultFailure(:final error) => PluginManagementActionState.failed(
        target: target,
        error: PluginManagementActionError.request(error: error),
      ),
    };
  }

  PluginManagementActionState _conflictActionStateFor({
    required PluginLifecycleConflict conflict,
    required PluginManagementActionTarget target,
    required _ForceContext? force,
  }) {
    final failed = PluginManagementActionState.failed(
      target: target,
      error: PluginManagementActionError.conflict(conflict: conflict),
    );
    if (force == null) return failed;
    return switch (_service.assessForce(conflict: conflict, action: force.action)) {
      PluginManagementForceAssessmentRequiresConfirmation(:final request) =>
        PluginManagementActionState.forceConfirmationRequired(
          pluginId: force.pluginId,
          action: force.action,
          conflict: conflict,
          request: request,
        ),
      PluginManagementForceAssessmentNotForceable() => failed,
    };
  }

  bool _canBeginAction({
    required PluginManagementActionTarget target,
    required bool replacePendingConfirmation,
  }) {
    if (isClosed) return false;
    final current = state;
    if (current is! PluginManagementReady) return false;
    final action = current.actionFor(target: target);
    if (action.blocksControls &&
        !(replacePendingConfirmation && action is PluginManagementActionForceConfirmationRequired)) {
      return false;
    }
    switch (target) {
      case PluginManagementActionTargetAllHarnesses():
        if (current.globalControlsBlocked) return false;
      case PluginManagementActionTargetHarness(:final pluginId):
        if (current.globalAction.blocksControls || current.harnessActivityBlocked(pluginId: pluginId)) {
          return false;
        }
    }
    return true;
  }

  PluginManagementActionInProgress? _beginAction({
    required PluginManagementActionTarget target,
    required bool replacePendingConfirmation,
  }) {
    if (!_canBeginAction(target: target, replacePendingConfirmation: replacePendingConfirmation)) return null;
    final pending = PluginManagementActionInProgress(target: target);
    _setAction(target: target, action: pending);
    return pending;
  }

  bool _ownsAction({required PluginManagementActionTarget target, required PluginManagementActionState action}) {
    final current = state;
    return !isClosed && current is PluginManagementReady && identical(current.actionFor(target: target), action);
  }

  void _setAction({required PluginManagementActionTarget target, required PluginManagementActionState action}) {
    final current = state;
    if (isClosed || current is! PluginManagementReady) return;
    switch (target) {
      case PluginManagementActionTargetAllHarnesses():
        emit(current.copyWith(globalAction: action));
      case PluginManagementActionTargetHarness(:final pluginId):
        final actions = Map<String, PluginManagementActionState>.of(current.harnessActions);
        if (action is PluginManagementActionIdle) {
          actions.remove(pluginId);
        } else {
          actions[pluginId] = action;
        }
        emit(current.copyWith(harnessActions: actions));
    }
  }

  void _emitImmediateFailure({
    required PluginManagementActionTarget target,
    required PluginManagementActionError error,
  }) {
    if (!_canBeginAction(target: target, replacePendingConfirmation: false)) return;
    _setAction(
      target: target,
      action: PluginManagementActionState.failed(target: target, error: error),
    );
  }

  void _onSnapshot({required PluginManagementLoadResult snapshot}) {
    if (isClosed) return;
    switch (snapshot) {
      case PluginManagementLoadResultLoading():
        emit(const PluginManagementState.loading());
      case PluginManagementLoadResultSupported(:final response, :final refreshError):
        final previous = switch (state) {
          final PluginManagementReady ready when ready.response.bridgeId == response.bridgeId => ready,
          PluginManagementReady() ||
          PluginManagementLoading() ||
          PluginManagementUnsupported() ||
          PluginManagementFailure() => null,
        };
        // Read the service's current progress rather than the previous state:
        // installs keep running across loading/reconnect transitions and while
        // this cubit is recreated (the screen builds a new one per visit), so
        // seeding from an empty map would hide a live install until its next
        // progress event.
        final installs = _service.installStates.valueOrNull ?? const <String, PluginInstallState>{};
        emit(
          PluginManagementState.ready(
            response: response,
            refresh: switch (refreshError) {
              final error? => PluginManagementRefreshState.failed(error: error),
              null => const PluginManagementRefreshState.idle(),
            },
            globalAction: previous?.globalAction ?? const PluginManagementActionState.idle(),
            harnessActions: previous?.harnessActions ?? const {},
            authentication: switch (state) {
              PluginManagementReady(:final authentication) => authentication,
              PluginManagementLoading() ||
              PluginManagementUnsupported() ||
              PluginManagementFailure() => _reattachedAuthentication(),
            },
            installs: installs,
            // Re-read from the service for the same reason as installs: a scan
            // outlives this cubit, which the screen rebuilds per visit.
            scanningPluginIds: _scanningPluginIds,
            // Carried forward instead, because nothing outside this cubit
            // holds a rejection the user has not read yet.
            scanRejections: switch (state) {
              PluginManagementReady(:final scanRejections) => scanRejections,
              PluginManagementLoading() || PluginManagementUnsupported() || PluginManagementFailure() => const {},
            },
            scanOutcome: switch (state) {
              PluginManagementReady(:final scanOutcome) => scanOutcome,
              PluginManagementLoading() || PluginManagementUnsupported() || PluginManagementFailure() => null,
            },
          ),
        );
      case PluginManagementLoadResultUnsupported():
        emit(const PluginManagementState.unsupported());
      case PluginManagementLoadResultFailure(:final error):
        final current = state;
        final authenticationIsActive = switch (current) {
          PluginManagementReady(:final authentication) => switch (authentication) {
            PluginAuthenticationPresentationStarting() ||
            PluginAuthenticationPresentationChallenge() ||
            PluginAuthenticationPresentationBrowserOpening() ||
            PluginAuthenticationPresentationBrowserWaiting() ||
            PluginAuthenticationPresentationBrowserFinalizing() ||
            PluginAuthenticationPresentationBrowserLaunchFailedState() ||
            PluginAuthenticationPresentationCancelling() ||
            PluginAuthenticationPresentationCancellingUncertain() ||
            PluginAuthenticationPresentationFailed(error: PluginAuthenticationPresentationUncertain()) => true,
            PluginAuthenticationPresentationIdle() ||
            PluginAuthenticationPresentationSucceeded() ||
            PluginAuthenticationPresentationCancelled() ||
            PluginAuthenticationPresentationFailed() => false,
          },
          PluginManagementLoading() || PluginManagementUnsupported() || PluginManagementFailure() => false,
        };
        if (current is PluginManagementReady && authenticationIsActive) {
          // Keep the terminal listener attached to an active login. The service
          // still owns the failed snapshot and rejects mutations until recovery.
          emit(current.copyWith(refresh: PluginManagementRefreshState.failed(error: error)));
        } else {
          emit(PluginManagementState.failure(error: error));
        }
    }
  }

  PluginAuthenticationPresentationState _reattachedAuthentication() {
    final challenges = _service.authenticationChallenges.valueOrNull;
    if (challenges == null || challenges.isEmpty) return const PluginAuthenticationPresentationState.idle();
    final entry = challenges.entries.first;
    return switch (entry.value) {
      final PluginAuthenticationBrowserChallenge challenge => _browserPresentation(
        pluginId: entry.key,
        challenge: challenge,
        browserState: _service.authenticationBrowserStates.valueOrNull?[entry.key],
      ),
      final PluginAuthenticationChallenge challenge => PluginAuthenticationPresentationState.challenge(
        pluginId: entry.key,
        challenge: _presentationForChallenge(challenge),
      ),
    };
  }

  void _onAuthenticationTerminal(PluginAuthenticationTerminalUpdate update) {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady) return;
    final authentication = current.authentication;
    final currentPluginId = switch (authentication) {
      PluginAuthenticationPresentationStarting(:final pluginId) ||
      PluginAuthenticationPresentationChallenge(:final pluginId) ||
      PluginAuthenticationPresentationBrowserOpening(:final pluginId) ||
      PluginAuthenticationPresentationBrowserWaiting(:final pluginId) ||
      PluginAuthenticationPresentationBrowserFinalizing(:final pluginId) ||
      PluginAuthenticationPresentationBrowserLaunchFailedState(:final pluginId) ||
      PluginAuthenticationPresentationCancelling(:final pluginId) ||
      PluginAuthenticationPresentationCancellingUncertain(:final pluginId) => pluginId,
      PluginAuthenticationPresentationIdle() ||
      PluginAuthenticationPresentationSucceeded() ||
      PluginAuthenticationPresentationCancelled() ||
      PluginAuthenticationPresentationFailed() => null,
    };
    if (currentPluginId != update.pluginId) return;
    _authenticationGeneration++;
    switch (update.progress) {
      case PluginAuthenticationCompletedProgress():
        _setAuthentication(PluginAuthenticationPresentationState.succeeded(pluginId: update.pluginId));
      case PluginAuthenticationCancelledProgress():
        _setAuthentication(PluginAuthenticationPresentationState.cancelled(pluginId: update.pluginId));
      case PluginAuthenticationFailedProgress(:final message):
        _setAuthenticationFailure(
          pluginId: update.pluginId,
          error: PluginAuthenticationPresentationError.remote(message: message),
        );
      case PluginAuthenticationUnknownProgress():
        _setAuthenticationFailure(
          pluginId: update.pluginId,
          error: const PluginAuthenticationPresentationError.uncertain(),
        );
    }
  }

  void _onAuthenticationBrowserStates(Map<String, PluginAuthenticationBrowserState> browserStates) {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady) return;
    final data = _authenticationChallengeData(current.authentication);
    final challenge = switch (data?.challenge) {
      final PluginAuthenticationBrowserChallenge challenge => challenge,
      PluginAuthenticationDeviceCodeChallenge() || PluginAuthenticationUnsupportedChallenge() || null => null,
    };
    if (data == null || challenge == null) return;
    final browserState = browserStates[data.pluginId];
    if (browserState == null) return;
    _setAuthentication(
      _browserPresentation(pluginId: data.pluginId, challenge: challenge, browserState: browserState),
    );
  }

  void _setAuthentication(PluginAuthenticationPresentationState authentication) {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady) return;
    emit(current.copyWith(authentication: authentication));
  }

  void _setAuthenticationFailure({
    required String? pluginId,
    required PluginAuthenticationPresentationError error,
  }) {
    _setAuthentication(PluginAuthenticationPresentationState.failed(pluginId: pluginId, error: error));
  }

  /// The harnesses the live scan covers, or empty when none is running.
  ///
  /// Only a live operation names members worth disabling an action for: a
  /// terminal state still carries no ids, and an idle one covers nothing.
  Set<String> get _scanningPluginIds => switch (_catalogRescanService.state.value) {
    CatalogRescanPreparingOne(:final pluginIds) ||
    CatalogRescanStarting(:final pluginIds) ||
    CatalogRescanReading(:final pluginIds) ||
    CatalogRescanSaving(:final pluginIds) => pluginIds,
    CatalogRescanIdle() ||
    CatalogRescanSucceeded() ||
    CatalogRescanPartlyFailed() ||
    CatalogRescanFailed() ||
    CatalogRescanUnsupported() ||
    CatalogRescanNoHarness() => const {},
  };

  void _onCatalogScan(CatalogRescanState scan) {
    if (isClosed) return;
    // Dropped before the readiness check, not after: a disconnect resets the
    // scan to idle and reloads the snapshot, and the reload reaches this cubit
    // first. Reading the claims only while ready would let them survive the run
    // they belong to.
    if (scan is CatalogRescanIdle) _scanClaims.clear();
    final current = state;
    if (current is! PluginManagementReady) return;
    final scanning = _scanningPluginIds;
    // A harness entering a scan has an attempt in flight, which answers any
    // earlier refusal — including when a list's pull started it rather than
    // this card. Leaving it would spin a card beside its own contradiction and
    // restore the refusal once the scan succeeded.
    final rejections = Map<String, CatalogRescanStartResult>.of(current.scanRejections)
      ..removeWhere((pluginId, _) => scanning.contains(pluginId));
    // A run that ends without a terminal state — cancelled, or recovered and
    // settled quietly — has nothing to announce, which the idle clear above
    // covers. Announcing one spends every claim in it: the operation is one
    // run however many cards started members of it, and it ends once.
    final outcome = _scanClaims.isEmpty ? null : _outcomeOf(scan);
    if (outcome != null) _scanClaims.clear();
    if (outcome == null &&
        const SetEquality<String>().equals(current.scanningPluginIds, scanning) &&
        rejections.length == current.scanRejections.length) {
      return;
    }
    emit(
      current.copyWith(
        scanningPluginIds: scanning,
        scanRejections: rejections,
        scanOutcome: outcome ?? current.scanOutcome,
      ),
    );
  }

  /// The three ways a scan that actually started can end.
  ///
  /// Everything else is either still running or an answer the harness card
  /// already owns, so it produces nothing to announce.
  CatalogRescanOutcome? _outcomeOf(CatalogRescanState scan) => switch (scan) {
    CatalogRescanSucceeded(:final counts) => CatalogRescanOutcome.succeeded(counts: counts),
    CatalogRescanPartlyFailed(:final succeededCount, :final failedCount) => CatalogRescanOutcome.partlyFailed(
      succeededCount: succeededCount,
      failedCount: failedCount,
    ),
    CatalogRescanFailed() => const CatalogRescanOutcome.failed(),
    CatalogRescanIdle() ||
    CatalogRescanPreparingOne() ||
    CatalogRescanStarting() ||
    CatalogRescanReading() ||
    CatalogRescanSaving() ||
    CatalogRescanUnsupported() ||
    CatalogRescanNoHarness() => null,
  };

  void _onInstallStates({required Map<String, PluginInstallState> installs}) {
    if (isClosed) return;
    final current = state;
    // A non-ready state has no card to update; the next ready snapshot reads
    // the service's current progress, so nothing is lost by ignoring it here.
    if (current is! PluginManagementReady) return;
    if (const MapEquality<String, PluginInstallState>().equals(current.installs, installs)) return;
    emit(current.copyWith(installs: installs));
  }

  @override
  Future<void> close() async {
    await _subscriptions.dispose();
    return await super.close();
  }
}

({String pluginId, PluginAuthenticationChallenge challenge})? _authenticationChallengeData(
  PluginAuthenticationPresentationState state,
) => switch (state) {
  PluginAuthenticationPresentationChallenge(:final pluginId, :final challenge) => (
    pluginId: pluginId,
    challenge: challenge.challenge,
  ),
  PluginAuthenticationPresentationBrowserOpening(:final pluginId, :final challenge) ||
  PluginAuthenticationPresentationBrowserWaiting(:final pluginId, :final challenge) ||
  PluginAuthenticationPresentationBrowserFinalizing(:final pluginId, :final challenge) => (
    pluginId: pluginId,
    challenge: challenge,
  ),
  PluginAuthenticationPresentationBrowserLaunchFailedState(:final pluginId, :final challenge) ||
  PluginAuthenticationPresentationCancelling(:final pluginId, :final challenge) ||
  PluginAuthenticationPresentationCancellingUncertain(:final pluginId, :final challenge) => (
    pluginId: pluginId,
    challenge: challenge,
  ),
  PluginAuthenticationPresentationIdle() ||
  PluginAuthenticationPresentationStarting() ||
  PluginAuthenticationPresentationSucceeded() ||
  PluginAuthenticationPresentationCancelled() ||
  PluginAuthenticationPresentationFailed() => null,
};

PluginAuthenticationPresentationState _browserPresentation({
  required String pluginId,
  required PluginAuthenticationBrowserChallenge challenge,
  required PluginAuthenticationBrowserState? browserState,
}) => switch (browserState) {
  PluginAuthenticationBrowserOpening() => PluginAuthenticationPresentationState.browserOpening(
    pluginId: pluginId,
    challenge: challenge,
  ),
  PluginAuthenticationBrowserWaiting() ||
  null => PluginAuthenticationPresentationState.browserWaiting(pluginId: pluginId, challenge: challenge),
  PluginAuthenticationBrowserFinalizing() => PluginAuthenticationPresentationState.browserFinalizing(
    pluginId: pluginId,
    challenge: challenge,
  ),
  PluginAuthenticationBrowserCancelling() => PluginAuthenticationPresentationState.cancelling(
    pluginId: pluginId,
    challenge: challenge,
  ),
  PluginAuthenticationBrowserCancellingUncertain() => PluginAuthenticationPresentationState.cancellingUncertain(
    pluginId: pluginId,
    challenge: challenge,
  ),
  PluginAuthenticationBrowserRetryableFailure() => PluginAuthenticationPresentationState.browserLaunchFailed(
    pluginId: pluginId,
    challenge: challenge,
  ),
  PluginAuthenticationBrowserFatalFailure() => PluginAuthenticationPresentationState.cancelling(
    pluginId: pluginId,
    challenge: challenge,
  ),
};

PluginAuthenticationChallengePresentation _presentationForChallenge(PluginAuthenticationChallenge challenge) =>
    switch (challenge) {
      final PluginAuthenticationDeviceCodeChallenge challenge => PluginAuthenticationChallengePresentation.deviceCode(
        challenge: challenge,
      ),
      final PluginAuthenticationBrowserChallenge challenge => PluginAuthenticationChallengePresentation.browser(
        challenge: challenge,
      ),
      final PluginAuthenticationUnsupportedChallenge challenge =>
        PluginAuthenticationChallengePresentation.updateRequired(challenge: challenge),
    };

/// The plugin and action a conflict may be force-retried with. Non-null only
/// where the caller can offer that retry, so a force action can never travel
/// without the plugin it applies to.
final class const _ForceContext({
  required final String pluginId,
  required final PluginManagementForceAction action,
});
