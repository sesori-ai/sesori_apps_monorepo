import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../platform/url_launcher.dart";
import "../../repositories/models/plugin_management_result.dart";
import "../../services/plugin_management_service.dart";
import "plugin_management_state.dart";

class PluginManagementCubit({required final PluginManagementService _service, required final UrlLauncher _urlLauncher})
    extends Cubit<PluginManagementState> {
  this : super(const PluginManagementState.loading()) {
    _snapshotSubscription = _service.snapshots.listen((snapshot) => _onSnapshot(snapshot: snapshot));
    _installSubscription = _service.installProgress.listen((installs) => _onInstallProgress(installs: installs));
    _authenticationTerminalSubscription = _service.authenticationTerminal.listen(_onAuthenticationTerminal);
  }

  late final StreamSubscription<PluginManagementLoadResult> _snapshotSubscription;
  late final StreamSubscription<Map<String, PluginInstallProgress>> _installSubscription;
  late final StreamSubscription<PluginAuthenticationTerminalUpdate> _authenticationTerminalSubscription;
  int _actionGeneration = 0;
  int _authenticationGeneration = 0;

  Future<void> refresh() => _service.refresh();

  Future<void> startAuthentication({required String pluginId}) async {
    final current = state;
    if (isClosed || current is! PluginManagementReady) return;
    if (current.authentication is! PluginAuthenticationPresentationIdle &&
        current.authentication is! PluginAuthenticationPresentationFailed) {
      return;
    }
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
        if (challenge == null) {
          _setAuthenticationFailure(
            pluginId: pluginId,
            error: const PluginAuthenticationPresentationError.invalidChallenge(),
          );
          return;
        }
        _setAuthentication(
          PluginAuthenticationPresentationState.challenge(
            pluginId: pluginId,
            verificationUri: challenge.verificationUri,
            userCode: challenge.userCode,
          ),
        );
      case PluginAuthenticationStartFailed(:final failure):
        _setAuthenticationFailure(pluginId: pluginId, error: _presentationErrorFor(failure: failure));
    }
  }

  Future<void> launchAuthenticationBrowser() async {
    final current = state;
    if (isClosed || current is! PluginManagementReady) return;
    final challenge = _authenticationChallengeData(current.authentication);
    if (challenge == null) return;
    final generation = _authenticationGeneration;
    bool launched;
    try {
      launched = await _urlLauncher.launch(challenge.verificationUri);
    } on Object {
      launched = false;
    }
    if (isClosed) return;
    final latest = state;
    if (launched ||
        generation != _authenticationGeneration ||
        latest is! PluginManagementReady ||
        (latest.authentication is! PluginAuthenticationPresentationChallenge &&
            latest.authentication is! PluginAuthenticationPresentationBrowserLaunchFailedState)) {
      return;
    }
    final latestChallenge = _authenticationChallengeData(latest.authentication);
    if (latestChallenge?.pluginId != challenge.pluginId) return;
    emit(
      latest.copyWith(
        authentication: PluginAuthenticationPresentationState.browserLaunchFailed(
          pluginId: challenge.pluginId,
          verificationUri: challenge.verificationUri,
          userCode: challenge.userCode,
        ),
      ),
    );
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
        verificationUri: challenge.verificationUri,
        userCode: challenge.userCode,
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
            verificationUri: challenge.verificationUri,
            userCode: challenge.userCode,
          ),
        );
      case PluginAuthenticationCancelFailed(:final failure):
        _setAuthenticationFailure(pluginId: challenge.pluginId, error: _presentationErrorFor(failure: failure));
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

  Future<void> confirmForce() async {
    final current = state;
    final pending = switch (current) {
      PluginManagementReady(action: final PluginManagementActionForceConfirmationRequired pending) => pending,
      PluginManagementReady() ||
      PluginManagementLoading() ||
      PluginManagementUnsupported() ||
      PluginManagementFailure() => null,
    };
    if (pending == null) return;
    await _runCommand(
      pluginId: pending.pluginId,
      request: pending.request,
      forceAction: null,
      replacePendingConfirmation: true,
    );
  }

  void dismissForceConfirmation() {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady || current.action is! PluginManagementActionForceConfirmationRequired) {
      return;
    }
    _actionGeneration++;
    emit(current.copyWith(action: const PluginManagementActionState.idle()));
  }

  void dismissActionError() {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady || current.action is! PluginManagementActionFailed) return;
    _actionGeneration++;
    emit(current.copyWith(action: const PluginManagementActionState.idle()));
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
    final generation = _beginAction(target: target, replacePendingConfirmation: replacePendingConfirmation);
    if (generation == null) return;

    final result = await _service.command(pluginId: pluginId, request: request);
    if (!_canFinishAction(generation: generation)) return;

    _finishAction(
      generation: generation,
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
        final generation = _beginAction(target: target, replacePendingConfirmation: false);
        if (generation == null) return;
        final result = await _service.updateIdleTimeout(request: request);
        if (!_canFinishAction(generation: generation)) return;
        // An idle-timeout update offers no force affordance, so a conflict here
        // is simply a failure.
        _finishAction(
          generation: generation,
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

  int? _beginAction({
    required PluginManagementActionTarget target,
    required bool replacePendingConfirmation,
  }) {
    if (isClosed) return null;
    final current = state;
    if (current is! PluginManagementReady) return null;
    final canBegin =
        current.action is PluginManagementActionIdle ||
        current.action is PluginManagementActionFailed ||
        (replacePendingConfirmation && current.action is PluginManagementActionForceConfirmationRequired);
    if (!canBegin) return null;
    final generation = ++_actionGeneration;
    emit(current.copyWith(action: PluginManagementActionState.inProgress(target: target)));
    return generation;
  }

  bool _canFinishAction({required int generation}) {
    return !isClosed && generation == _actionGeneration && state is PluginManagementReady;
  }

  void _finishAction({required int generation, required PluginManagementActionState action}) {
    if (isClosed || generation != _actionGeneration) return;
    final current = state;
    if (current is! PluginManagementReady) return;
    emit(current.copyWith(action: action));
  }

  void _emitImmediateFailure({
    required PluginManagementActionTarget target,
    required PluginManagementActionError error,
  }) {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady ||
        (current.action is! PluginManagementActionIdle && current.action is! PluginManagementActionFailed)) {
      return;
    }
    _actionGeneration++;
    emit(
      current.copyWith(
        action: PluginManagementActionState.failed(target: target, error: error),
      ),
    );
  }

  void _onSnapshot({required PluginManagementLoadResult snapshot}) {
    if (isClosed) return;
    switch (snapshot) {
      case PluginManagementLoadResultLoading():
        _actionGeneration++;
        emit(const PluginManagementState.loading());
      case PluginManagementLoadResultSupported(:final response, :final refreshError):
        final action = switch (state) {
          PluginManagementReady(:final action) => action,
          PluginManagementLoading() ||
          PluginManagementUnsupported() ||
          PluginManagementFailure() => const PluginManagementActionState.idle(),
        };
        // Read the service's current progress rather than the previous state:
        // installs keep running across loading/reconnect transitions and while
        // this cubit is recreated (the screen builds a new one per visit), so
        // seeding from an empty map would hide a live install until its next
        // progress event.
        final installs = _service.installProgress.valueOrNull ?? const <String, PluginInstallProgress>{};
        emit(
          PluginManagementState.ready(
            response: response,
            refresh: switch (refreshError) {
              final error? => PluginManagementRefreshState.failed(error: error),
              null => const PluginManagementRefreshState.idle(),
            },
            action: action,
            authentication: switch (state) {
              PluginManagementReady(:final authentication) => authentication,
              PluginManagementLoading() ||
              PluginManagementUnsupported() ||
              PluginManagementFailure() => const PluginAuthenticationPresentationState.idle(),
            },
            installs: installs,
          ),
        );
      case PluginManagementLoadResultUnsupported():
        _actionGeneration++;
        emit(const PluginManagementState.unsupported());
      case PluginManagementLoadResultFailure(:final error):
        _actionGeneration++;
        emit(PluginManagementState.failure(error: error));
    }
  }

  void _onAuthenticationTerminal(PluginAuthenticationTerminalUpdate update) {
    if (isClosed) return;
    final current = state;
    if (current is! PluginManagementReady) return;
    final authentication = current.authentication;
    final currentPluginId = switch (authentication) {
      PluginAuthenticationPresentationStarting(:final pluginId) ||
      PluginAuthenticationPresentationChallenge(:final pluginId) ||
      PluginAuthenticationPresentationBrowserLaunchFailedState(:final pluginId) ||
      PluginAuthenticationPresentationCancelling(:final pluginId) ||
      PluginAuthenticationPresentationCancellingUncertain(:final pluginId) => pluginId,
      PluginAuthenticationPresentationIdle() || PluginAuthenticationPresentationFailed() => null,
    };
    if (currentPluginId != update.pluginId) return;
    _authenticationGeneration++;
    switch (update.progress) {
      case PluginAuthenticationCompletedProgress() || PluginAuthenticationCancelledProgress():
        _setAuthentication(const PluginAuthenticationPresentationState.idle());
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

  void _onInstallProgress({required Map<String, PluginInstallProgress> installs}) {
    if (isClosed) return;
    final current = state;
    // A non-ready state has no card to update; the next ready snapshot reads
    // the service's current progress, so nothing is lost by ignoring it here.
    if (current is! PluginManagementReady) return;
    if (const MapEquality<String, PluginInstallProgress>().equals(current.installs, installs)) return;
    emit(current.copyWith(installs: installs));
  }

  @override
  Future<void> close() async {
    await _snapshotSubscription.cancel();
    await _installSubscription.cancel();
    await _authenticationTerminalSubscription.cancel();
    return await super.close();
  }
}

({String pluginId, Uri verificationUri, String userCode})? _authenticationChallengeData(
  PluginAuthenticationPresentationState state,
) => switch (state) {
  PluginAuthenticationPresentationChallenge(:final pluginId, :final verificationUri, :final userCode) ||
  PluginAuthenticationPresentationBrowserLaunchFailedState(
    :final pluginId,
    :final verificationUri,
    :final userCode,
  ) ||
  PluginAuthenticationPresentationCancelling(:final pluginId, :final verificationUri, :final userCode) ||
  PluginAuthenticationPresentationCancellingUncertain(
    :final pluginId,
    :final verificationUri,
    :final userCode,
  ) => (pluginId: pluginId, verificationUri: verificationUri, userCode: userCode),
  PluginAuthenticationPresentationIdle() ||
  PluginAuthenticationPresentationStarting() ||
  PluginAuthenticationPresentationFailed() => null,
};

/// The plugin and action a conflict may be force-retried with. Non-null only
/// where the caller can offer that retry, so a force action can never travel
/// without the plugin it applies to.
final class const _ForceContext({
  required final String pluginId,
  required final PluginManagementForceAction action,
});
