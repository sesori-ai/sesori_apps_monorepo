import "../../foundation/models/product_analytics/product_analytics_event.dart";

final class const DeferredProductAnalyticsRetention({
  required final DeferredProductAnalyticsCandidates candidates,
  required final bool retained,
});

sealed class const DeferredProductAnalyticsDrain();

final class const DeferredProductAnalyticsDrainComplete() extends DeferredProductAnalyticsDrain;

final class const DeferredProductAnalyticsDrainNext({
  required final ProductAnalyticsEnvelope envelope,
  required final DeferredProductAnalyticsCandidates remainingCandidates,
}) extends DeferredProductAnalyticsDrain;

final class DeferredProductAnalyticsCandidates {
  final int generation;
  final _DeferredProductAnalyticsCandidate _activation;
  final _DeferredProductAnalyticsCandidate _projectAvailable;
  final _DeferredProductAnalyticsCandidate _diffAdoption;
  final _DeferredProductAnalyticsCandidate _sessionActivity;

  const new _({
    required this.generation,
    required _DeferredProductAnalyticsCandidate activation,
    required _DeferredProductAnalyticsCandidate projectAvailable,
    required _DeferredProductAnalyticsCandidate diffAdoption,
    required _DeferredProductAnalyticsCandidate sessionActivity,
  }) : _activation = activation,
       _projectAvailable = projectAvailable,
       _diffAdoption = diffAdoption,
       _sessionActivity = sessionActivity;

  const new empty({required this.generation})
    : _activation = const _DeferredProductAnalyticsCandidateEmpty(),
      _projectAvailable = const _DeferredProductAnalyticsCandidateEmpty(),
      _diffAdoption = const _DeferredProductAnalyticsCandidateEmpty(),
      _sessionActivity = const _DeferredProductAnalyticsCandidateEmpty();

  DeferredProductAnalyticsRetention retain({required ProductAnalyticsEnvelope envelope}) => switch (envelope.event) {
    SessionMessageSentEvent() || SessionCreatedWithMessageEvent() => _retainActivation(envelope: envelope),
    ProjectInventoryLoadedEvent(inventoryState: AnalyticsInventoryState.nonEmpty) => _retainProject(
      envelope: envelope,
    ),
    SessionDiffViewedEvent(changeState: AnalyticsChangeState.nonEmpty) => _retainDiff(envelope: envelope),
    SessionActivityViewedEvent(activityState: AnalyticsActivityState.nonEmpty) => _retainActivity(
      envelope: envelope,
    ),
    AnalyticsSchemaReadyEvent() ||
    AnalyticsActivationReadyEvent() ||
    ProjectInventoryLoadedEvent(inventoryState: AnalyticsInventoryState.empty) ||
    SessionActivityViewedEvent(activityState: AnalyticsActivityState.empty) ||
    SessionCreationFailedEvent() ||
    VoiceTranscriptionCompletedEvent() ||
    SessionQuestionAnsweredEvent() ||
    SessionQuestionRejectedEvent() ||
    SessionPermissionAnsweredEvent() ||
    SessionAbortSucceededEvent() ||
    HarnessInstallFinishedEvent() ||
    SessionDiffViewedEvent(changeState: AnalyticsChangeState.empty) ||
    NeedHelpMenuOpenedEvent() ||
    SupportLinkOpenedEvent() ||
    WhyBridgeOpenedEvent() ||
    InstallCommandCopiedEvent() ||
    InstallCommandSharedEvent() ||
    RunCommandCopiedEvent() ||
    RunCommandSharedEvent() ||
    ProductScreenViewedEvent() => DeferredProductAnalyticsRetention(candidates: this, retained: false),
  };

