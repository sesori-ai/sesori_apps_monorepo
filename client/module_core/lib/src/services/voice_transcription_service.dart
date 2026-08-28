import "dart:async";

import "package:injectable/injectable.dart";

import "../logging/logging.dart";
import "../platform/voice_capture.dart";
import "../repositories/voice_repository.dart";

const maxRecordingDuration = Duration(minutes: 15);
const _recorderPrewarmTimeout = Duration(seconds: 2);

@lazySingleton
class VoiceTranscriptionService({
  required final VoiceRepository _repository,
  required final VoiceCapture _capture,
}) {
  VoiceTranscriptionSession createSession() => VoiceTranscriptionSession._(
    captureSession: _capture.createSession(),
  );

  Stream<double> amplitudeStream({required VoiceTranscriptionSession session}) =>
      session._captureSession.amplitudeStream;

  Stream<void> maxDurationReachedStream({required VoiceTranscriptionSession session}) =>
      session._maxDurationReachedController.stream;

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

    final operation = _start(session: session);
    session._startFuture = operation;
    return operation.whenComplete(() {
      if (identical(session._startFuture, operation)) session._startFuture = null;
    });
  }

  Future<void> _start({required VoiceTranscriptionSession session}) async {
    final generation = ++session._generation;
    session._state = const _VoiceSessionStarting();

    try {
      final prewarmFuture = session._prewarmFuture;
      if (prewarmFuture != null) await prewarmFuture.timeout(_recorderPrewarmTimeout);
      if (!_ownsGeneration(session: session, generation: generation)) {
        throw VoiceTranscriptionError.cancelled();
      }

      await session._captureSession.start();
      if (!_ownsGeneration(session: session, generation: generation)) {
        await session._captureSession.cancel();
        throw VoiceTranscriptionError.cancelled();
      }

      session._state = const _VoiceSessionRecording();
      _startMaxDurationTimer(session: session);
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

  Future<String> stopAndTranscribe({required VoiceTranscriptionSession session}) async {
    if (session._state is! _VoiceSessionRecording) {
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
    try {
      final outcome = await _repository.transcribe(
        audioFilePath: artifact.path,
        mimeType: artifact.mimeType,
      );
      if (!_ownsGeneration(session: session, generation: generation)) {
        throw VoiceTranscriptionError.cancelled();
      }

      return switch (outcome) {
        VoiceTranscriptionSuccess(:final transcript) => transcript,
        VoiceTranscriptionNotAuthenticated() => throw VoiceTranscriptionError.notAuthenticated(),
        VoiceTranscriptionRetryableServerFailure(:final statusCode) => _retainAndThrow(
          session: session,
          artifact: artifact,
          error: VoiceTranscriptionError.retryableServerError(statusCode: statusCode),
        ),
        VoiceTranscriptionTerminalServerFailure(:final statusCode) => throw VoiceTranscriptionError.serverError(
          statusCode: statusCode,
        ),
        VoiceTranscriptionNetworkFailure() => _retainAndThrow(
          session: session,
          artifact: artifact,
          error: VoiceTranscriptionError.networkError(),
        ),
        VoiceTranscriptionUnexpectedFailure() => throw VoiceTranscriptionError.recordingFailed(innerError: outcome),
        VoiceTranscriptionEmptyTranscript() => throw VoiceTranscriptionError.emptyTranscript(),
      };
    } finally {
      final ownsGeneration = _ownsGeneration(session: session, generation: generation);
      if (ownsGeneration) {
        try {
          if (releaseCaptureOperation) await session._captureSession.releaseOperation();
        } finally {
          if (session._state is! _VoiceSessionRetryPending) {
            await session._captureSession.deleteArtifact(artifact: artifact);
            session._state = const _VoiceSessionIdle();
          }
        }
      }
    }
  }

  Never _retainAndThrow({
    required VoiceTranscriptionSession session,
    required VoiceRecordingArtifact artifact,
    required VoiceTranscriptionError error,
  }) {
    session._state = _VoiceSessionRetryPending(artifact: artifact);
    throw error;
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
    session._state = switch (state) {
      _VoiceSessionInitialTranscribing(:final artifact) ||
      _VoiceSessionRetryTranscribing(:final artifact) ||
      _VoiceSessionRetryPending(:final artifact) => _VoiceSessionClosingWithArtifact(artifact: artifact),
      _VoiceSessionIdle() ||
      _VoiceSessionStarting() ||
      _VoiceSessionRecording() ||
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
      if (session._state is _VoiceSessionRecording && !session._maxDurationReachedController.isClosed) {
        session._maxDurationReachedController.add(null);
      }
    });
  }

  static void _cancelMaxDurationTimer({required VoiceTranscriptionSession session}) {
    session._maxDurationTimer?.cancel();
    session._maxDurationTimer = null;
  }
}

class VoiceTranscriptionSession._({required final VoiceCaptureSession _captureSession}) {
  final StreamController<void> _maxDurationReachedController = StreamController<void>.broadcast();

  _VoiceSessionState _state = const _VoiceSessionIdle();
  Future<void>? _prewarmFuture;
  Future<void>? _startFuture;
  Future<VoiceRecordingArtifact>? _stopFuture;
  Future<void>? _cancelFuture;
  Timer? _maxDurationTimer;
  int _generation = 0;
}

sealed class const _VoiceSessionState();

final class const _VoiceSessionIdle() extends _VoiceSessionState;

final class const _VoiceSessionStarting() extends _VoiceSessionState;

final class const _VoiceSessionRecording() extends _VoiceSessionState;

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
