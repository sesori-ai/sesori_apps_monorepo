import "dart:async";
import "dart:io";

import "package:injectable/injectable.dart";
import "package:record/record.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "audio_format_config.dart";
import "recorder_prewarm_client.dart";
import "recording_file_provider.dart";
import "wake_lock_service.dart";

/// Maximum recording duration before the service signals auto-stop.
const maxRecordingDuration = Duration(minutes: 15);

/// Amplitude polling interval for the waveform visualizer.
const _amplitudeInterval = Duration(milliseconds: 100);

/// Native warm-up should normally finish in under 200 ms. This bound lets a
/// recording attempt fail promptly without racing native warm-up resources.
const _recorderPrewarmTimeout = Duration(seconds: 2);

/// dBFS floor for normalization — speech rarely drops below -60 dBFS,
/// so using -160 (the technical floor) would make the bars barely move.
const double _amplitudeFloor = -60.0;

@lazySingleton
class VoiceTranscriptionService({
  required final HostedVoiceInputService _hostedVoiceInputService,
  required final AudioRecorder _recorder,
  required final RecorderPrewarmClient _recorderPrewarmClient,
  required final RecordingFileProvider _fileProvider,
  required final WakeLockService _wakeLockService,
  required final AudioFormatConfig _audioFormat,
}) {
  bool _isRecording = false;
  bool _isBusy = false;
  Future<void>? _prewarmFuture;
  int _transcriptionGeneration = 0;
  String? _currentRecordingPath;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _maxDurationTimer;
  final _amplitudeController = StreamController<double>.broadcast();
  final _maxDurationReachedController = StreamController<void>.broadcast();

  bool get isRecording => _isRecording;
  bool get isBusy => _isBusy;
  bool get isTranscribing => _isBusy && !_isRecording;

  /// Normalized amplitude stream (0.0–1.0) emitted during recording.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Emits when the recording reaches [maxRecordingDuration].
  ///
  /// Listeners should call [stopAndTranscribe] to finalize the recording.
  Stream<void> get onMaxDurationReached => _maxDurationReachedController.stream;

  /// Best-effort preparation of native resources used by the first recording.
  ///
  /// Permission is never requested here, and concurrent callers share one
  /// attempt. [startRecording] waits for an attempt already in progress so the
  /// prewarmer and recorder never contend for the same native resources.
  Future<void> prewarmRecording() {
    if (_isBusy) return Future<void>.value();

    final prewarmFuture = _prewarmFuture;
    if (prewarmFuture != null) return prewarmFuture;

    final newPrewarmFuture = _runRecorderPrewarm();
    _prewarmFuture = newPrewarmFuture;
    return newPrewarmFuture;
  }

  Future<void> _runRecorderPrewarm() async {
    try {
      final hasPermission = await _recorder.hasPermission(request: false);
      if (!hasPermission) return;

      await _recorderPrewarmClient.prewarm(
        sampleRate: _audioFormat.sampleRate,
        bitRate: _audioFormat.bitRate,
        numChannels: _audioFormat.numChannels,
      );
    } catch (error, stackTrace) {
      logw("Failed to prewarm audio recorder", error, stackTrace);
    } finally {
      _prewarmFuture = null;
    }
  }

  Future<void> startRecording({required String? projectId}) async {
    if (_isBusy) {
      logw("Operation already in progress, ignoring startRecording call");
      return;
    }

    _isBusy = true;

    try {
      final prewarmFuture = _prewarmFuture;
      if (prewarmFuture != null) {
        // Future.timeout does not cancel native work, so a timeout must fail
        // this attempt while the underlying future remains serialized.
        await prewarmFuture.timeout(_recorderPrewarmTimeout);
      }

      bool hasPermission;
      try {
        hasPermission = await _recorder.hasPermission();
      } catch (error, stackTrace) {
        loge("Failed to check microphone permission", error, stackTrace);
        throw VoiceTranscriptionError.microphonePermissionDenied();
      }
      if (!hasPermission) {
        throw VoiceTranscriptionError.microphonePermissionDenied();
      }

      final path = await _fileProvider.createRecordingPath();
      _currentRecordingPath = path;

      final config = RecordConfig(
        encoder: _audioFormat.encoder,
        bitRate: _audioFormat.bitRate,
        sampleRate: _audioFormat.sampleRate,
        numChannels: _audioFormat.numChannels,
        autoGain: true,
        noiseSuppress: true,
        audioInterruption: AudioInterruptionMode.none,
        // iOS silences every haptic and system sound while an audio session is
        // recording unless the session opts in, which mutes the whole
        // hold-to-speak feedback (cancel-target ticks included) on device.
        iosConfig: const IosRecordConfig(allowHapticsAndSystemSoundsDuringRecording: true),
      );
      logt(
        "[voice] starting recorder — encoder=${config.encoder.name} "
        "sampleRate=${config.sampleRate} channels=${config.numChannels} "
        "path=$path",
      );

      try {
        await _recorder.start(config, path: path);
        _isRecording = true;
        _startAmplitudeMonitoring(_recorder);
        _startMaxDurationTimer();
        _hostedVoiceInputService.recordingStarted(projectId: projectId);
        unawaited(_wakeLockService.enable());
      } catch (error, stackTrace) {
        loge("Failed to start recording", error, stackTrace);
        await _cleanupFile(path);
        _currentRecordingPath = null;
        throw VoiceTranscriptionError.recordingFailed();
      }
    } catch (_) {
      // Release the busy lock on any error — if recording started
      // successfully, _isBusy stays true until stop/cancel.
      if (!_isRecording) _isBusy = false;
      rethrow;
    }
  }

  /// Stops the current recording, uploads the audio to the server,
  /// and returns the transcribed text.
  Future<String> stopAndTranscribe({required String? projectId}) async {
    if (!_isRecording) {
      throw VoiceTranscriptionError.notRecording();
    }

    _cancelMaxDurationTimer();
    final generation = ++_transcriptionGeneration;

    try {
      String? path;
      try {
        path = await _recorder.stop();
      } catch (error, stackTrace) {
        loge("Failed to stop recorder", error, stackTrace);
        throw VoiceTranscriptionError.recordingFailed();
      } finally {
        _stopAmplitudeMonitoring();
        _isRecording = false;
      }

      if (path == null || path.isEmpty) {
        throw VoiceTranscriptionError.recordingFailed();
      }

      // Verify the file has actual content before uploading.
      final fileSize = await File(path).length();
      logt("[voice] recorded file: $fileSize bytes");
      if (fileSize == 0) {
        loge("Recording produced a 0-byte file");
        throw VoiceTranscriptionError.recordingFailed();
      }

      final response = await _hostedVoiceInputService.transcribe(
        audioFilePath: path,
        mimeType: _audioFormat.mimeType,
        projectId: projectId,
      );

      // If cancelled (or a new call started) while awaiting the HTTP call,
      // discard the result.
      if (generation != _transcriptionGeneration) throw VoiceTranscriptionError.cancelled();

      switch (response) {
        case SuccessResponse(:final data):
          return data;
        case ErrorResponse(:final error):
          throw _mapApiError(error);
      }
    } finally {
      _isBusy = false;
      await _wakeLockService.disable();
      await _cleanup();
    }
  }

  /// Cancels any active recording or transcription in progress.
  ///
  /// If a transcription upload is in flight, [_transcriptionGeneration] is
  /// bumped so that [stopAndTranscribe] detects a generation mismatch and
  /// throws [TranscriptionCancelledError] instead of returning a stale
  /// transcript.
  Future<void> cancelRecording() async {
    if (!_isBusy) return;

    _cancelMaxDurationTimer();
    _stopAmplitudeMonitoring();

    // Bump the generation so any in-flight stopAndTranscribe sees a mismatch
    // and discards its result.
    _transcriptionGeneration++;

    if (_isRecording) {
      try {
        await _recorder.stop();
      } catch (error, stackTrace) {
        loge("Failed to stop recorder during cancel", error, stackTrace);
      }
    }

    _isRecording = false;
    _isBusy = false;
    await _wakeLockService.disable();
    await _cleanup();
  }

  /// Maps [ApiError] to the appropriate [VoiceTranscriptionError].
  VoiceTranscriptionError _mapApiError(ApiError error) => switch (error) {
    NotAuthenticatedError() => VoiceTranscriptionError.notAuthenticated(),
    NonSuccessCodeError(:final errorCode) => VoiceTranscriptionError.serverError(errorCode),
    DartHttpClientError() => VoiceTranscriptionError.networkError(),
    JsonParsingError() => VoiceTranscriptionError.emptyTranscript(),
    EmptyResponseError() => VoiceTranscriptionError.emptyTranscript(),
    GenericError() => VoiceTranscriptionError.networkError(),
  };

  void _startMaxDurationTimer() {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(maxRecordingDuration, () {
      if (_isRecording && !_maxDurationReachedController.isClosed) {
        _maxDurationReachedController.add(null);
      }
    });
  }

  void _cancelMaxDurationTimer() {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
  }

  void _startAmplitudeMonitoring(AudioRecorder recorder) {
    _amplitudeSub?.cancel();
    _amplitudeSub = recorder
        .onAmplitudeChanged(_amplitudeInterval)
        .listen(
          (amp) {
            if (!_amplitudeController.isClosed) {
              _amplitudeController.add(_normalizeAmplitude(amp.current));
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            logw("Amplitude stream error", error, stackTrace);
          },
        );
  }

  void _stopAmplitudeMonitoring() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    // Emit zero so the waveform settles to baseline.
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(0.0);
    }
  }

  static double _normalizeAmplitude(double dBFS) {
    if (dBFS <= _amplitudeFloor) return 0.0;
    if (dBFS >= 0.0) return 1.0;
    return (dBFS - _amplitudeFloor) / -_amplitudeFloor;
  }

  Future<void> _cleanup() async {
    final path = _currentRecordingPath;
    _currentRecordingPath = null;
    _hostedVoiceInputService.recordingFinished();

    if (path != null) {
      await _cleanupFile(path);
    }
  }

  Future<void> _cleanupFile(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (error, stackTrace) {
      logw("Failed to clean up recording file", error, stackTrace);
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    _cancelMaxDurationTimer();
    _stopAmplitudeMonitoring();
    await _wakeLockService.disable();
    await _amplitudeController.close();
    await _maxDurationReachedController.close();

    final prewarmFuture = _prewarmFuture;
    if (prewarmFuture != null) {
      try {
        await prewarmFuture.timeout(_recorderPrewarmTimeout);
      } on TimeoutException catch (error, stackTrace) {
        logw("Timed out waiting for recorder prewarm during disposal", error, stackTrace);
      }
    }

    try {
      await _recorder.dispose();
    } catch (error, stackTrace) {
      logw("Failed to dispose AudioRecorder", error, stackTrace);
    }
    await _cleanup();
  }
}

