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
  final _DeferredProductAnalyticsCandidate _founderCallShown;

  const new _({
    required this.generation,
    required _DeferredProductAnalyticsCandidate activation,
    required _DeferredProductAnalyticsCandidate projectAvailable,
    required _DeferredProductAnalyticsCandidate diffAdoption,
    required _DeferredProductAnalyticsCandidate sessionActivity,
    required _DeferredProductAnalyticsCandidate founderCallShown,
  }) : _activation = activation,
       _projectAvailable = projectAvailable,
       _diffAdoption = diffAdoption,
       _sessionActivity = sessionActivity,
       _founderCallShown = founderCallShown;

  const new empty({required this.generation})
    : _activation = const _DeferredProductAnalyticsCandidateEmpty(),
      _projectAvailable = const _DeferredProductAnalyticsCandidateEmpty(),
      _diffAdoption = const _DeferredProductAnalyticsCandidateEmpty(),
      _sessionActivity = const _DeferredProductAnalyticsCandidateEmpty(),
      _founderCallShown = const _DeferredProductAnalyticsCandidateEmpty();

  DeferredProductAnalyticsRetention retain({required ProductAnalyticsEnvelope envelope}) => switch (envelope.event) {
    SessionMessageSentEvent() || SessionCreatedWithMessageEvent() => _retainActivation(envelope: envelope),
    ProjectInventoryLoadedEvent(inventoryState: AnalyticsInventoryState.nonEmpty) => _retainProject(
      envelope: envelope,
    ),
    SessionDiffViewedEvent(changeState: AnalyticsChangeState.nonEmpty) => _retainDiff(envelope: envelope),
    SessionActivityViewedEvent(activityState: AnalyticsActivityState.nonEmpty) => _retainActivity(
      envelope: envelope,
    ),
    // The computer-connected sheet can open right after a fresh sign-in,
    // before the preference resolves; it is the A/B test's activation event.
    FounderCallShownEvent() => _retainFounderCallShown(envelope: envelope),
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
    TranscriptPromptsOpenedEvent() ||
    FeedbackPromptAnsweredEvent() ||
    PrivateFeedbackSentEvent() ||
    NeedHelpMenuOpenedEvent() ||
    SupportLinkOpenedEvent() ||
    WhyBridgeOpenedEvent() ||
    InstallCommandCopiedEvent() ||
    InstallCommandSharedEvent() ||
    RunCommandCopiedEvent() ||
    RunCommandSharedEvent() ||
    ProductScreenViewedEvent() ||
    ComputerSwitchedEvent() ||
    ComputerManagedEvent() ||
    FounderCallLinkOpenedEvent() ||
    FounderCallDeclinedEvent() => DeferredProductAnalyticsRetention(candidates: this, retained: false),
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
          founderCallShown: _founderCallShown,
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
          founderCallShown: _founderCallShown,
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
          founderCallShown: _founderCallShown,
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
          founderCallShown: _founderCallShown,
        ),
      );
    }
    if (_founderCallShown case _DeferredProductAnalyticsCandidateRetained(:final envelope)) {
      return DeferredProductAnalyticsDrainNext(
        envelope: envelope,
        remainingCandidates: DeferredProductAnalyticsCandidates._(
          generation: generation,
          activation: _activation,
          projectAvailable: _projectAvailable,
          diffAdoption: _diffAdoption,
          sessionActivity: _sessionActivity,
          founderCallShown: const _DeferredProductAnalyticsCandidateEmpty(),
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
        founderCallShown: _founderCallShown,
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
        founderCallShown: _founderCallShown,
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
        founderCallShown: _founderCallShown,
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
        founderCallShown: _founderCallShown,
      ),
      retained: retention.retained,
    );
  }

  DeferredProductAnalyticsRetention _retainFounderCallShown({required ProductAnalyticsEnvelope envelope}) {
    final retention = _founderCallShown.retain(envelope: envelope);
    return DeferredProductAnalyticsRetention(
      candidates: DeferredProductAnalyticsCandidates._(
        generation: generation,
        activation: _activation,
        projectAvailable: _projectAvailable,
        diffAdoption: _diffAdoption,
        sessionActivity: _sessionActivity,
        founderCallShown: retention.candidate,
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