  DeferredProductAnalyticsDrain drainNext() {
    if (_activation case _DeferredProductAnalyticsCandidateRetained(:final envelope)) {
      return DeferredProductAnalyticsDrainNext(
        envelope: envelope,
        remainingCandidates: DeferredProductAnalyticsCandidates._(
          generation: generation,
          activation: const _DeferredProductAnalyticsCandidateEmpty(),
          projectAvailable: _projectAvailable,
          diffAdoption: _diffAdoption,
          sessionActivity: _sessionActivity,
        ),
      );
    }
    if (_projectAvailable case _DeferredProductAnalyticsCandidateRetained(:final envelope)) {
      return DeferredProductAnalyticsDrainNext(
        envelope: envelope,
        remainingCandidates: DeferredProductAnalyticsCandidates._(
          generation: generation,
          activation: _activation,
          projectAvailable: const _DeferredProductAnalyticsCandidateEmpty(),
          diffAdoption: _diffAdoption,
          sessionActivity: _sessionActivity,
        ),
      );
    }
    if (_diffAdoption case _DeferredProductAnalyticsCandidateRetained(:final envelope)) {
      return DeferredProductAnalyticsDrainNext(
        envelope: envelope,
        remainingCandidates: DeferredProductAnalyticsCandidates._(
          generation: generation,
          activation: _activation,
          projectAvailable: _projectAvailable,
          diffAdoption: const _DeferredProductAnalyticsCandidateEmpty(),
          sessionActivity: _sessionActivity,
        ),
      );
    }
    if (_sessionActivity case _DeferredProductAnalyticsCandidateRetained(:final envelope)) {
      return DeferredProductAnalyticsDrainNext(
        envelope: envelope,
        remainingCandidates: DeferredProductAnalyticsCandidates._(
          generation: generation,
          activation: _activation,
          projectAvailable: _projectAvailable,
          diffAdoption: _diffAdoption,
          sessionActivity: const _DeferredProductAnalyticsCandidateEmpty(),
        ),
      );
    }
    return const DeferredProductAnalyticsDrainComplete();
  }

  DeferredProductAnalyticsRetention _retainActivation({required ProductAnalyticsEnvelope envelope}) {
    final retention = _activation.retain(envelope: envelope);
    return DeferredProductAnalyticsRetention(
      candidates: DeferredProductAnalyticsCandidates._(
        generation: generation,
        activation: retention.candidate,
        projectAvailable: _projectAvailable,
        diffAdoption: _diffAdoption,
        sessionActivity: _sessionActivity,
      ),
      retained: retention.retained,
    );
  }

  DeferredProductAnalyticsRetention _retainProject({required ProductAnalyticsEnvelope envelope}) {
    final retention = _projectAvailable.retain(envelope: envelope);
    return DeferredProductAnalyticsRetention(
      candidates: DeferredProductAnalyticsCandidates._(
        generation: generation,
        activation: _activation,
        projectAvailable: retention.candidate,
        diffAdoption: _diffAdoption,
        sessionActivity: _sessionActivity,
      ),
      retained: retention.retained,
    );
  }

  DeferredProductAnalyticsRetention _retainDiff({required ProductAnalyticsEnvelope envelope}) {
    final retention = _diffAdoption.retain(envelope: envelope);
    return DeferredProductAnalyticsRetention(
      candidates: DeferredProductAnalyticsCandidates._(
        generation: generation,
        activation: _activation,
        projectAvailable: _projectAvailable,
        diffAdoption: retention.candidate,
        sessionActivity: _sessionActivity,
      ),
      retained: retention.retained,
    );
  }

  DeferredProductAnalyticsRetention _retainActivity({required ProductAnalyticsEnvelope envelope}) {
    final retention = _sessionActivity.retain(envelope: envelope);
    return DeferredProductAnalyticsRetention(
      candidates: DeferredProductAnalyticsCandidates._(
        generation: generation,
        activation: _activation,
        projectAvailable: _projectAvailable,
        diffAdoption: _diffAdoption,
        sessionActivity: retention.candidate,
      ),
      retained: retention.retained,
    );
  }
}

sealed class const _DeferredProductAnalyticsCandidate() {
  ({_DeferredProductAnalyticsCandidate candidate, bool retained}) retain({
    required ProductAnalyticsEnvelope envelope,
  });
}

final class const _DeferredProductAnalyticsCandidateEmpty() extends _DeferredProductAnalyticsCandidate {
  @override
  ({_DeferredProductAnalyticsCandidate candidate, bool retained}) retain({
    required ProductAnalyticsEnvelope envelope,
  }) => (
    candidate: _DeferredProductAnalyticsCandidateRetained(envelope: envelope),
    retained: true,
  );
}

final class const _DeferredProductAnalyticsCandidateRetained({required final ProductAnalyticsEnvelope envelope})
    extends _DeferredProductAnalyticsCandidate {
  @override
  ({_DeferredProductAnalyticsCandidate candidate, bool retained}) retain({
    required ProductAnalyticsEnvelope envelope,
  }) => (candidate: this, retained: false);
}