sealed class const VoiceTranscriptionError._(final String message) implements Exception {
  factory microphonePermissionDenied() = MicrophonePermissionDeniedError._;

  factory recordingFailed() = RecordingFailedError._;

  factory notRecording() = NotRecordingError._;

  factory notAuthenticated() = NotAuthenticatedVoiceError._;

  factory serverError(int statusCode) = ServerVoiceError._;

  factory emptyTranscript() = EmptyTranscriptError._;

  factory networkError() = NetworkVoiceError._;

  factory cancelled() = TranscriptionCancelledError._;

  @override
  String toString() => "VoiceTranscriptionError: $message";
}

class const MicrophonePermissionDeniedError._() extends VoiceTranscriptionError {
  this : super._("Microphone permission denied");
}

class const RecordingFailedError._() extends VoiceTranscriptionError {
  this : super._("Recording failed");
}

class const NotRecordingError._() extends VoiceTranscriptionError {
  this : super._("Not currently recording");
}

class const NotAuthenticatedVoiceError._() extends VoiceTranscriptionError {
  this : super._("Not authenticated");
}

class ServerVoiceError._(final int statusCode) extends VoiceTranscriptionError {
  this : super._("Server error ($statusCode)");
}

class const EmptyTranscriptError._() extends VoiceTranscriptionError {
  this : super._("Server returned empty transcript");
}

class const NetworkVoiceError._() extends VoiceTranscriptionError {
  this : super._("Network error");
}

class const TranscriptionCancelledError._() extends VoiceTranscriptionError {
  this : super._("Transcription cancelled");
}
