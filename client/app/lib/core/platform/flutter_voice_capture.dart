import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:record/record.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../capabilities/voice/audio_format_config.dart";
import "../../capabilities/voice/recorder_prewarm_client.dart";
import "../../capabilities/voice/recording_file_provider.dart";
import "../../capabilities/voice/wake_lock_service.dart";

const _amplitudeInterval = Duration(milliseconds: 100);
const _sharedPrewarmWaitTimeout = Duration(seconds: 2);
const double _amplitudeFloor = -60;

// WORKAROUND: dart_style 3.1.12 crashes on empty enhanced enum constructors in this file.
// ignore: use_primary_constructors
enum _VoiceNativeCaptureMode { idle, async, realtimePaused, realtime }

@LazySingleton(as: VoiceCapture)
class FlutterVoiceCapture({
  required final RecorderPrewarmClient _recorderPrewarmClient,
  required final RecordingFileProvider _fileProvider,
  required final WakeLockService _wakeLockService,
  required final AudioFormatConfig _audioFormat,
  @ignoreParam @visibleForTesting final AudioRecorder Function() _recorderFactory = AudioRecorder.new,
  @ignoreParam @visibleForTesting final Duration _prewarmWaitTimeout = _sharedPrewarmWaitTimeout,
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
    if (prewarmFuture != null) {
      try {
        await prewarmFuture.timeout(_prewarmWaitTimeout);
      } on TimeoutException catch (error, stackTrace) {
        loge("Timed out waiting for shared recorder prewarm", error, stackTrace);
        throw VoiceCaptureError.failed(innerError: error);
      }
    }
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
  StreamSubscription<Uint8List>? _realtimeFrameSubscription;
  StreamController<Uint8List>? _realtimeFrameController;
  StreamController<VoiceRealtimeCaptureFormat>? _realtimeFormatController;
  ({VoiceCaptureError error, StackTrace stackTrace})? _pendingRealtimeFrameFailure;
  WakeLockLease? _wakeLockLease;
  _VoiceCaptureActivityLease? _activityLease;
  RecordConfig? _latestRealtimeConfig;
  String? _currentPath;
  Future<VoiceRealtimeCapture>? _realtimeStartFuture;
  _VoiceNativeCaptureMode _mode = _VoiceNativeCaptureMode.idle;
  bool _realtimeConfigCallbackSet = false;
  bool _realtimeStartCancellationRequested = false;
  bool _realtimeStreamCompletionExpected = false;
  bool _isClosed = false;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<void> start() async {
    if (_isClosed || _mode != _VoiceNativeCaptureMode.idle) throw VoiceCaptureError.failed(innerError: null);

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
    await _requirePermission();

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
      _mode = _VoiceNativeCaptureMode.async;
      _startAmplitudeMonitoring();
      _wakeLockLease = _wakeLockService.acquire();
    } catch (error, stackTrace) {
      loge("Failed to start recording", error, stackTrace);
      if (_mode != _VoiceNativeCaptureMode.idle) {
        try {
          await _recorder.stop();
        } catch (rollbackError, rollbackStackTrace) {
          loge("Failed to stop recorder after incomplete startup", rollbackError, rollbackStackTrace);
        }
      }
      _stopAmplitudeMonitoring();
      _mode = _VoiceNativeCaptureMode.idle;
      await releaseOperation();
      await _deletePath(path: path);
      _currentPath = null;
      throw VoiceCaptureError.failed(innerError: error);
    }
  }

  @override
  Future<VoiceRealtimeCapture> startRealtime() async {
    if (_isClosed || _mode != _VoiceNativeCaptureMode.idle || _realtimeStartFuture != null) {
      throw VoiceCaptureError.failed(innerError: null);
    }

    _realtimeStartCancellationRequested = false;
    late final Future<VoiceRealtimeCapture> trackedFuture;
    trackedFuture = _startRealtime().whenComplete(() {
      if (identical(_realtimeStartFuture, trackedFuture)) {
        _realtimeStartFuture = null;
        _realtimeStartCancellationRequested = false;
      }
    });
    _realtimeStartFuture = trackedFuture;
    return await trackedFuture;
  }

  Future<VoiceRealtimeCapture> _startRealtime() async {
    final activityLease = await _owner._acquireActivity();
    try {
      await _requirePermission();
      final realtimeConfig = _audioFormat.realtimeRecorder;
      _latestRealtimeConfig = realtimeConfig.requestedRecordConfig;
      final frameController = StreamController<Uint8List>.broadcast(
        onListen: _deliverPendingRealtimeFrameFailure,
      );
      final formatController = StreamController<VoiceRealtimeCaptureFormat>.broadcast();
      _realtimeFrameController = frameController;
      _realtimeFormatController = formatController;

      await _recorder.setOnConfigChanged(_handleRealtimeConfigChanged);
      _realtimeConfigCallbackSet = true;
      final nativeFrames = await _recorder.startStream(realtimeConfig.requestedRecordConfig);
      _mode = _VoiceNativeCaptureMode.realtimePaused;
      _throwIfRealtimeStartCancelled();
      _realtimeFrameSubscription = nativeFrames.listen(
        frameController.add,
        onError: (Object error, StackTrace stackTrace) {
          _surfaceRealtimeFrameFailure(
            error: error is VoiceCaptureError ? error : VoiceCaptureError.failed(innerError: error),
            stackTrace: stackTrace,
          );
        },
        onDone: _handleRealtimeFramesDone,
      );
      await _recorder.pause();
      _throwIfRealtimeStartCancelled();
      _activityLease = activityLease;

      return VoiceRealtimeCapture(
        format: _validateRealtimeFormat(),
        frames: frameController.stream,
        formatChanges: formatController.stream,
      );
    } on VoiceCaptureError {
      await _rollbackRealtimeStart();
      activityLease.release();
      rethrow;
    } catch (error, stackTrace) {
      loge("Failed to start realtime voice capture", error, stackTrace);
      await _rollbackRealtimeStart();
      activityLease.release();
      throw VoiceCaptureError.failed(innerError: error);
    }
  }

  @override
  Future<void> resumeRealtime() async {
    if (_mode != _VoiceNativeCaptureMode.realtimePaused) {
      throw VoiceCaptureError.failed(innerError: null);
    }
    try {
      await _recorder.resume();
      if (_mode != _VoiceNativeCaptureMode.realtimePaused) {
        try {
          await _recorder.cancel();
        } catch (error, stackTrace) {
          logw("Failed to cancel stale realtime resume", error, stackTrace);
        }
        throw VoiceCaptureError.failed(innerError: StateError("Realtime capture was cancelled while resuming"));
      }
      _mode = _VoiceNativeCaptureMode.realtime;
      _startAmplitudeMonitoring();
      _wakeLockLease = _wakeLockService.acquire();
    } catch (error, stackTrace) {
      loge("Failed to resume realtime voice capture", error, stackTrace);
      await cancel();
      throw VoiceCaptureError.failed(innerError: error);
    }
  }

  @override
  Future<VoiceRecordingArtifact> stop() async {
    if (_mode != _VoiceNativeCaptureMode.async) throw VoiceCaptureError.failed(innerError: null);

    String? path;
    try {
      path = await _recorder.stop();
    } catch (error, stackTrace) {
      loge("Failed to stop recorder", error, stackTrace);
      throw VoiceCaptureError.failed(innerError: error);
    } finally {
      _stopAmplitudeMonitoring();
      _mode = _VoiceNativeCaptureMode.idle;
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
  Future<void> stopRealtime() async {
    if (_mode != _VoiceNativeCaptureMode.realtime && _mode != _VoiceNativeCaptureMode.realtimePaused) {
      throw VoiceCaptureError.failed(innerError: null);
    }
    _realtimeStreamCompletionExpected = true;
    try {
      await _recorder.stop();
    } catch (error, stackTrace) {
      loge("Failed to stop realtime voice capture", error, stackTrace);
      throw VoiceCaptureError.failed(innerError: error);
    } finally {
      _stopAmplitudeMonitoring();
      _mode = _VoiceNativeCaptureMode.idle;
      await _closeRealtimeStreams();
    }
  }

  @override
  Future<void> cancel() async {
    final realtimeStartFuture = _realtimeStartFuture;
    if (realtimeStartFuture != null) {
      _realtimeStartCancellationRequested = true;
      try {
        await realtimeStartFuture;
      } on VoiceCaptureError {
        // The startup path owns rollback before its future settles.
      }
    }

    _stopAmplitudeMonitoring();
    final mode = _mode;
    _mode = _VoiceNativeCaptureMode.idle;
    if (mode != _VoiceNativeCaptureMode.idle) {
      try {
        if (mode == _VoiceNativeCaptureMode.async) {
          await _recorder.stop();
        } else {
          await _recorder.cancel();
        }
      } catch (error, stackTrace) {
        loge("Failed to stop recorder during cancel", error, stackTrace);
      }
    }
    if (mode == _VoiceNativeCaptureMode.realtime || mode == _VoiceNativeCaptureMode.realtimePaused) {
      await _closeRealtimeStreams();
    }
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
  Future<bool> artifactExists({required VoiceRecordingArtifact artifact}) {
    try {
      return Future.value(File(artifact.path).existsSync());
    } catch (error, stackTrace) {
      logw("Failed to inspect retained voice recording", error, stackTrace);
      return Future.value(false);
    }
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

  Future<void> _requirePermission() async {
    bool hasPermission;
    try {
      hasPermission = await _recorder.hasPermission();
    } catch (error, stackTrace) {
      loge("Failed to check microphone permission", error, stackTrace);
      throw VoiceCaptureError.permissionDenied(innerError: error);
    }
    if (!hasPermission) throw VoiceCaptureError.permissionDenied(innerError: null);
  }

  VoiceRealtimeCaptureFormat _validateRealtimeFormat() {
    try {
      final format = _audioFormat.realtimeRecorder.validateEffectiveRecordConfig(
        latestRecordConfig: _latestRealtimeConfig,
      );
      return VoiceRealtimeCaptureFormat(sampleRate: format.sampleRate);
      // ignore: avoid_catching_errors, record reports effective native format mismatch as UnsupportedError
    } on UnsupportedError catch (error) {
      throw VoiceCaptureError.realtimeUnsupported(innerError: error);
    }
  }

  void _handleRealtimeConfigChanged(RecordConfig config) {
    _latestRealtimeConfig = config;
    final controller = _realtimeFormatController;
    if (controller == null || controller.isClosed) return;
    try {
      controller.add(_validateRealtimeFormat());
    } on VoiceCaptureError catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
  }

  void _handleRealtimeFramesDone() {
    if (_realtimeStreamCompletionExpected ||
        (_mode != _VoiceNativeCaptureMode.realtime && _mode != _VoiceNativeCaptureMode.realtimePaused)) {
      return;
    }
    _surfaceRealtimeFrameFailure(
      error: VoiceCaptureError.failed(
        innerError: StateError("Native realtime audio stream ended unexpectedly"),
      ),
      stackTrace: StackTrace.current,
    );
  }

  void _surfaceRealtimeFrameFailure({
    required VoiceCaptureError error,
    required StackTrace stackTrace,
  }) {
    final controller = _realtimeFrameController;
    if (controller == null || controller.isClosed) return;
    final failure = (error: error, stackTrace: stackTrace);
    if (controller.hasListener) {
      controller.addError(failure.error, failure.stackTrace);
    } else {
      _pendingRealtimeFrameFailure ??= failure;
    }
  }

  void _deliverPendingRealtimeFrameFailure() {
    scheduleMicrotask(() {
      final controller = _realtimeFrameController;
      final failure = _pendingRealtimeFrameFailure;
      if (controller == null || controller.isClosed || !controller.hasListener || failure == null) return;
      _pendingRealtimeFrameFailure = null;
      controller.addError(failure.error, failure.stackTrace);
    });
  }

  void _throwIfRealtimeStartCancelled() {
    if (_realtimeStartCancellationRequested) {
      throw VoiceCaptureError.failed(
        innerError: StateError("Realtime capture was cancelled while starting"),
      );
    }
  }

  Future<void> _rollbackRealtimeStart() async {
    final mode = _mode;
    _mode = _VoiceNativeCaptureMode.idle;
    if (mode == _VoiceNativeCaptureMode.realtime || mode == _VoiceNativeCaptureMode.realtimePaused) {
      try {
        await _recorder.cancel();
      } catch (error, stackTrace) {
        logw("Failed to cancel incomplete realtime voice capture", error, stackTrace);
      }
    }
    await _closeRealtimeStreams();
    await releaseOperation();
  }

  Future<void> _closeRealtimeStreams() async {
    if (_realtimeConfigCallbackSet) {
      try {
        await _recorder.setOnConfigChanged(null);
      } catch (error, stackTrace) {
        logw("Failed to clear realtime recorder config callback", error, stackTrace);
      }
      _realtimeConfigCallbackSet = false;
    }
    await _realtimeFrameSubscription?.cancel();
    _realtimeFrameSubscription = null;
    await _realtimeFrameController?.close();
    _realtimeFrameController = null;
    _pendingRealtimeFrameFailure = null;
    await _realtimeFormatController?.close();
    _realtimeFormatController = null;
    _latestRealtimeConfig = null;
    _realtimeStreamCompletionExpected = false;
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
