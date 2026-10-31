import "dart:async";
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart" show ErrorResponse, SuccessResponse;
import "package:sesori_shared/sesori_shared.dart" show Project, ProjectGlossaryKey;

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../foundation/models/voice/voice_dictation_outcome.dart";
import "../foundation/models/voice/voice_live.dart";
import "../foundation/models/voice/voice_mode.dart";
import "../foundation/models/voice/voice_transcription_error.dart";
import "../logging/logging.dart";
import "../platform/voice_capture.dart";
import "../repositories/project_repository.dart";
import "../repositories/voice_mode_repository.dart";
import "../repositories/voice_repository.dart";
import "live_dictation_run.dart";

const maxRecordingDuration = Duration(minutes: 15);
const _recorderPrewarmTimeout = Duration(seconds: 2);

@lazySingleton
class VoiceTranscriptionService({
  required final VoiceRepository _repository,
  required final ProjectRepository _projectRepository,
  required final VoiceModeRepository _voiceModeRepository,
  required final VoiceCapture _capture,
  required final ConnectionService _connectionService,
}) {
  // Lets a new composer start with the key its project had last time, because a
  // live dictation can't wait for the bridge to answer.
  final Map<({String computerId, String projectId}), ProjectGlossaryKey> _rememberedProjectGlossaryKeys = {};

  /// [allowLive] is false where dictation keeps recording first, whatever the
  /// voice mode says. A change of mode applies from the next session.
  VoiceTranscriptionSession createSession({required String? projectId, required bool allowLive}) {
    final session = VoiceTranscriptionSession._(
      captureSession: _capture.createSession(),
      projectId: projectId == null || projectId.trim().isEmpty ? null : projectId,
    );
    session._projectGlossaryKey = _rememberedProjectGlossaryKey(projectId: session._projectId);
    // Asks even with a remembered key: this request is also what keeps the
    // project's glossary refreshed on the bridge.
    _loadProjectGlossaryKeyIfIdle(session: session);
    if (allowLive) unawaited(_loadLiveAvailability(session: session));
    return session;
  }

  /// Both answers can take seconds, so a hold never waits for them (D26). The
  /// support check spawns a process on Linux, so it runs only when live is on.
  Future<void> _loadLiveAvailability({required VoiceTranscriptionSession session}) async {
    try {
      await _voiceModeRepository.load();
    } catch (error, stackTrace) {
      logw("Could not load the voice mode; keeping the last one", error, stackTrace);
    }
    if (_voiceModeRepository.onDeviceEnabled) {
      session._canRunOnDevice =
          await _repository.prepareOnDevice() && await session._captureSession.supportsPcmStream();
    }
    if (_voiceModeRepository.mode is! VoiceModeLive) return;
    session._canRunLive = await session._captureSession.supportsPcmStream();
  }

  /// The two switches are independent: the device's engine runs whenever it can,
  /// and the live switch decides whether the words show while the user speaks.
  VoiceDictationMode _chooseMode({required VoiceTranscriptionSession session}) {
    final liveEnabled = _voiceModeRepository.mode is VoiceModeLive;
    if (session._canRunOnDevice)
      return liveEnabled ? VoiceDictationMode.onDeviceLive : VoiceDictationMode.onDeviceHidden;
    return session._canRunLive && liveEnabled ? VoiceDictationMode.live : VoiceDictationMode.afterRecording;
  }

  ProjectGlossaryKey? _rememberedProjectGlossaryKey({required String? projectId}) {
    final computerId = _connectionService.currentStatus.targetBridgeId;
    if (projectId == null || computerId == null) return null;
    return _rememberedProjectGlossaryKeys[(computerId: computerId, projectId: projectId)];
  }

  void _loadProjectGlossaryKeyIfIdle({required VoiceTranscriptionSession session}) {
    final projectId = session._projectId;
    if (projectId == null ||
        session._projectGlossaryKeyLoad != null ||
        session._state is _VoiceSessionClosing ||
        session._state is _VoiceSessionDisposed) {
      return;
    }

    late final Future<void> tracked;
    tracked = _loadProjectGlossaryKey(session: session, projectId: projectId).whenComplete(() {
      if (identical(session._projectGlossaryKeyLoad, tracked)) {
        session._projectGlossaryKeyLoad = null;
      }
    });
    session._projectGlossaryKeyLoad = tracked;
  }

  Future<void> _loadProjectGlossaryKey({
    required VoiceTranscriptionSession session,
    required String projectId,
  }) async {
    // Read before asking, so the answer is remembered for the computer it came from.
    final computerId = _connectionService.currentStatus.targetBridgeId;
    try {
      final response = await _projectRepository.getProject(projectId: projectId);
      if (session._state is _VoiceSessionClosing || session._state is _VoiceSessionDisposed) return;
      switch (response) {
        case SuccessResponse(data: Project(voiceGlossaryKey: final key?)):
          session._projectGlossaryKey = key;
          if (computerId != null) {
            _rememberedProjectGlossaryKeys[(computerId: computerId, projectId: projectId)] = key;
          }
        case SuccessResponse():
          // No key in this answer, so whatever is already known stays.
          break;
        case ErrorResponse(:final error):
          logw("Could not load optional project voice context; continuing unscoped", error);
      }
    } catch (error, stackTrace) {
      logw("Could not load optional project voice context; continuing unscoped", error, stackTrace);
    }
  }

  void _logProjectGlossaryUse({required VoiceTranscriptionSession session}) {
    final glossary = session._projectGlossaryKey == null ? "no project glossary" : "the project glossary";
    logi("Transcribing with $glossary");
  }

  Stream<double> amplitudeStream({required VoiceTranscriptionSession session}) =>
      session._captureSession.amplitudeStream;

  Stream<void> maxDurationReachedStream({required VoiceTranscriptionSession session}) =>
      session._maxDurationReachedController.stream;

  /// Reports a live dictation while the user may still be holding. Delivered
  /// synchronously, so a release can never overtake an ending.
  Stream<VoiceLiveEvent> liveEventStream({required VoiceTranscriptionSession session}) =>
      session._liveEventsController.stream;

  /// Whether the dictation shows its words while the user speaks.
  bool isLive({required VoiceTranscriptionSession session}) {
    final state = session._state;
    return state is _VoiceSessionLiveRecording && state.mode != VoiceDictationMode.onDeviceHidden;
  }

  Future<void> prewarm({required VoiceTranscriptionSession session}) {
    if (session._state is _VoiceSessionClosing || session._state is _VoiceSessionDisposed) {
      return Future<void>.value();
    }

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

  Future<void> start({required VoiceTranscriptionSession session}) {
    if (session._state is! _VoiceSessionIdle) {
      logw("Voice recording operation already in progress");
      return Future<void>.value();
    }

    return _trackStart(
      session: session,
      operation: _start(session: session),
    );
  }

  Future<void> _trackStart({required VoiceTranscriptionSession session, required Future<void> operation}) {
    session._startFuture = operation;
    return operation.whenComplete(() {
      if (identical(session._startFuture, operation)) session._startFuture = null;
    });
  }

  Future<void> _start({required VoiceTranscriptionSession session}) async {
    final generation = ++session._generation;
    session._state = const _VoiceSessionStarting();
    if (session._projectGlossaryKey == null) _loadProjectGlossaryKeyIfIdle(session: session);
    // Read once, here: the dictation keeps this mode whatever the switches do next.
    final mode = _chooseMode(session: session);

    try {
      final prewarmFuture = session._prewarmFuture;
      if (prewarmFuture != null) await prewarmFuture.timeout(_recorderPrewarmTimeout);
      if (!_ownsGeneration(session: session, generation: generation)) {
        throw VoiceTranscriptionError.cancelled();
      }

      switch (mode) {
        case VoiceDictationMode.afterRecording:
          await _startFileCapture(session: session, generation: generation, fellBackFromLive: false);
        case VoiceDictationMode.live:
          _logProjectGlossaryUse(session: session);
          await _startLiveCapture(
            session: session,
            generation: generation,
            mode: mode,
            connecting: _repository.openRealtime(
              sampleRate: voiceCapturePcmSampleRate,
              projectKey: session._projectGlossaryKey,
            ),
          );
        case VoiceDictationMode.onDeviceLive || VoiceDictationMode.onDeviceHidden:
          await _startLiveCapture(
            session: session,
            generation: generation,
            mode: mode,
            connecting: _repository.openOnDevice(sampleRate: voiceCapturePcmSampleRate),
          );
      }
    } on VoiceCapturePermissionDenied catch (error) {
      _restoreIdleAfterFailure(session: session, generation: generation);
      throw VoiceTranscriptionError.microphonePermissionDenied(innerError: error);
    } on VoiceCaptureError catch (error) {
      _restoreIdleAfterFailure(session: session, generation: generation);
      throw VoiceTranscriptionError.recordingFailed(innerError: error);
    } on VoiceTranscriptionError {
      rethrow;
    } catch (error, stackTrace) {
      loge("Failed to start voice recording", error, stackTrace);
      _restoreIdleAfterFailure(session: session, generation: generation);
      throw VoiceTranscriptionError.recordingFailed(innerError: error);
    }
  }

  Future<void> _startFileCapture({
    required VoiceTranscriptionSession session,
    required int generation,
    required bool fellBackFromLive,
  }) async {
    await session._captureSession.start();
    if (!_ownsGeneration(session: session, generation: generation)) {
      await session._captureSession.cancel();
      throw VoiceTranscriptionError.cancelled();
    }

    session._state = _VoiceSessionRecording(fellBackFromLive: fellBackFromLive);
    _startMaxDurationTimer(session: session);
  }

  /// The socket starts with the microphone, so first words come sooner by however
  /// long the microphone takes. Whatever stops the dictation before the run takes
  /// the socket closes it. A microphone that refuses to stream may still record a
  /// file (D21). A denied permission is not that, and goes up as itself.
  Future<void> _startLiveCapture({
    required VoiceTranscriptionSession session,
    required int generation,
    required VoiceDictationMode mode,
    required Future<VoiceRealtimeConnection> connecting,
  }) async {
    final captureSession = session._captureSession;
    // A failure waits for the run or the close below, which is not an unhandled one.
    connecting.ignore();
    final Stream<Uint8List> frames;
    try {
      frames = await captureSession.startPcmStream();
    } on VoiceCaptureFailed catch (error, stackTrace) {
      logw("Live capture could not start; recording instead", error, stackTrace);
      unawaited(_closeUnusedSocket(connecting: connecting));
      await captureSession.cancel();
      await _startFileCapture(session: session, generation: generation, fellBackFromLive: true);
      return;
    } on Object {
      unawaited(_closeUnusedSocket(connecting: connecting));
      rethrow;
    }
    if (!_ownsGeneration(session: session, generation: generation)) {
      unawaited(_closeUnusedSocket(connecting: connecting));
      await captureSession.cancel();
      throw VoiceTranscriptionError.cancelled();
    }

    final run = LiveDictationRun(
      capture: captureSession,
      onWords: ({required words}) => session._liveEventsController.add(VoiceLiveWordsChanged(words: words)),
      frames: frames,
      connecting: connecting,
    );
    session._state = _VoiceSessionLiveRecording(run: run, mode: mode);
    _startMaxDurationTimer(session: session);
    unawaited(_handleLiveEndingWhileHolding(session: session, generation: generation, run: run, mode: mode));
  }

  Future<void> _closeUnusedSocket({required Future<VoiceRealtimeConnection> connecting}) async {
    try {
      final connection = await connecting;
      await connection.cancel();
    } on VoiceTranscriptionError catch (error, stackTrace) {
      logw("A live socket that was no longer needed could not open", error, stackTrace);
    }
  }

  /// A release hands the ending to [stopAndTranscribe], and a cancel takes the
  /// generation, so this acts only on a session that ended by itself.
  Future<void> _handleLiveEndingWhileHolding({
    required VoiceTranscriptionSession session,
    required int generation,
    required LiveDictationRun run,
    required VoiceDictationMode mode,
  }) async {
    final ending = await run.ended;
    if (!_ownsGeneration(session: session, generation: generation)) return;
    if (session._state is! _VoiceSessionLiveRecording) return;

    _cancelMaxDurationTimer(session: session);
    switch (ending) {
      case LiveDictationFellBack():
        session._state = const _VoiceSessionStarting();
        unawaited(
          _trackStart(
            session: session,
            operation: _fallBackFromLive(session: session, generation: generation),
          ),
        );
      case LiveDictationEnded(:final transcript, :final outcome):
        session._state = const _VoiceSessionIdle();
        session._liveEventsController.add(VoiceLiveEnded(transcript: transcript, outcome: outcome, mode: mode));
      case LiveDictationFailed(:final error):
        session._state = const _VoiceSessionIdle();
        session._liveEventsController.add(VoiceLiveFailed(error: error));
      case LiveDictationCancelled():
        session._state = const _VoiceSessionIdle();
    }
  }

  Future<void> _fallBackFromLive({required VoiceTranscriptionSession session, required int generation}) async {
    try {
      await _startFileCapture(session: session, generation: generation, fellBackFromLive: true);
      session._liveEventsController.add(const VoiceLiveFellBack());
    } on TranscriptionCancelledError {
      // A cancel or disposal took over while the recorder was starting.
    } catch (error, stackTrace) {
      logw("Could not fall back from live dictation", error, stackTrace);
      if (!_ownsGeneration(session: session, generation: generation)) return;
      session._state = const _VoiceSessionIdle();
      session._liveEventsController.add(
        VoiceLiveFailed(error: VoiceTranscriptionError.recordingFailed(innerError: error)),
      );
    }
  }

  Future<VoiceDictationResult> stopAndTranscribe({required VoiceTranscriptionSession session}) async {
    // A hold can end while a failed live session is still restarting the recorder.
    final restart = session._startFuture;
    if (session._state is _VoiceSessionStarting && restart != null) await restart;

    final state = session._state;
    if (state is _VoiceSessionLiveRecording)
      return await _finishLive(session: session, run: state.run, mode: state.mode);
    if (state is! _VoiceSessionRecording) throw VoiceTranscriptionError.notRecording();
    return await _stopFileCapture(
      session: session,
      outcome: state.fellBackFromLive ? VoiceDictationOutcome.interrupted : VoiceDictationOutcome.finished,
    );
  }

  Future<VoiceDictationResult> _finishLive({
    required VoiceTranscriptionSession session,
    required LiveDictationRun run,
    required VoiceDictationMode mode,
  }) async {
    _cancelMaxDurationTimer(session: session);
    final generation = session._generation;
    session._state = _VoiceSessionLiveFinishing(run: run);

    final ending = await run.finish();
    if (!_ownsGeneration(session: session, generation: generation)) {
      throw VoiceTranscriptionError.cancelled();
    }
    session._state = const _VoiceSessionIdle();

    switch (ending) {
      case LiveDictationEnded(:final transcript, :final outcome):
        return VoiceDictationResult(transcript: transcript, outcome: outcome, mode: mode);
      // The user has already released, so there is nothing left to record.
      case LiveDictationFailed(:final error) || LiveDictationFellBack(:final error):
        throw error;
      case LiveDictationCancelled():
        throw VoiceTranscriptionError.cancelled();
    }
  }

  Future<VoiceDictationResult> _stopFileCapture({
    required VoiceTranscriptionSession session,
    required VoiceDictationOutcome outcome,
  }) async {
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
    final transcript = await _transcribeArtifact(
      session: session,
      artifact: artifact,
      generation: generation,
      releaseCaptureOperation: true,
    );
    return VoiceDictationResult(transcript: transcript, outcome: outcome, mode: VoiceDictationMode.afterRecording);
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
    _logProjectGlossaryUse(session: session);
    try {
      final outcome = await _repository.transcribe(
        audioFilePath: artifact.path,
        mimeType: artifact.mimeType,
        projectGlossaryKey: session._projectGlossaryKey,
      );
      if (!_ownsGeneration(session: session, generation: generation)) {
        throw VoiceTranscriptionError.cancelled();
      }

      switch (outcome) {
        case VoiceTranscriptionSuccess(:final transcript):
          return transcript;
        case VoiceTranscriptionNotAuthenticated():
          throw VoiceTranscriptionError.notAuthenticated(innerError: null);
        case VoiceTranscriptionRetryableServerFailure(:final statusCode):
          retainedFailure = VoiceTranscriptionError.retryableServerError(statusCode: statusCode, innerError: null);
          throw retainedFailure;
        case VoiceTranscriptionTerminalServerFailure(:final statusCode):
          throw VoiceTranscriptionError.serverError(statusCode: statusCode, innerError: null);
        case VoiceTranscriptionNetworkFailure():
          retainedFailure = VoiceTranscriptionError.networkError(innerError: null);
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
      case _VoiceSessionStarting() || _VoiceSessionRecording():
        await session._captureSession.cancel();
      case _VoiceSessionLiveRecording(:final run) || _VoiceSessionLiveFinishing(:final run):
        await run.cancel();
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
    if (state case _VoiceSessionLiveRecording(:final run) || _VoiceSessionLiveFinishing(:final run)) {
      session._cancelFuture = run.cancel();
    }
    session._state = switch (state) {
      _VoiceSessionInitialTranscribing(:final artifact) ||
      _VoiceSessionRetryTranscribing(:final artifact) ||
      _VoiceSessionRetryPending(:final artifact) => _VoiceSessionClosingWithArtifact(artifact: artifact),
      _VoiceSessionIdle() ||
      _VoiceSessionStarting() ||
      _VoiceSessionRecording() ||
      _VoiceSessionLiveRecording() ||
      _VoiceSessionLiveFinishing() ||
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
      _VoiceSessionRecording() ||
      _VoiceSessionLiveRecording() ||
      _VoiceSessionLiveFinishing() ||
      _VoiceSessionStopping() ||
      _VoiceSessionInitialTranscribing() ||
      _VoiceSessionRetryTranscribing() ||
      _VoiceSessionRetryPending() => null,
    };
    if (retainedArtifact != null) {
      await session._captureSession.deleteArtifact(artifact: retainedArtifact);
    }

    try {
      await session._captureSession.close();
    } catch (error, stackTrace) {
      logw("Failed to close voice capture session", error, stackTrace);
    }
    await session._maxDurationReachedController.close();
    await session._liveEventsController.close();
    session._state = const _VoiceSessionDisposed();
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
    }
  }

  static void _startMaxDurationTimer({required VoiceTranscriptionSession session}) {
    _cancelMaxDurationTimer(session: session);
    session._maxDurationTimer = Timer(maxRecordingDuration, () {
      final recording = session._state is _VoiceSessionRecording || session._state is _VoiceSessionLiveRecording;
      if (recording && !session._maxDurationReachedController.isClosed) {
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
  final StreamController<VoiceLiveEvent> _liveEventsController = StreamController<VoiceLiveEvent>.broadcast(sync: true);

  _VoiceSessionState _state = const _VoiceSessionIdle();
  Future<void>? _prewarmFuture;
  Future<void>? _startFuture;
  Future<VoiceRecordingArtifact>? _stopFuture;
  Future<void>? _cancelFuture;
  Future<void>? _projectGlossaryKeyLoad;
  Timer? _maxDurationTimer;
  ProjectGlossaryKey? _projectGlossaryKey;

  /// False until the voice mode says live and this host can stream, which is also
  /// the answer for a session that doesn't allow live.
  bool _canRunLive = false;

  /// False until the kill switch and this device both allow it, which is also the
  /// answer for a session that doesn't allow live.
  bool _canRunOnDevice = false;
  int _generation = 0;
}

sealed class const _VoiceSessionState();

final class const _VoiceSessionIdle() extends _VoiceSessionState;

final class const _VoiceSessionStarting() extends _VoiceSessionState;

/// [fellBackFromLive] means the first words may be missing (D33).
final class const _VoiceSessionRecording({required final bool fellBackFromLive}) extends _VoiceSessionState;

final class const _VoiceSessionLiveRecording({
  required final LiveDictationRun run,
  required final VoiceDictationMode mode,
}) extends _VoiceSessionState;

final class const _VoiceSessionLiveFinishing({required final LiveDictationRun run}) extends _VoiceSessionState;

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
