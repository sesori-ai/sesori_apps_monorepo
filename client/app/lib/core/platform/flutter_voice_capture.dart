import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:record/record.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../capabilities/voice/audio_format_config.dart";
import "../../capabilities/voice/recorder_prewarm_client.dart";
import "../../capabilities/voice/recording_file_provider.dart";
import "../../capabilities/voice/wake_lock_service.dart";

const _amplitudeInterval = Duration(milliseconds: 100);
const double _amplitudeFloor = -60;

@LazySingleton(as: VoiceCapture)
class FlutterVoiceCapture({
  required final RecorderPrewarmClient _recorderPrewarmClient,
  required final RecordingFileProvider _fileProvider,
  required final WakeLockService _wakeLockService,
  required final AudioFormatConfig _audioFormat,
  @ignoreParam @visibleForTesting final AudioRecorder Function() _recorderFactory = AudioRecorder.new,
}) implements VoiceCapture {
  Future<void>? _prewarmFuture;
  int _activeCaptures = 0;

  @override
  Future<void> prewarm() {
    if (_activeCaptures > 0) return Future<void>.value();
    final existing = _prewarmFuture;
    if (existing != null) return existing;

    late final Future<void> trackedFuture;
    trackedFuture = _performPrewarm().whenComplete(() {
      if (identical(_prewarmFuture, trackedFuture)) _prewarmFuture = null;
    });
    _prewarmFuture = trackedFuture;
    return trackedFuture;
  }

  Future<void> _performPrewarm() async {
    final recorder = _recorderFactory();
    try {
      final hasPermission = await recorder.hasPermission(request: false);
      if (!hasPermission) return;

      await _recorderPrewarmClient.prewarm(
        sampleRate: _audioFormat.sampleRate,
        bitRate: _audioFormat.bitRate,
        numChannels: _audioFormat.numChannels,
      );
    } catch (error, stackTrace) {
      logw("Failed to prewarm audio recorder", error, stackTrace);
    } finally {
      try {
        await recorder.dispose();
      } catch (error, stackTrace) {
        logw("Failed to dispose prewarm AudioRecorder", error, stackTrace);
      }
    }
  }

  @override
  VoiceCaptureSession createSession() => _FlutterVoiceCaptureSession(
    recorder: _recorderFactory(),
    fileProvider: _fileProvider,
    wakeLockService: _wakeLockService,
    audioFormat: _audioFormat,
    owner: this,
  );

  Future<_VoiceCaptureActivityLease> _acquireActivity() async {
    final prewarmFuture = _prewarmFuture;
    if (prewarmFuture != null) await prewarmFuture;
    _activeCaptures++;
    return _VoiceCaptureActivityLease._(owner: this);
  }

  void _releaseActivity({required _VoiceCaptureActivityLease lease}) {
    if (lease._released) return;
    lease._released = true;
    _activeCaptures--;
  }
}

final class _VoiceCaptureActivityLease._({
  required final FlutterVoiceCapture _owner,
}) {
  bool _released = false;

  void release() => _owner._releaseActivity(lease: this);
}

