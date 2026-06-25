import "dart:async";
import "dart:io";

import "package:injectable/injectable.dart";
import "package:record/record.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "audio_format_config.dart";
import "recording_file_provider.dart";
import "wake_lock_service.dart";

/// Maximum recording duration before the service signals auto-stop.
const maxRecordingDuration = Duration(minutes: 15);

/// Amplitude polling interval for the waveform visualizer.
const _amplitudeInterval = Duration(milliseconds: 100);

/// dBFS floor for normalization — speech rarely drops below -60 dBFS,
/// so using -160 (the technical floor) would make the bars barely move.
const double _amplitudeFloor = -60.0;

@lazySingleton
class VoiceTranscriptionService {
  final VoiceApi _voiceApi;
  final AudioRecorder _recorder;
  final RecordingFileProvider _fileProvider;
  final WakeLockService _wakeLockService;
  final AudioFormatConfig _audioFormat;
  bool _isRecording = false;
  bool _isBusy = false;
  int _transcriptionGeneration = 0;
  String? _currentRecordingPath;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _maxDurationTimer;
  final _amplitudeController = StreamController<double>.broadcast();
  final _maxDurationReachedController = StreamController<void>.broadcast();

  VoiceTranscriptionService(
    VoiceApi voiceApi,
    AudioRecorder recorder,
    RecordingFileProvider fileProvider,
    WakeLockService wakeLockService,
    AudioFormatConfig audioFormat,
  ) : _voiceApi = voiceApi,
      _recorder = recorder,
      _fileProvider = fileProvider,
      _wakeLockService = wakeLockService,
      _audioFormat = audioFormat;

  bool get isRecording => _isRecording;
  bool get isBusy => _isBusy;
  bool get isTranscribing => _isBusy && !_isRecording;

  /// Normalized amplitude stream (0.0–1.0) emitted during recording.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Emits when the recording reaches [maxRecordingDuration].
  ///
  /// Listeners should call [stopAndTranscribe] to finalize the recording.
  Stream<void> get onMaxDurationReached => _maxDurationReachedController.stream;

  Future<void> startRecording() async {
    if (_isBusy) {
      logw("Operation already in progress, ignoring startRecording call");
      return;
    }

    _isBusy = true;

    try {
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
        sampleRate: _audioFormat.sampleRate,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: true,
        audioInterruption: AudioInterruptionMode.none,
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
  Future<String> stopAndTranscribe() async {
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

      final response = await _voiceApi.transcribe(path, mimeType: _audioFormat.mimeType);

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

    try {
      await _recorder.dispose();
    } catch (error, stackTrace) {
      logw("Failed to dispose AudioRecorder", error, stackTrace);
    }
    await _cleanup();
  }
}

sealed class VoiceTranscriptionError implements Exception {
  final String message;

  const VoiceTranscriptionError._(this.message);

  factory VoiceTranscriptionError.microphonePermissionDenied() = MicrophonePermissionDeniedError._;

  factory VoiceTranscriptionError.recordingFailed() = RecordingFailedError._;

  factory VoiceTranscriptionError.notRecording() = NotRecordingError._;

  factory VoiceTranscriptionError.notAuthenticated() = NotAuthenticatedVoiceError._;

  factory VoiceTranscriptionError.serverError(int statusCode) = ServerVoiceError._;

  factory VoiceTranscriptionError.emptyTranscript() = EmptyTranscriptError._;

  factory VoiceTranscriptionError.networkError() = NetworkVoiceError._;

  factory VoiceTranscriptionError.cancelled() = TranscriptionCancelledError._;

  @override
  String toString() => "VoiceTranscriptionError: $message";
}

class MicrophonePermissionDeniedError extends VoiceTranscriptionError {
  const MicrophonePermissionDeniedError._() : super._("Microphone permission denied");
}

class RecordingFailedError extends VoiceTranscriptionError {
  const RecordingFailedError._() : super._("Recording failed");
}

class NotRecordingError extends VoiceTranscriptionError {
  const NotRecordingError._() : super._("Not currently recording");
}

class NotAuthenticatedVoiceError extends VoiceTranscriptionError {
  const NotAuthenticatedVoiceError._() : super._("Not authenticated");
}

class ServerVoiceError extends VoiceTranscriptionError {
  final int statusCode;

  ServerVoiceError._(this.statusCode) : super._("Server error ($statusCode)");
}

class EmptyTranscriptError extends VoiceTranscriptionError {
  const EmptyTranscriptError._() : super._("Server returned empty transcript");
}

class NetworkVoiceError extends VoiceTranscriptionError {
  const NetworkVoiceError._() : super._("Network error");
}

class TranscriptionCancelledError extends VoiceTranscriptionError {
  const TranscriptionCancelledError._() : super._("Transcription cancelled");
}
