import "dart:async";
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey;

import "../logging/logging.dart";
import "../models/voice_capabilities.dart";
import "../models/voice_realtime.dart";
import "../platform/voice_capture.dart";
import "../repositories/project_repository.dart";
import "../repositories/voice_repository.dart";

const maxRecordingDuration = Duration(minutes: 15);
const _recorderPrewarmTimeout = Duration(seconds: 2);
const _realtimeReadyTimeout = Duration(seconds: 10);
const _realtimeFinishTimeout = Duration(seconds: 10);

@lazySingleton
class VoiceTranscriptionService({
  required final VoiceRepository _repository,
  required final ProjectRepository _projectRepository,
  required final VoiceCapture _capture,
}) {
  VoiceTranscriptionSession createSession({required String? projectId}) {
    final session = VoiceTranscriptionSession._(
      captureSession: _capture.createSession(),
      projectId: projectId == null || projectId.trim().isEmpty ? null : projectId,
    );
    _refreshProjectGlossaryKey(session: session);
    return session;
  }

  Stream<double> amplitudeStream({required VoiceTranscriptionSession session}) =>
      session._captureSession.amplitudeStream;

  Stream<void> maxDurationReachedStream({required VoiceTranscriptionSession session}) =>
      session._maxDurationReachedController.stream;

  Stream<VoiceRealtimeTerminalCause> realtimeTerminalStream({required VoiceTranscriptionSession session}) =>
      session._realtimeTerminalController.stream;

  VoiceTranscriptionPreview currentPreview({required VoiceTranscriptionSession session}) => session._preview;

  Stream<VoiceTranscriptionPreview> previewStream({required VoiceTranscriptionSession session}) =>
      session._previewController.stream;

  Future<void> prewarm({required VoiceTranscriptionSession session}) {
    if (session._state is _VoiceSessionClosing || session._state is _VoiceSessionDisposed) {
      return Future<void>.value();
    }

    _beginCapabilityDiscovery(session: session);
    final existing = session._prewarmFuture;
    if (existing != null) return existing;

    late final Future<void> trackedFuture;
    trackedFuture = _runPrewarm().whenComplete(() {
      if (identical(session._prewarmFuture, trackedFuture)) session._prewarmFuture = null;
    });
    session._prewarmFuture = trackedFuture;
    return trackedFuture;
  }

  Future<void> _runPrewarm() async {
    try {
      await _capture.prewarm();
    } catch (error, stackTrace) {
      logw("Failed to prewarm voice capture", error, stackTrace);
    }
  }

  void _beginCapabilityDiscovery({required VoiceTranscriptionSession session}) {
    if (session._capabilitiesOutcome != null ||
        session._capabilitiesDiscoveryFuture != null ||
        session._state is _VoiceSessionClosing ||
        session._state is _VoiceSessionDisposed) {
      return;
    }

    late final Future<void> trackedFuture;
    trackedFuture = _loadCapabilities(session: session).whenComplete(() {
      if (identical(session._capabilitiesDiscoveryFuture, trackedFuture)) {
        session._capabilitiesDiscoveryFuture = null;
      }
    });
    session._capabilitiesDiscoveryFuture = trackedFuture;
  }

  Future<void> _loadCapabilities({required VoiceTranscriptionSession session}) async {
    try {
      final outcome = await _repository.discoverCapabilities();
      if (session._state is! _VoiceSessionClosing && session._state is! _VoiceSessionDisposed) {
        session._capabilitiesOutcome = outcome;
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to pre-discover realtime voice capability", error, stackTrace);
      if (session._state is! _VoiceSessionClosing && session._state is! _VoiceSessionDisposed) {
        session._capabilitiesOutcome = const VoiceCapabilitiesAsyncFallback();
      }
    }
  }

  void _refreshProjectGlossaryKey({required VoiceTranscriptionSession session}) {
    final projectId = session._projectId;
    if (projectId == null ||
        session._availableProjectGlossaryKey != null ||
        session._projectGlossaryKeyLoad != null ||
        session._state is _VoiceSessionClosing ||
        session._state is _VoiceSessionDisposed) {
      return;
    }

    late final Future<void> trackedFuture;
    trackedFuture = _loadProjectGlossaryKey(session: session, projectId: projectId).whenComplete(() {
      if (identical(session._projectGlossaryKeyLoad, trackedFuture)) {
        session._projectGlossaryKeyLoad = null;
      }
    });
    session._projectGlossaryKeyLoad = trackedFuture;
  }

  Future<void> _loadProjectGlossaryKey({
    required VoiceTranscriptionSession session,
    required String projectId,
  }) async {
    try {
      final projectGlossaryKey = await _projectRepository.resolveVoiceGlossaryKey(projectId: projectId);
      if (session._state is _VoiceSessionClosing || session._state is _VoiceSessionDisposed) return;
      session._availableProjectGlossaryKey = projectGlossaryKey;
    } on Object catch (error, stackTrace) {
      logw("Could not load optional project voice context; continuing unscoped", error, stackTrace);
    }
  }

  Future<VoiceCapabilitiesDiscoveryOutcome> _capabilitiesForStart({
    required VoiceTranscriptionSession session,
  }) async {
    _beginCapabilityDiscovery(session: session);
    // Give an already-completed discovery one microtask to publish its result,
    // but never delay the active hold on network capability discovery.
    await Future<void>.value();
    return session._capabilitiesOutcome ?? const VoiceCapabilitiesAsyncFallback();
  }

  Future<void> start({required VoiceTranscriptionSession session}) {
    if (session._state is! _VoiceSessionIdle) {
      logw("Voice recording operation already in progress");
      return Future<void>.value();
    }

    final operation = _start(session: session);
    session._startFuture = operation;
    return operation.whenComplete(() {
      if (identical(session._startFuture, operation)) session._startFuture = null;
    });
  }

  Future<void> _start({required VoiceTranscriptionSession session}) async {
    final generation = ++session._generation;
    session._state = const _VoiceSessionStarting();
    session._interactionProjectGlossaryKey = session._availableProjectGlossaryKey;
    _refreshProjectGlossaryKey(session: session);
    _setPreview(
      session: session,
      preview: const VoiceTranscriptionPreview(confirmedText: "", provisionalText: ""),
    );

    try {
      final prewarmFuture = session._prewarmFuture;
      if (prewarmFuture != null) await prewarmFuture.timeout(_recorderPrewarmTimeout);
      _ensureGeneration(session: session, generation: generation);

      final discovery = await _capabilitiesForStart(session: session);
      _ensureGeneration(session: session, generation: generation);
      final mode = _selectStartMode(
        result: discovery,
        projectKey: session._interactionProjectGlossaryKey,
      );

      switch (mode) {
        case _AsyncVoiceStartMode():
          await _startAsync(session: session, generation: generation);
        case _RealtimeVoiceStartMode(:final projectKey):
          try {
            await _startRealtime(session: session, projectKey: projectKey, generation: generation);
          } on _RealtimePreAudioFallback catch (fallback) {
            logw(
              "Realtime voice failed before audio; continuing with async capture",
              fallback.cause,
              fallback.innerStackTrace,
            );
            await _disposeRealtimeInteraction(session: session, sendCancel: true, stopCapture: true);
            _ensureGeneration(session: session, generation: generation);
            await _startAsync(session: session, generation: generation);
          } on VoiceCaptureRealtimeUnsupported catch (error, stackTrace) {
            logw("Realtime capture is unsupported; continuing with async capture", error, stackTrace);
            await _disposeRealtimeInteraction(session: session, sendCancel: true, stopCapture: true);
            _ensureGeneration(session: session, generation: generation);
            await _startAsync(session: session, generation: generation);
          }
      }
    } on VoiceCapturePermissionDenied catch (error) {
      _restoreIdleAfterFailure(session: session, generation: generation);
      throw VoiceTranscriptionError.microphonePermissionDenied(innerError: error);
    } on VoiceCaptureError catch (error) {
      await _disposeRealtimeInteraction(session: session, sendCancel: true, stopCapture: true);
      _restoreIdleAfterFailure(session: session, generation: generation);
      throw VoiceTranscriptionError.recordingFailed(innerError: error);
    } on VoiceTranscriptionError {
      await _disposeRealtimeInteraction(session: session, sendCancel: true, stopCapture: true);
      _restoreIdleAfterFailure(session: session, generation: generation);
      rethrow;
    } catch (error, stackTrace) {
      loge("Failed to start voice recording", error, stackTrace);
      await _disposeRealtimeInteraction(session: session, sendCancel: true, stopCapture: true);
      _restoreIdleAfterFailure(session: session, generation: generation);
      throw VoiceTranscriptionError.recordingFailed(innerError: error);
    }
  }

  _VoiceStartMode _selectStartMode({
    required VoiceCapabilitiesDiscoveryOutcome result,
    required ProjectGlossaryKey? projectKey,
  }) => switch (result) {
    VoiceCapabilitiesAsyncFallback() => _AsyncVoiceStartMode(projectKey: projectKey),
    VoiceCapabilitiesContractFailure(:final reason) => throw VoiceTranscriptionError.contractFailure(
      reason: reason,
      innerError: FormatException(reason),
      innerStackTrace: null,
    ),
    VoiceCapabilitiesAvailable(:final capabilities) => () {
      if (capabilities.canUseRealtimeProtocol1) {
        return _RealtimeVoiceStartMode(projectKey: projectKey);
      }
      return _AsyncVoiceStartMode(projectKey: projectKey);
    }(),
  };

  Future<void> _startAsync({required VoiceTranscriptionSession session, required int generation}) async {
    await session._captureSession.start();
    if (!_ownsGeneration(session: session, generation: generation)) {
      await session._captureSession.cancel();
      throw VoiceTranscriptionError.cancelled();
    }
    session._state = const _VoiceSessionAsyncRecording();
    _startMaxDurationTimer(session: session);
  }

  Future<void> _startRealtime({
    required VoiceTranscriptionSession session,
    required ProjectGlossaryKey? projectKey,
    required int generation,
  }) async {
    final captureStartFuture = session._captureSession.startRealtime();
    session._realtimeCaptureStartFuture = captureStartFuture;
    final capture = await captureStartFuture;
    _ensureGeneration(session: session, generation: generation);
    final setupFailure = Completer<_RealtimePreAudioFallback>();
    void failSetup({required Object error, required StackTrace stackTrace}) {
      if (setupFailure.isCompleted) return;
      setupFailure.complete(
        _RealtimePreAudioFallback(
          cause: error is Exception ? error : VoiceCaptureError.failed(innerError: error),
          innerStackTrace: stackTrace,
        ),
      );
    }

    final setupFrameSubscription = capture.frames.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) => failSetup(error: error, stackTrace: stackTrace),
      onDone: () => failSetup(
        error: VoiceCaptureError.failed(innerError: null),
        stackTrace: StackTrace.current,
      ),
    );
    final setupFormatSubscription = capture.formatChanges.listen(
      (format) {
        if (format.sampleRate != capture.format.sampleRate) {
          failSetup(
            error: VoiceCaptureError.realtimeUnsupported(innerError: null),
            stackTrace: StackTrace.current,
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) => failSetup(error: error, stackTrace: stackTrace),
    );
    final openFuture = _repository.openRealtime(
      audio: VoiceRealtimeAudioFormat(sampleRate: capture.format.sampleRate),
      projectKey: projectKey,
    );
    late final VoiceRealtimeOpenOutcome open;
    try {
      open = await Future.any<VoiceRealtimeOpenOutcome>([
        openFuture,
        setupFailure.future.then((failure) => throw failure),
      ]);
    } on _RealtimePreAudioFallback {
      unawaited(_closeLateRealtimeOpen(openFuture));
      rethrow;
    } finally {
      await setupFrameSubscription.cancel();
      await setupFormatSubscription.cancel();
    }
    if (!_ownsGeneration(session: session, generation: generation)) {
      if (open case VoiceRealtimeOpened(:final connection)) {
        try {
          await connection.cancel();
        } on Object catch (error, stackTrace) {
          logw("Failed to close realtime voice after startup ownership was lost", error, stackTrace);
        }
      }
      throw VoiceTranscriptionError.cancelled();
    }

    final VoiceRealtimeConnection realtimeSession;
    switch (open) {
      case VoiceRealtimeOpened(:final connection):
        realtimeSession = connection;
      case VoiceRealtimeOpenAsyncFallback(:final cause, :final innerStackTrace):
        throw _RealtimePreAudioFallback(cause: cause, innerStackTrace: innerStackTrace);
      case VoiceRealtimeOpenNotAuthenticated():
        throw VoiceTranscriptionError.notAuthenticated();
      case VoiceRealtimeOpenContractFailure(:final reason, :final cause):
        throw VoiceTranscriptionError.contractFailure(
          reason: reason,
          innerError: cause,
          innerStackTrace: null,
        );
      case VoiceRealtimeOpenUnexpectedFailure(:final error):
        throw VoiceTranscriptionError.recordingFailed(innerError: error);
    }

    final interaction = _RealtimeVoiceInteraction(
      generation: generation,
      capture: capture,
      session: realtimeSession,
    );
    session._realtime = interaction;
    if (identical(session._realtimeCaptureStartFuture, captureStartFuture)) {
      session._realtimeCaptureStartFuture = null;
    }
    interaction.frameSubscription = capture.frames.listen(
      (frame) => _handleRealtimeFrame(session: session, interaction: interaction, frame: frame),
      onError: (Object error, StackTrace stackTrace) {
        _handleRealtimeCaptureFailure(
          session: session,
          interaction: interaction,
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    interaction.formatSubscription = capture.formatChanges.listen(
      (format) => _handleRealtimeFormatChange(
        session: session,
        interaction: interaction,
        format: format,
      ),
      onError: (Object error, StackTrace stackTrace) {
        _handleRealtimeCaptureFailure(
          session: session,
          interaction: interaction,
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    interaction.eventSubscription = realtimeSession.events.listen(
      (event) => _handleRealtimeEvent(session: session, interaction: interaction, event: event),
      onError: (Object error, StackTrace stackTrace) {
        _handleRealtimeDomainFailure(
          session: session,
          interaction: interaction,
          failure: VoiceRealtimeInterruptedFailure(
            innerError: error,
            innerStackTrace: stackTrace,
          ),
          allowPreAudioFallback: true,
        );
      },
      onDone: () {
        if (interaction.terminalEvent == null && interaction.terminalFailure == null) {
          _handleRealtimeDomainFailure(
            session: session,
            interaction: interaction,
            failure: const VoiceRealtimeInterruptedFailure(
              innerError: null,
              innerStackTrace: null,
            ),
            allowPreAudioFallback: true,
          );
        }
      },
    );

    try {
      await Future.any<void>([
        interaction.ready.future.timeout(_realtimeReadyTimeout),
        interaction.startFailure.future.then((error) => throw error),
      ]);
    } on TimeoutException catch (error, stackTrace) {
      throw _RealtimePreAudioFallback(cause: error, innerStackTrace: stackTrace);
    } on RealtimeInterruptedVoiceError catch (error, stackTrace) {
      throw _RealtimePreAudioFallback(
        cause: error,
        innerStackTrace: error.innerStackTrace ?? stackTrace,
      );
    }
    _ensureGeneration(session: session, generation: generation);
    if (interaction.fallbackRequested) {
      throw _RealtimePreAudioFallback(
        cause: interaction.fallbackCause ?? Exception("Realtime setup failed"),
        innerStackTrace: interaction.fallbackStackTrace ?? StackTrace.current,
      );
    }
    if (interaction.terminalEvent != null) {
      session._state = const _VoiceSessionRealtimeRecording();
      return;
    }
    final terminalFailureBeforeResume = interaction.terminalFailure;
    if (terminalFailureBeforeResume != null) throw terminalFailureBeforeResume;
    await session._captureSession.resumeRealtime();
    _ensureGeneration(session: session, generation: generation);
    if (interaction.fallbackRequested) {
      throw _RealtimePreAudioFallback(
        cause: interaction.fallbackCause ?? Exception("Realtime setup failed"),
        innerStackTrace: interaction.fallbackStackTrace ?? StackTrace.current,
      );
    }
    if (interaction.terminalEvent != null) {
      session._state = const _VoiceSessionRealtimeRecording();
      return;
    }
    final terminalFailureAfterResume = interaction.terminalFailure;
    if (terminalFailureAfterResume != null) throw terminalFailureAfterResume;
    interaction.forwardFrames = true;
    session._state = const _VoiceSessionRealtimeRecording();
    _startMaxDurationTimer(session: session);
  }

  Future<String> stopAndTranscribe({required VoiceTranscriptionSession session}) async {
    final state = session._state;
    if (state case _VoiceSessionRealtimeFallback(:final transition)) {
      await transition;
      return await stopAndTranscribe(session: session);
    }
    if (state is _VoiceSessionRealtimeRecording) {
      return await _stopRealtimeAndTranscribe(session: session);
    }
    if (state is! _VoiceSessionAsyncRecording) {
      throw VoiceTranscriptionError.notRecording();
    }

    _cancelMaxDurationTimer(session: session);
    final generation = session._generation;
    late final VoiceRecordingArtifact artifact;

    try {
      final stopFuture = session._captureSession.stop();
      session._stopFuture = stopFuture;
      session._state = const _VoiceSessionStopping();
      try {
        artifact = await stopFuture;
      } finally {
        if (identical(session._stopFuture, stopFuture)) session._stopFuture = null;
      }
    } on VoiceCaptureError catch (error) {
      await session._captureSession.cancel();
      _restoreIdleAfterFailure(session: session, generation: generation);
      throw VoiceTranscriptionError.recordingFailed(innerError: error);
    }

    if (!_ownsGeneration(session: session, generation: generation)) {
      await session._captureSession.deleteArtifact(artifact: artifact);
      throw VoiceTranscriptionError.cancelled();
    }

    session._state = _VoiceSessionInitialTranscribing(artifact: artifact);
    return await _transcribeArtifact(
      session: session,
      artifact: artifact,
      generation: generation,
      releaseCaptureOperation: true,
    );
  }

  Future<void> _closeLateRealtimeOpen(Future<VoiceRealtimeOpenOutcome> openFuture) async {
    try {
      final outcome = await openFuture;
      if (outcome case VoiceRealtimeOpened(:final connection)) await connection.cancel();
    } on Object catch (error, stackTrace) {
      logw("Late realtime voice open failed after local fallback", error, stackTrace);
    }
  }

  void _handleRealtimeFrame({
    required VoiceTranscriptionSession session,
    required _RealtimeVoiceInteraction interaction,
    required Uint8List frame,
  }) {
    if (!interaction.forwardFrames || !_ownsGeneration(session: session, generation: interaction.generation)) return;
    try {
      interaction.session.sendAudio(frame);
      interaction.sentAudio = true;
    } on VoiceRealtimeConnectionException catch (error) {
      _handleRealtimeDomainFailure(
        session: session,
        interaction: interaction,
        failure: error.failure,
        allowPreAudioFallback: true,
      );
    } on Object catch (error, stackTrace) {
      _handleRealtimeDomainFailure(
        session: session,
        interaction: interaction,
        failure: VoiceRealtimeInterruptedFailure(
          innerError: error,
          innerStackTrace: stackTrace,
        ),
        allowPreAudioFallback: true,
      );
    }
  }

  void _handleRealtimeFormatChange({
    required VoiceTranscriptionSession session,
    required _RealtimeVoiceInteraction interaction,
    required VoiceRealtimeCaptureFormat format,
  }) {
    if (format.sampleRate == interaction.capture.format.sampleRate) return;
    final stackTrace = StackTrace.current;
    final error = VoiceTranscriptionError.realtimeContract(
      reason: "Realtime recorder format changed after setup",
      innerError: StateError("Realtime recorder sample rate changed"),
      innerStackTrace: stackTrace,
    );
    if (!interaction.sentAudio) {
      _requestRealtimeFallback(
        session: session,
        interaction: interaction,
        cause: error,
        innerStackTrace: stackTrace,
      );
    } else {
      _completeRealtimeFailure(session: session, interaction: interaction, error: error);
    }
  }

  void _handleRealtimeCaptureFailure({
    required VoiceTranscriptionSession session,
    required _RealtimeVoiceInteraction interaction,
    required Object error,
    required StackTrace stackTrace,
  }) {
    final typed = error is VoiceCaptureError ? error : VoiceCaptureError.failed(innerError: error);
    if (!interaction.sentAudio) {
      _requestRealtimeFallback(
        session: session,
        interaction: interaction,
        cause: typed,
        innerStackTrace: stackTrace,
      );
      return;
    }
    _completeRealtimeFailure(
      session: session,
      interaction: interaction,
      error: switch (typed) {
        VoiceCaptureRealtimeUnsupported() => VoiceTranscriptionError.realtimeContract(
          reason: "Realtime recorder format became unsupported after audio started",
          innerError: typed,
          innerStackTrace: stackTrace,
        ),
        VoiceCapturePermissionDenied() ||
        VoiceCaptureFailed() => VoiceTranscriptionError.recordingFailed(innerError: typed),
      },
    );
  }

  void _handleRealtimeDomainFailure({
    required VoiceTranscriptionSession session,
    required _RealtimeVoiceInteraction interaction,
    required VoiceRealtimeFailure failure,
    required bool allowPreAudioFallback,
  }) {
    final typed = _mapRealtimeFailure(failure);
    if (allowPreAudioFallback && failure is VoiceRealtimeInterruptedFailure && !interaction.sentAudio) {
      _requestRealtimeFallback(
        session: session,
        interaction: interaction,
        cause: typed,
        innerStackTrace: failure.innerStackTrace ?? StackTrace.current,
      );
      return;
    }
    _completeRealtimeFailure(session: session, interaction: interaction, error: typed);
  }

  VoiceTranscriptionError _mapRealtimeFailure(VoiceRealtimeFailure failure) => switch (failure) {
    VoiceRealtimeQuotaFailure(:final innerError, :final innerStackTrace) => VoiceTranscriptionError.realtimeQuota(
      innerError: innerError,
      innerStackTrace: innerStackTrace,
    ),
    VoiceRealtimeTemporaryUnavailableFailure(:final innerError, :final innerStackTrace) =>
      VoiceTranscriptionError.realtimeTemporaryUnavailable(
        innerError: innerError,
        innerStackTrace: innerStackTrace,
      ),
    VoiceRealtimeInterruptedFailure(:final innerError, :final innerStackTrace) =>
      VoiceTranscriptionError.realtimeInterrupted(
        innerError: innerError,
        innerStackTrace: innerStackTrace,
      ),
    VoiceRealtimeContractFailure(:final innerError, :final innerStackTrace) => VoiceTranscriptionError.realtimeContract(
      reason: "Realtime voice contract failure",
      innerError: innerError ?? const FormatException("Realtime voice contract failure"),
      innerStackTrace: innerStackTrace,
    ),
  };

  void _handleRealtimeEvent({
    required VoiceTranscriptionSession session,
    required _RealtimeVoiceInteraction interaction,
    required VoiceRealtimeConnectionEvent event,
  }) {
    if (!_ownsGeneration(session: session, generation: interaction.generation)) return;
    switch (event) {
      case VoiceRealtimeReady():
        if (!interaction.ready.isCompleted) interaction.ready.complete();
      case VoiceRealtimeTranscript(:final confirmedDelta, :final provisional):
        interaction.confirmedText += confirmedDelta;
        interaction.provisionalText = provisional;
        _setPreview(
          session: session,
          preview: VoiceTranscriptionPreview(
            confirmedText: interaction.confirmedText,
            provisionalText: interaction.provisionalText,
          ),
        );
      case VoiceRealtimeCompleted(:final reason):
        interaction.terminalEvent = event;
        if (!interaction.ready.isCompleted && !interaction.startFailure.isCompleted) {
          interaction.startFailure.complete(
            VoiceTranscriptionError.contractFailure(
              reason: "Realtime session completed before ready",
              innerError: StateError("Realtime complete before ready"),
              innerStackTrace: StackTrace.current,
            ),
          );
        }
        unawaited(_stopRealtimeCaptureAfterTerminal(session: session, interaction: interaction));
        if (!session._realtimeTerminalController.isClosed) {
          session._realtimeTerminalController.add(
            reason == VoiceRealtimeCompletionReason.finished
                ? VoiceRealtimeTerminalCause.completed
                : VoiceRealtimeTerminalCause.limitReached,
          );
        }
      case VoiceRealtimeFailed(:final failure):
        _handleRealtimeDomainFailure(
          session: session,
          interaction: interaction,
          failure: failure,
          allowPreAudioFallback: true,
        );
    }
  }

  void _requestRealtimeFallback({
    required VoiceTranscriptionSession session,
    required _RealtimeVoiceInteraction interaction,
    required Exception cause,
    required StackTrace innerStackTrace,
  }) {
    if (interaction.fallbackRequested || interaction.terminalFailure != null || interaction.terminalEvent != null) {
      return;
    }
    interaction.fallbackRequested = true;
    interaction.fallbackCause = cause;
    interaction.fallbackStackTrace = innerStackTrace;
    interaction.forwardFrames = false;
    if (session._state is _VoiceSessionStarting) {
      if (!interaction.startFailure.isCompleted) {
        interaction.startFailure.complete(
          VoiceTranscriptionError.realtimeInterrupted(
            innerError: cause,
            innerStackTrace: innerStackTrace,
          ),
        );
      }
      return;
    }
    if (session._state is _VoiceSessionRealtimeRecording && interaction.fallbackTransition == null) {
      logw(
        "Realtime voice failed before audio; continuing with async capture",
        cause,
        innerStackTrace,
      );
      final transition = _transitionRealtimeToAsync(
        session: session,
        interaction: interaction,
      );
      interaction.fallbackTransition = transition;
      session._state = _VoiceSessionRealtimeFallback(transition: transition);
    }
  }

  Future<void> _transitionRealtimeToAsync({
    required VoiceTranscriptionSession session,
    required _RealtimeVoiceInteraction interaction,
  }) async {
    final generation = interaction.generation;
    try {
      await _disposeRealtimeInteraction(session: session, sendCancel: true, stopCapture: true);
      _ensureGeneration(session: session, generation: generation);
      await _startAsync(session: session, generation: generation);
    } on TranscriptionCancelledError {
      return;
    } on Object catch (error, stackTrace) {
      loge("Failed to fall back from realtime voice capture", error, stackTrace);
      interaction.terminalFailure = error is VoiceTranscriptionError
          ? error
          : VoiceTranscriptionError.recordingFailed(innerError: error);
      session._realtime = interaction;
      if (_ownsGeneration(session: session, generation: generation)) {
        session._state = const _VoiceSessionRealtimeRecording();
      }
    }
  }

  void _completeRealtimeFailure({
    required VoiceTranscriptionSession session,
    required _RealtimeVoiceInteraction interaction,
    required VoiceTranscriptionError error,
  }) {
    if (interaction.terminalFailure != null || interaction.terminalEvent != null) return;
    interaction.terminalFailure = error;
    interaction.forwardFrames = false;
    if (!interaction.ready.isCompleted && !interaction.startFailure.isCompleted) {
      interaction.startFailure.complete(error);
    }
    unawaited(_stopRealtimeCaptureAfterTerminal(session: session, interaction: interaction));
    if (!session._realtimeTerminalController.isClosed) {
      session._realtimeTerminalController.add(VoiceRealtimeTerminalCause.failed);
    }
  }

  Future<void> _stopRealtimeCaptureAfterTerminal({
    required VoiceTranscriptionSession session,
    required _RealtimeVoiceInteraction interaction,
  }) {
    if (interaction.captureStopped) return Future<void>.value();
    final existing = interaction.captureStopFuture;
    if (existing != null) return existing;
    final operation = _runStopRealtimeCaptureAfterTerminal(session: session, interaction: interaction);
    interaction.captureStopFuture = operation;
    return operation;
  }

  Future<void> _runStopRealtimeCaptureAfterTerminal({
    required VoiceTranscriptionSession session,
    required _RealtimeVoiceInteraction interaction,
  }) async {
    interaction.forwardFrames = false;
    _cancelMaxDurationTimer(session: session);
    try {
      await session._captureSession.stopRealtime();
    } on VoiceCaptureError catch (error, stackTrace) {
      interaction.captureFailure = VoiceTranscriptionError.recordingFailed(innerError: error);
      logw("Failed to stop realtime capture after terminal event", error, stackTrace);
    } finally {
      interaction.captureStopped = true;
      await session._captureSession.releaseOperation();
    }
  }

  Future<String> _stopRealtimeAndTranscribe({required VoiceTranscriptionSession session}) async {
    final interaction = session._realtime;
    if (interaction == null) throw VoiceTranscriptionError.notRecording();
    final generation = interaction.generation;
    _cancelMaxDurationTimer(session: session);
    session._state = const _VoiceSessionRealtimeFinishing();
    interaction.forwardFrames = false;

    try {
      await _stopRealtimeCaptureAfterTerminal(session: session, interaction: interaction);
      _ensureGeneration(session: session, generation: generation);

      final terminalFailure = interaction.terminalFailure ?? interaction.captureFailure;
      if (terminalFailure != null) {
        throw VoiceRealtimePartialTranscriptionError(
          confirmedText: interaction.confirmedText,
          failure: terminalFailure,
        );
      }
      final terminalEvent = interaction.terminalEvent;
      if (terminalEvent is VoiceRealtimeCompleted) {
        return _requireRealtimeTranscript(interaction: interaction);
      }

      try {
        final terminal = await interaction.session.finish().timeout(_realtimeFinishTimeout);
        _ensureGeneration(session: session, generation: generation);
        if (terminal case VoiceRealtimeTerminalFailed(:final failure)) {
          throw VoiceRealtimePartialTranscriptionError(
            confirmedText: interaction.confirmedText,
            failure: _mapRealtimeFailure(failure),
          );
        }
        return _requireRealtimeTranscript(interaction: interaction);
      } on VoiceRealtimePartialTranscriptionError {
        rethrow;
      } on TimeoutException catch (error, stackTrace) {
        _ensureGeneration(session: session, generation: generation);
        throw VoiceRealtimePartialTranscriptionError(
          confirmedText: interaction.confirmedText,
          failure: VoiceTranscriptionError.realtimeTemporaryUnavailable(
            innerError: error,
            innerStackTrace: stackTrace,
          ),
        );
      } on VoiceRealtimeConnectionException catch (error) {
        _ensureGeneration(session: session, generation: generation);
        throw VoiceRealtimePartialTranscriptionError(
          confirmedText: interaction.confirmedText,
          failure: _mapRealtimeFailure(error.failure),
        );
      } on VoiceTranscriptionError {
        rethrow;
      } on Object catch (error, stackTrace) {
        _ensureGeneration(session: session, generation: generation);
        throw VoiceRealtimePartialTranscriptionError(
          confirmedText: interaction.confirmedText,
          failure: VoiceTranscriptionError.realtimeInterrupted(
            innerError: error,
            innerStackTrace: stackTrace,
          ),
        );
      }
    } finally {
      if (identical(session._realtime, interaction)) {
        await _disposeRealtimeInteraction(session: session, sendCancel: false, stopCapture: false);
      }
      if (_ownsGeneration(session: session, generation: generation)) {
        session._state = const _VoiceSessionIdle();
        _setPreview(
          session: session,
          preview: const VoiceTranscriptionPreview(confirmedText: "", provisionalText: ""),
        );
      }
    }
  }

  static String _requireRealtimeTranscript({required _RealtimeVoiceInteraction interaction}) {
    if (interaction.confirmedText.isEmpty) throw VoiceTranscriptionError.emptyTranscript();
    return interaction.confirmedText;
  }

  Future<String> retry({required VoiceTranscriptionSession session}) async {
    final pending = session._state;
    if (pending is! _VoiceSessionRetryPending) {
      throw VoiceTranscriptionError.missingRecording();
    }

    final artifact = pending.artifact;
    final generation = ++session._generation;
    session._state = _VoiceSessionRetryTranscribing(artifact: artifact);

    bool artifactExists;
    try {
      artifactExists = await session._captureSession.artifactExists(artifact: artifact);
    } catch (error, stackTrace) {
      logw("Failed to inspect retained voice recording", error, stackTrace);
      artifactExists = false;
    }
    if (!_ownsGeneration(session: session, generation: generation)) {
      throw VoiceTranscriptionError.cancelled();
    }
    if (!artifactExists) {
      await session._captureSession.deleteArtifact(artifact: artifact);
      session._state = const _VoiceSessionIdle();
      throw VoiceTranscriptionError.missingRecording();
    }

    return await _transcribeArtifact(
      session: session,
      artifact: artifact,
      generation: generation,
      releaseCaptureOperation: false,
    );
  }

  Future<String> _transcribeArtifact({
    required VoiceTranscriptionSession session,
    required VoiceRecordingArtifact artifact,
    required int generation,
    required bool releaseCaptureOperation,
  }) async {
    VoiceTranscriptionError? retainedFailure;
    try {
      final outcome = await _repository.transcribe(
        audioFilePath: artifact.path,
        mimeType: artifact.mimeType,
        projectGlossaryKey: session._interactionProjectGlossaryKey,
      );
      if (!_ownsGeneration(session: session, generation: generation)) {
        throw VoiceTranscriptionError.cancelled();
      }

      switch (outcome) {
        case VoiceTranscriptionSuccess(:final transcript):
          return transcript;
        case VoiceTranscriptionNotAuthenticated():
          throw VoiceTranscriptionError.notAuthenticated();
        case VoiceTranscriptionRetryableServerFailure(:final statusCode):
          retainedFailure = VoiceTranscriptionError.retryableServerError(statusCode: statusCode);
          throw retainedFailure;
        case VoiceTranscriptionTerminalServerFailure(:final statusCode):
          throw VoiceTranscriptionError.serverError(statusCode: statusCode);
        case VoiceTranscriptionNetworkFailure():
          retainedFailure = VoiceTranscriptionError.networkError();
          throw retainedFailure;
        case VoiceTranscriptionUnexpectedFailure():
          throw VoiceTranscriptionError.recordingFailed(innerError: outcome);
        case VoiceTranscriptionEmptyTranscript():
          throw VoiceTranscriptionError.emptyTranscript();
      }
    } finally {
      if (_ownsGeneration(session: session, generation: generation)) {
        try {
          if (releaseCaptureOperation) await session._captureSession.releaseOperation();
        } finally {
          if (_ownsGeneration(session: session, generation: generation)) {
            if (retainedFailure == null) {
              await session._captureSession.deleteArtifact(artifact: artifact);
              session._state = const _VoiceSessionIdle();
            } else {
              session._state = _VoiceSessionRetryPending(artifact: artifact);
            }
          }
        }
      }
    }
  }

  Future<void> cancel({required VoiceTranscriptionSession session}) {
    final existing = session._cancelFuture;
    if (existing != null) return existing;

    final operation = _cancel(session: session);
    session._cancelFuture = operation;
    return operation.whenComplete(() {
      if (identical(session._cancelFuture, operation)) session._cancelFuture = null;
    });
  }

  Future<void> _cancel({required VoiceTranscriptionSession session}) async {
    final state = session._state;
    if (state is _VoiceSessionIdle ||
        state is _VoiceSessionRetryPending ||
        state is _VoiceSessionClosing ||
        state is _VoiceSessionDisposed) {
      return;
    }

    final generation = ++session._generation;
    _cancelMaxDurationTimer(session: session);

    switch (state) {
      case _VoiceSessionStarting():
        final realtimeStarting = session._realtime != null || session._realtimeCaptureStartFuture != null;
        await _disposeRealtimeInteraction(session: session, sendCancel: true, stopCapture: true);
        if (!realtimeStarting) await session._captureSession.cancel();
      case _VoiceSessionAsyncRecording():
        await session._captureSession.cancel();
      case _VoiceSessionRealtimeRecording() || _VoiceSessionRealtimeFinishing():
        await _disposeRealtimeInteraction(session: session, sendCancel: true, stopCapture: true);
      case _VoiceSessionRealtimeFallback(:final transition):
        await transition;
      case _VoiceSessionStopping():
        final stopFuture = session._stopFuture;
        VoiceRecordingArtifact? artifact;
        if (stopFuture != null) {
          try {
            artifact = await stopFuture;
          } on VoiceCaptureError {
            // The stop operation owns native failure cleanup after the future settles.
          }
        }
        await session._captureSession.releaseOperation();
        if (artifact != null) {
          await session._captureSession.deleteArtifact(artifact: artifact);
        }
      case _VoiceSessionInitialTranscribing(:final artifact):
        await session._captureSession.releaseOperation();
        await session._captureSession.deleteArtifact(artifact: artifact);
      case _VoiceSessionRetryTranscribing(:final artifact):
        if (_ownsGeneration(session: session, generation: generation)) {
          session._state = _VoiceSessionRetryPending(artifact: artifact);
        }
        return;
      case _VoiceSessionIdle() || _VoiceSessionRetryPending() || _VoiceSessionClosing() || _VoiceSessionDisposed():
        return;
    }
    if (_ownsGeneration(session: session, generation: generation)) {
      session._state = const _VoiceSessionIdle();
      _setPreview(
        session: session,
        preview: const VoiceTranscriptionPreview(confirmedText: "", provisionalText: ""),
      );
    }
  }

  Future<void> discard({required VoiceTranscriptionSession session}) async {
    final state = session._state;
    if (state is! _VoiceSessionRetryPending) return;

    session._generation++;
    await session._captureSession.deleteArtifact(artifact: state.artifact);
    session._state = const _VoiceSessionIdle();
  }

  void invalidate({required VoiceTranscriptionSession session}) {
    final state = session._state;
    if (state is _VoiceSessionClosing || state is _VoiceSessionDisposed) return;

    session._generation++;
    _cancelMaxDurationTimer(session: session);
    session._state = switch (state) {
      _VoiceSessionInitialTranscribing(:final artifact) ||
      _VoiceSessionRetryTranscribing(:final artifact) ||
      _VoiceSessionRetryPending(:final artifact) => _VoiceSessionClosingWithArtifact(artifact: artifact),
      _VoiceSessionIdle() ||
      _VoiceSessionStarting() ||
      _VoiceSessionAsyncRecording() ||
      _VoiceSessionRealtimeRecording() ||
      _VoiceSessionRealtimeFallback() ||
      _VoiceSessionRealtimeFinishing() ||
      _VoiceSessionStopping() => const _VoiceSessionClosingWithoutArtifact(),
      _VoiceSessionClosing() || _VoiceSessionDisposed() => throw StateError("Voice session already closing"),
    };
  }

  Future<void> close({required VoiceTranscriptionSession session}) async {
    if (session._state is _VoiceSessionDisposed) return;
    if (session._state is! _VoiceSessionClosing) invalidate(session: session);

    final prewarmFuture = session._prewarmFuture;
    if (prewarmFuture != null) {
      try {
        await prewarmFuture.timeout(_recorderPrewarmTimeout);
      } on TimeoutException catch (error, stackTrace) {
        logw("Timed out waiting for recorder prewarm during disposal", error, stackTrace);
      } catch (error, stackTrace) {
        logw("Recorder prewarm failed during disposal", error, stackTrace);
      }
    }

    final startFuture = session._startFuture;
    if (startFuture != null) {
      try {
        await startFuture;
      } on TranscriptionCancelledError {
        // Invalidation deliberately turns a late startup completion into cancellation.
      } catch (error, stackTrace) {
        logw("Voice recording start settled with an error during disposal", error, stackTrace);
      }
    }

    final stopFuture = session._stopFuture;
    if (stopFuture != null) {
      try {
        await stopFuture;
      } catch (error, stackTrace) {
        logw("Voice recording stop settled with an error during disposal", error, stackTrace);
      }
    }

    final cancelFuture = session._cancelFuture;
    if (cancelFuture != null) {
      try {
        await cancelFuture;
      } catch (error, stackTrace) {
        logw("Voice recording cancellation settled with an error during disposal", error, stackTrace);
      }
    }

    final retainedArtifact = switch (session._state) {
      _VoiceSessionClosingWithArtifact(:final artifact) => artifact,
      _VoiceSessionClosingWithoutArtifact() || _VoiceSessionDisposed() => null,
      _VoiceSessionIdle() ||
      _VoiceSessionStarting() ||
      _VoiceSessionAsyncRecording() ||
      _VoiceSessionRealtimeRecording() ||
      _VoiceSessionRealtimeFallback() ||
      _VoiceSessionRealtimeFinishing() ||
      _VoiceSessionStopping() ||
      _VoiceSessionInitialTranscribing() ||
      _VoiceSessionRetryTranscribing() ||
      _VoiceSessionRetryPending() => null,
    };
    await _disposeRealtimeInteraction(session: session, sendCancel: true, stopCapture: true);
    if (retainedArtifact != null) {
      await session._captureSession.deleteArtifact(artifact: retainedArtifact);
    }

    try {
      await session._captureSession.close();
    } catch (error, stackTrace) {
      logw("Failed to close voice capture session", error, stackTrace);
    }
    await session._maxDurationReachedController.close();
    await session._realtimeTerminalController.close();
    await session._previewController.close();
    session._state = const _VoiceSessionDisposed();
  }

  Future<void> _disposeRealtimeInteraction({
    required VoiceTranscriptionSession session,
    required bool sendCancel,
    required bool stopCapture,
  }) async {
    final interaction = session._realtime;
    if (interaction == null) {
      final captureStartFuture = session._realtimeCaptureStartFuture;
      if (stopCapture && captureStartFuture != null) {
        try {
          await captureStartFuture;
        } on VoiceCaptureError {
          if (identical(session._realtimeCaptureStartFuture, captureStartFuture)) {
            session._realtimeCaptureStartFuture = null;
          }
          return;
        }
        if (!identical(session._realtimeCaptureStartFuture, captureStartFuture)) return;
        session._realtimeCaptureStartFuture = null;
        await session._captureSession.cancel();
      }
      return;
    }
    if (identical(session._realtime, interaction)) session._realtime = null;
    interaction.forwardFrames = false;
    if (!interaction.ready.isCompleted && !interaction.startFailure.isCompleted) {
      interaction.startFailure.complete(VoiceTranscriptionError.cancelled());
    }
    await interaction.cancelSubscriptions();
    try {
      if (sendCancel) {
        await interaction.session.cancel();
      } else {
        await interaction.session.close();
      }
    } on Exception catch (error, stackTrace) {
      logw("Failed to close realtime voice connection", error, stackTrace);
    }
    if (stopCapture) {
      final terminalStop = interaction.captureStopFuture;
      if (terminalStop != null) {
        await terminalStop;
      } else if (!interaction.captureStopped) {
        await session._captureSession.cancel();
        interaction.captureStopped = true;
      }
      await session._captureSession.releaseOperation();
    }
  }

  static void _setPreview({
    required VoiceTranscriptionSession session,
    required VoiceTranscriptionPreview preview,
  }) {
    session._preview = preview;
    if (!session._previewController.isClosed) session._previewController.add(preview);
  }

  static void _ensureGeneration({
    required VoiceTranscriptionSession session,
    required int generation,
  }) {
    if (!_ownsGeneration(session: session, generation: generation)) {
      throw VoiceTranscriptionError.cancelled();
    }
  }

  static bool _ownsGeneration({
    required VoiceTranscriptionSession session,
    required int generation,
  }) =>
      session._generation == generation &&
      session._state is! _VoiceSessionClosing &&
      session._state is! _VoiceSessionDisposed;

  static void _restoreIdleAfterFailure({
    required VoiceTranscriptionSession session,
    required int generation,
  }) {
    if (_ownsGeneration(session: session, generation: generation)) {
      session._state = const _VoiceSessionIdle();
      _setPreview(
        session: session,
        preview: const VoiceTranscriptionPreview(confirmedText: "", provisionalText: ""),
      );
    }
  }

  static void _startMaxDurationTimer({required VoiceTranscriptionSession session}) {
    _cancelMaxDurationTimer(session: session);
    session._maxDurationTimer = Timer(maxRecordingDuration, () {
      if ((session._state is _VoiceSessionAsyncRecording || session._state is _VoiceSessionRealtimeRecording) &&
          !session._maxDurationReachedController.isClosed) {
        session._maxDurationReachedController.add(null);
      }
    });
  }

  static void _cancelMaxDurationTimer({required VoiceTranscriptionSession session}) {
    session._maxDurationTimer?.cancel();
    session._maxDurationTimer = null;
  }
}

class VoiceTranscriptionSession._({
  required final VoiceCaptureSession _captureSession,
  required final String? _projectId,
}) {
  final StreamController<void> _maxDurationReachedController = StreamController<void>.broadcast();
  final StreamController<VoiceRealtimeTerminalCause> _realtimeTerminalController =
      StreamController<VoiceRealtimeTerminalCause>.broadcast();
  final StreamController<VoiceTranscriptionPreview> _previewController =
      StreamController<VoiceTranscriptionPreview>.broadcast();

  _VoiceSessionState _state = const _VoiceSessionIdle();
  VoiceTranscriptionPreview _preview = const VoiceTranscriptionPreview(confirmedText: "", provisionalText: "");
  ProjectGlossaryKey? _availableProjectGlossaryKey;
  ProjectGlossaryKey? _interactionProjectGlossaryKey;
  Future<void>? _projectGlossaryKeyLoad;
  _RealtimeVoiceInteraction? _realtime;
  Future<VoiceRealtimeCapture>? _realtimeCaptureStartFuture;
  VoiceCapabilitiesDiscoveryOutcome? _capabilitiesOutcome;
  Future<void>? _capabilitiesDiscoveryFuture;
  Future<void>? _prewarmFuture;
  Future<void>? _startFuture;
  Future<VoiceRecordingArtifact>? _stopFuture;
  Future<void>? _cancelFuture;
  Timer? _maxDurationTimer;
  int _generation = 0;
}

final class const VoiceTranscriptionPreview({
  required final String confirmedText,
  required final String provisionalText,
});

// ignore: use_primary_constructors, dart_style 3.1.12 crashes on enum primary constructors here.
enum VoiceRealtimeTerminalCause { completed, limitReached, failed }

sealed class const _VoiceStartMode() {
  ProjectGlossaryKey? get projectKey;
}

final class const _AsyncVoiceStartMode({
  @override required final ProjectGlossaryKey? projectKey,
}) extends _VoiceStartMode;

final class const _RealtimeVoiceStartMode({
  @override required final ProjectGlossaryKey? projectKey,
}) extends _VoiceStartMode;

final class _RealtimeVoiceInteraction({
  required final int generation,
  required final VoiceRealtimeCapture capture,
  required final VoiceRealtimeConnection session,
}) {
  final Completer<void> ready = Completer<void>();
  final Completer<VoiceTranscriptionError> startFailure = Completer<VoiceTranscriptionError>();
  StreamSubscription<Uint8List>? frameSubscription;
  StreamSubscription<VoiceRealtimeCaptureFormat>? formatSubscription;
  StreamSubscription<VoiceRealtimeConnectionEvent>? eventSubscription;
  Future<void>? captureStopFuture;
  Future<void>? fallbackTransition;
  VoiceRealtimeConnectionEvent? terminalEvent;
  VoiceTranscriptionError? terminalFailure;
  VoiceTranscriptionError? captureFailure;
  Exception? fallbackCause;
  StackTrace? fallbackStackTrace;
  String confirmedText = "";
  String provisionalText = "";
  bool forwardFrames = false;
  bool sentAudio = false;
  bool fallbackRequested = false;
  bool captureStopped = false;

  Future<void> cancelSubscriptions() async {
    await frameSubscription?.cancel();
    frameSubscription = null;
    await formatSubscription?.cancel();
    formatSubscription = null;
    await eventSubscription?.cancel();
    eventSubscription = null;
  }
}

final class const _RealtimePreAudioFallback({
  required final Exception cause,
  required final StackTrace innerStackTrace,
}) implements Exception;

sealed class const _VoiceSessionState();

final class const _VoiceSessionIdle() extends _VoiceSessionState;

final class const _VoiceSessionStarting() extends _VoiceSessionState;

final class const _VoiceSessionAsyncRecording() extends _VoiceSessionState;

final class const _VoiceSessionRealtimeRecording() extends _VoiceSessionState;

final class const _VoiceSessionRealtimeFallback({required final Future<void> transition}) extends _VoiceSessionState;

final class const _VoiceSessionRealtimeFinishing() extends _VoiceSessionState;

final class const _VoiceSessionStopping() extends _VoiceSessionState;

final class const _VoiceSessionInitialTranscribing({required final VoiceRecordingArtifact artifact})
    extends _VoiceSessionState;

final class const _VoiceSessionRetryPending({required final VoiceRecordingArtifact artifact})
    extends _VoiceSessionState;

final class const _VoiceSessionRetryTranscribing({required final VoiceRecordingArtifact artifact})
    extends _VoiceSessionState;

sealed class const _VoiceSessionClosing() extends _VoiceSessionState;

final class const _VoiceSessionClosingWithoutArtifact() extends _VoiceSessionClosing;

final class const _VoiceSessionClosingWithArtifact({required final VoiceRecordingArtifact artifact})
    extends _VoiceSessionClosing;

final class const _VoiceSessionDisposed() extends _VoiceSessionState;

sealed class const VoiceTranscriptionError._(final String message) implements Exception {
  factory microphonePermissionDenied({required Object innerError}) = MicrophonePermissionDeniedError._;

  factory recordingFailed({required Object innerError}) = RecordingFailedError._;

  factory notRecording() = NotRecordingError._;

  factory notAuthenticated() = NotAuthenticatedVoiceError._;

  factory retryableServerError({required int statusCode}) = RetryableServerVoiceError._;

  factory serverError({required int statusCode}) = ServerVoiceError._;

  factory emptyTranscript() = EmptyTranscriptError._;

  factory networkError() = NetworkVoiceError._;

  factory missingRecording() = MissingRecordingArtifactError._;

  factory cancelled() = TranscriptionCancelledError._;

  factory contractFailure({
    required String reason,
    required Object innerError,
    required StackTrace? innerStackTrace,
  }) = ContractVoiceError._;

  factory realtimeContract({
    required String reason,
    required Object innerError,
    required StackTrace? innerStackTrace,
  }) = ContractVoiceError._;

  factory realtimeQuota({
    required Object? innerError,
    required StackTrace? innerStackTrace,
  }) = RealtimeQuotaVoiceError._;

  factory realtimeTemporaryUnavailable({
    required Object? innerError,
    required StackTrace? innerStackTrace,
  }) = RealtimeTemporaryUnavailableVoiceError._;

  factory realtimeInterrupted({
    required Object? innerError,
    required StackTrace? innerStackTrace,
  }) = RealtimeInterruptedVoiceError._;

  @override
  String toString() => "VoiceTranscriptionError: $message";
}

final class const MicrophonePermissionDeniedError._({required final Object innerError})
    extends VoiceTranscriptionError {
  this : super._("Microphone permission denied");
}

final class const RecordingFailedError._({required final Object innerError}) extends VoiceTranscriptionError {
  this : super._("Recording failed");
}

final class const NotRecordingError._() extends VoiceTranscriptionError {
  this : super._("Not currently recording");
}

final class const NotAuthenticatedVoiceError._() extends VoiceTranscriptionError {
  this : super._("Not authenticated");
}

final class const RetryableServerVoiceError._({required final int statusCode}) extends VoiceTranscriptionError {
  this : super._("Retryable server error ($statusCode)");
}

final class const ServerVoiceError._({required final int statusCode}) extends VoiceTranscriptionError {
  this : super._("Server error ($statusCode)");
}

final class const EmptyTranscriptError._() extends VoiceTranscriptionError {
  this : super._("Server returned empty transcript");
}

final class const NetworkVoiceError._() extends VoiceTranscriptionError {
  this : super._("Network error");
}

final class const MissingRecordingArtifactError._() extends VoiceTranscriptionError {
  this : super._("Saved recording is no longer available");
}

final class const TranscriptionCancelledError._() extends VoiceTranscriptionError {
  this : super._("Transcription cancelled");
}

final class const ContractVoiceError._({
  required final String reason,
  required final Object innerError,
  required final StackTrace? innerStackTrace,
}) extends VoiceTranscriptionError {
  this : super._("Voice contract failure: $reason");
}

final class const RealtimeQuotaVoiceError._({
  required final Object? innerError,
  required final StackTrace? innerStackTrace,
}) extends VoiceTranscriptionError {
  this : super._("Realtime voice quota exhausted");
}

final class const RealtimeTemporaryUnavailableVoiceError._({
  required final Object? innerError,
  required final StackTrace? innerStackTrace,
}) extends VoiceTranscriptionError {
  this : super._("Realtime voice temporarily unavailable");
}

final class const RealtimeInterruptedVoiceError._({
  required final Object? innerError,
  required final StackTrace? innerStackTrace,
}) extends VoiceTranscriptionError {
  this : super._("Realtime voice interrupted");
}

final class const VoiceRealtimePartialTranscriptionError({
  required final String confirmedText,
  required final VoiceTranscriptionError failure,
}) extends VoiceTranscriptionError {
  this : super._("Realtime transcription ended after confirmed partial text");
}