final class _FlutterVoiceCaptureSession({
  required final AudioRecorder _recorder,
  required final RecordingFileProvider _fileProvider,
  required final WakeLockService _wakeLockService,
  required final AudioFormatConfig _audioFormat,
  required final FlutterVoiceCapture _owner,
}) implements VoiceCaptureSession {
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  WakeLockLease? _wakeLockLease;
  _VoiceCaptureActivityLease? _activityLease;
  String? _currentPath;
  bool _isRecording = false;
  bool _isClosed = false;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<void> start() async {
    if (_isClosed || _isRecording) throw VoiceCaptureError.failed(innerError: null);

    final activityLease = await _owner._acquireActivity();
    try {
      await _startNative();
      _activityLease = activityLease;
    } on Object {
      activityLease.release();
      rethrow;
    }
  }

  Future<void> _startNative() async {
    bool hasPermission;
    try {
      hasPermission = await _recorder.hasPermission();
    } catch (error, stackTrace) {
      loge("Failed to check microphone permission", error, stackTrace);
      throw VoiceCaptureError.permissionDenied(innerError: error);
    }
    if (!hasPermission) throw VoiceCaptureError.permissionDenied(innerError: null);

    late final String path;
    try {
      path = await _fileProvider.createRecordingPath();
    } catch (error, stackTrace) {
      loge("Failed to create voice recording path", error, stackTrace);
      throw VoiceCaptureError.failed(innerError: error);
    }
    _currentPath = path;

    final config = RecordConfig(
      encoder: _audioFormat.encoder,
      bitRate: _audioFormat.bitRate,
      sampleRate: _audioFormat.sampleRate,
      numChannels: _audioFormat.numChannels,
      autoGain: true,
      noiseSuppress: true,
      audioInterruption: AudioInterruptionMode.none,
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
      _startAmplitudeMonitoring();
      _wakeLockLease = _wakeLockService.acquire();
    } catch (error, stackTrace) {
      loge("Failed to start recording", error, stackTrace);
      if (_isRecording) {
        try {
          await _recorder.stop();
        } catch (rollbackError, rollbackStackTrace) {
          loge("Failed to stop recorder after incomplete startup", rollbackError, rollbackStackTrace);
        }
      }
      _stopAmplitudeMonitoring();
      _isRecording = false;
      await releaseOperation();
      await _deletePath(path: path);
      _currentPath = null;
      throw VoiceCaptureError.failed(innerError: error);
    }
  }

  @override
  Future<VoiceRecordingArtifact> stop() async {
    if (!_isRecording) throw VoiceCaptureError.failed(innerError: null);

    String? path;
    try {
      path = await _recorder.stop();
    } catch (error, stackTrace) {
      loge("Failed to stop recorder", error, stackTrace);
      throw VoiceCaptureError.failed(innerError: error);
    } finally {
      _stopAmplitudeMonitoring();
      _isRecording = false;
    }

    if (path == null || path.isEmpty) throw VoiceCaptureError.failed(innerError: null);
    _currentPath = path;

    try {
      final fileSize = await File(path).length();
      logt("[voice] recorded file: $fileSize bytes");
      if (fileSize == 0) {
        loge("Recording produced a 0-byte file");
        throw VoiceCaptureError.failed(innerError: null);
      }
    } on VoiceCaptureError {
      rethrow;
    } catch (error, stackTrace) {
      loge("Failed to inspect recorded audio", error, stackTrace);
      throw VoiceCaptureError.failed(innerError: error);
    }

    return VoiceRecordingArtifact(path: path, mimeType: _audioFormat.mimeType);
  }

  @override
  Future<void> cancel() async {
    _stopAmplitudeMonitoring();
    if (_isRecording) {
      try {
        await _recorder.stop();
      } catch (error, stackTrace) {
        loge("Failed to stop recorder during cancel", error, stackTrace);
      }
    }
    _isRecording = false;
    await releaseOperation();

    final path = _currentPath;
    _currentPath = null;
    if (path != null) await _deletePath(path: path);
  }

  @override
  Future<void> releaseOperation() async {
    final wakeLockLease = _wakeLockLease;
    _wakeLockLease = null;
    if (wakeLockLease != null) await wakeLockLease.release();

    final activityLease = _activityLease;
    _activityLease = null;
    activityLease?.release();
  }

  @override
  Future<void> deleteArtifact({required VoiceRecordingArtifact artifact}) async {
    if (_currentPath == artifact.path) _currentPath = null;
    await _deletePath(path: artifact.path);
  }

  @override
  Future<void> close() async {
    if (_isClosed) return;

    await cancel();
    await _amplitudeController.close();
    try {
      await _recorder.dispose();
    } catch (error, stackTrace) {
      logw("Failed to dispose AudioRecorder", error, stackTrace);
    }
    _isClosed = true;
  }

  void _startAmplitudeMonitoring() {
    unawaited(_amplitudeSubscription?.cancel());
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(_amplitudeInterval)
        .listen(
          (amplitude) {
            if (!_amplitudeController.isClosed) {
              _amplitudeController.add(_normalizeAmplitude(amplitude.current));
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            logw("Amplitude stream error", error, stackTrace);
          },
        );
  }

  void _stopAmplitudeMonitoring() {
    unawaited(_amplitudeSubscription?.cancel());
    _amplitudeSubscription = null;
    if (!_amplitudeController.isClosed) _amplitudeController.add(0);
  }

  static double _normalizeAmplitude(double dBFS) {
    if (dBFS <= _amplitudeFloor) return 0;
    if (dBFS >= 0) return 1;
    return (dBFS - _amplitudeFloor) / -_amplitudeFloor;
  }

  Future<void> _deletePath({required String path}) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (error, stackTrace) {
      logw("Failed to clean up recording file", error, stackTrace);
    }
  }
}
