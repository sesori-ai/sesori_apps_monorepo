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
    VoiceRecordingArtifact? artifact;

    try {
      try {
        final stopFuture = session._captureSession.stop();
        session._stopFuture = stopFuture;
        try {
          artifact = await stopFuture;
        } finally {
          if (identical(session._stopFuture, stopFuture)) session._stopFuture = null;
        }
      } on VoiceCaptureError catch (error) {
        await session._captureSession.cancel();
        throw VoiceTranscriptionError.recordingFailed(innerError: error);
      }

      if (!_ownsGeneration(session: session, generation: generation)) {
        throw VoiceTranscriptionError.cancelled();
      }
      session._state = _VoiceSessionTranscribing(artifact: artifact);

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
        VoiceTranscriptionServerFailure(:final statusCode) => throw VoiceTranscriptionError.serverError(
          statusCode: statusCode,
        ),
        VoiceTranscriptionNetworkFailure() => throw VoiceTranscriptionError.networkError(),
        VoiceTranscriptionEmptyTranscript() => throw VoiceTranscriptionError.emptyTranscript(),
      };
    } finally {
      final ownsGeneration = _ownsGeneration(session: session, generation: generation);
      if (ownsGeneration) await session._captureSession.releaseOperation();
      if (artifact != null) {
        await session._captureSession.deleteArtifact(artifact: artifact);
      }
      if (ownsGeneration) session._state = const _VoiceSessionIdle();
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
    if (session._state is _VoiceSessionIdle ||
        session._state is _VoiceSessionClosing ||
        session._state is _VoiceSessionDisposed) {
      return;
    }

    final state = session._state;
    final generation = ++session._generation;
    _cancelMaxDurationTimer(session: session);

    switch (state) {
      case _VoiceSessionStarting() || _VoiceSessionRecording():
        await session._captureSession.cancel();
      case _VoiceSessionTranscribing(:final artifact):
        await session._captureSession.releaseOperation();
        await session._captureSession.deleteArtifact(artifact: artifact);
      case _VoiceSessionIdle() || _VoiceSessionClosing() || _VoiceSessionDisposed():
        return;
    }
    if (_ownsGeneration(session: session, generation: generation)) {
      session._state = const _VoiceSessionIdle();
    }
  }

  void invalidate({required VoiceTranscriptionSession session}) {
    final state = session._state;
    if (state is _VoiceSessionClosing || state is _VoiceSessionDisposed) return;

    session._generation++;
    _cancelMaxDurationTimer(session: session);
    session._state = const _VoiceSessionClosing();
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

final class const _VoiceSessionTranscribing({required final VoiceRecordingArtifact artifact})
    extends _VoiceSessionState;

final class const _VoiceSessionClosing() extends _VoiceSessionState;

final class const _VoiceSessionDisposed() extends _VoiceSessionState;

sealed class const VoiceTranscriptionError._(final String message) implements Exception {
  factory microphonePermissionDenied({required Object innerError}) = MicrophonePermissionDeniedError._;

  factory recordingFailed({required Object innerError}) = RecordingFailedError._;

  factory notRecording() = NotRecordingError._;

  factory notAuthenticated() = NotAuthenticatedVoiceError._;

  factory serverError({required int statusCode}) = ServerVoiceError._;

  factory emptyTranscript() = EmptyTranscriptError._;

  factory networkError() = NetworkVoiceError._;

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

final class const ServerVoiceError._({required final int statusCode}) extends VoiceTranscriptionError {
  this : super._("Server error ($statusCode)");
}

final class const EmptyTranscriptError._() extends VoiceTranscriptionError {
  this : super._("Server returned empty transcript");
}

final class const NetworkVoiceError._() extends VoiceTranscriptionError {
  this : super._("Network error");
}

final class const TranscriptionCancelledError._() extends VoiceTranscriptionError {
  this : super._("Transcription cancelled");
}
