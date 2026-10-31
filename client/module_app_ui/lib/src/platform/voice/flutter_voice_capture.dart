import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:record/record.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:universal_platform/universal_platform.dart";

import "audio_format_config.dart";
import "pcm_frame_builder.dart";
import "recording_file_provider.dart";
import "wake_lock_service.dart";

const _amplitudeInterval = Duration(milliseconds: 100);
const _sharedPrewarmWaitTimeout = Duration(seconds: 2);
const double _amplitudeFloor = -60;
const int _pcmChannels = 1;

/// Warms the native audio session ahead of the first recording. Only a shell
/// with a native prewarm channel supplies one.
typedef RecorderPrewarm = Future<void> Function({required int sampleRate, required int bitRate, required int numChannels});

/// Builds the shared `record`-backed [VoiceCapture] for a product shell's DI.
VoiceCapture createFlutterVoiceCapture({
  required TemporaryDirectoryClient temporaryDirectoryClient,
  required RecorderPrewarm? recorderPrewarm,
}) {
  final audioFormat = AudioFormatConfig();
  return FlutterVoiceCapture(
    recorderPrewarm: recorderPrewarm,
    fileProvider: RecordingFileProvider(audioFormat: audioFormat, temporaryDirectoryClient: temporaryDirectoryClient),
    wakeLockService: WakeLockService(),
    audioFormat: audioFormat,
  );
}

/// Whether the tool `record` runs for PCM capture is installed. `record` reports
/// PCM as supported on Linux without looking for `parecord`. No other platform
/// runs a tool to capture.
@visibleForTesting
Future<bool> isPcmCaptureToolAvailable({required bool isLinux, required String parecord}) async {
  if (!isLinux) return true;
  try {
    final result = await Process.run(parecord, const ["--version"]);
    if (result.exitCode == 0) return true;
    logw("$parecord --version exited with ${result.exitCode}, so PCM capture is unavailable");
    return false;
  } on ProcessException catch (error, stackTrace) {
    logw("$parecord can't run, so PCM capture is unavailable", error, stackTrace);
    return false;
  }
}

Future<bool> _isHostPcmCaptureToolAvailable() =>
    isPcmCaptureToolAvailable(isLinux: UniversalPlatform.isLinux, parecord: "parecord");

class FlutterVoiceCapture({
  required final RecorderPrewarm? _recorderPrewarm,
  required final RecordingFileProvider _fileProvider,
  required final WakeLockService _wakeLockService,
  required final AudioFormatConfig _audioFormat,
  @visibleForTesting final AudioRecorder Function() _recorderFactory = AudioRecorder.new,
  @visibleForTesting final Duration _prewarmWaitTimeout = _sharedPrewarmWaitTimeout,
  @visibleForTesting final Future<bool> Function() _pcmCaptureToolCheck = _isHostPcmCaptureToolAvailable,
}) implements VoiceCapture {
  Future<void>? _prewarmFuture;
  int _activeCaptures = 0;

  @override
  Future<void> prewarm() {
    final recorderPrewarm = _recorderPrewarm;
    if (recorderPrewarm == null || _activeCaptures > 0) return Future<void>.value();
    final existing = _prewarmFuture;
    if (existing != null) return existing;

    late final Future<void> trackedFuture;
    trackedFuture = _performPrewarm(recorderPrewarm: recorderPrewarm).whenComplete(() {
      if (identical(_prewarmFuture, trackedFuture)) _prewarmFuture = null;
    });
    _prewarmFuture = trackedFuture;
    return trackedFuture;
  }

  Future<void> _performPrewarm({required RecorderPrewarm recorderPrewarm}) async {
    final recorder = _recorderFactory();
    try {
      final hasPermission = await recorder.hasPermission(request: false);
      if (!hasPermission) return;

      await recorderPrewarm(
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

/// One [VoiceCaptureSession.startPcmStream], from the recorder's chunks to the
/// caller's frames.
final class _PcmCapture() {
  final StreamController<Uint8List> _frames = StreamController<Uint8List>();
  final PcmFrameBuilder _builder = PcmFrameBuilder();
  StreamSubscription<Uint8List>? _chunks;
  bool _endExpected = false;

  Stream<Uint8List> get frames => _frames.stream;

  /// `record` drops chunks while nothing listens, so call this right after
  /// `startStream` returns.
  void listenTo({required Stream<Uint8List> chunks}) {
    _chunks = chunks.listen(
      _onChunk,
      onError: (Object error, StackTrace stackTrace) => _fail(error: error, stackTrace: stackTrace),
      onDone: () {
        if (_endExpected) {
          end();
        } else {
          _fail(error: StateError("The recorder ended the PCM stream on its own"), stackTrace: StackTrace.current);
        }
      },
    );
  }

  /// Audio is sent as 16 kHz mono, so any other format would reach the server
  /// as noise. Android can pick stereo for an input that reports only that.
  void checkFormat({required RecordConfig config}) {
    if (config.sampleRate == voiceCapturePcmSampleRate.hertz && config.numChannels == _pcmChannels) return;
    _fail(
      error: UnsupportedError("The recorder changed PCM to ${config.sampleRate} Hz, ${config.numChannels} channels"),
      stackTrace: StackTrace.current,
    );
  }

  /// The recorder is about to stop, so its stream closing is no longer a failure.
  void expectEnd() => _endExpected = true;

  void end() {
    _endExpected = true;
    unawaited(_chunks?.cancel());
    if (!_frames.isClosed) unawaited(_frames.close());
  }

  void _onChunk(Uint8List chunk) {
    if (_frames.isClosed) return;
    _builder.add(chunk: chunk).forEach(_frames.add);
  }

  void _fail({required Object error, required StackTrace stackTrace}) {
    if (_frames.isClosed) return;
    _frames.addError(VoiceCaptureError.failed(innerError: error), stackTrace);
    end();
  }
}

sealed class const _CaptureMode();

final class const _CaptureIdle() extends _CaptureMode;

final class const _CaptureRecordingFile() extends _CaptureMode;

final class _CaptureStreamingPcm({required final _PcmCapture pcmCapture}) extends _CaptureMode;

final class _FlutterVoiceCaptureSession({
  required final AudioRecorder _recorder,
  required final RecordingFileProvider _fileProvider,
  required final WakeLockService _wakeLockService,
  required final AudioFormatConfig _audioFormat,
  required final FlutterVoiceCapture _owner,
}) implements VoiceCaptureSession {
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  _CaptureMode _captureMode = const _CaptureIdle();
  WakeLockLease? _wakeLockLease;
  _VoiceCaptureActivityLease? _activityLease;
  String? _currentPath;
  bool _isClosed = false;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<void> start() => _startLeased(startNative: _startNative);

  @override
  Future<bool> supportsPcmStream() async {
    try {
      return await _recorder.isEncoderSupported(AudioEncoder.pcm16bits) && await _owner._pcmCaptureToolCheck();
    } catch (error, stackTrace) {
      logw("Failed to check PCM capture support", error, stackTrace);
      return false;
    }
  }

  @override
  Future<Stream<Uint8List>> startPcmStream() => _startLeased(startNative: _startPcmNative);

  Future<T> _startLeased<T>({required Future<T> Function() startNative}) async {
    if (_isClosed || _captureMode is! _CaptureIdle) throw VoiceCaptureError.failed(innerError: null);

    final activityLease = await _owner._acquireActivity();
    try {
      final started = await startNative();
      _activityLease = activityLease;
      return started;
    } on Object {
      activityLease.release();
      rethrow;
    }
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

  RecordConfig _recordConfig({required AudioEncoder encoder, required int sampleRate, required int numChannels}) =>
      RecordConfig(
        encoder: encoder,
        bitRate: _audioFormat.bitRate,
        sampleRate: sampleRate,
        numChannels: numChannels,
        autoGain: true,
        noiseSuppress: true,
        audioInterruption: AudioInterruptionMode.none,
        iosConfig: const IosRecordConfig(allowHapticsAndSystemSoundsDuringRecording: true),
      );

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

    final config = _recordConfig(
      encoder: _audioFormat.encoder,
      sampleRate: _audioFormat.sampleRate,
      numChannels: _audioFormat.numChannels,
    );
    logt(
      "[voice] starting recorder — encoder=${config.encoder.name} "
      "sampleRate=${config.sampleRate} channels=${config.numChannels} "
      "path=$path",
    );

    try {
      await _recorder.start(config, path: path);
      _captureMode = const _CaptureRecordingFile();
      _startAmplitudeMonitoring();
      _wakeLockLease = _wakeLockService.acquire();
    } catch (error, stackTrace) {
      loge("Failed to start recording", error, stackTrace);
      if (_captureMode is _CaptureRecordingFile) {
        try {
          await _recorder.stop();
        } catch (rollbackError, rollbackStackTrace) {
          loge("Failed to stop recorder after incomplete startup", rollbackError, rollbackStackTrace);
        }
      }
      _stopAmplitudeMonitoring();
      _captureMode = const _CaptureIdle();
      await releaseOperation();
      await _deletePath(path: path);
      _currentPath = null;
      throw VoiceCaptureError.failed(innerError: error);
    }
  }

  Future<Stream<Uint8List>> _startPcmNative() async {
    await _requirePermission();

    final config = _recordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: voiceCapturePcmSampleRate.hertz,
      numChannels: _pcmChannels,
    );
    logt("[voice] starting PCM capture — sampleRate=${config.sampleRate} channels=${config.numChannels}");

    final pcmCapture = _PcmCapture();
    try {
      await _recorder.setOnConfigChanged((changed) => pcmCapture.checkFormat(config: changed));
      pcmCapture.listenTo(chunks: await _recorder.startStream(config));
      _captureMode = _CaptureStreamingPcm(pcmCapture: pcmCapture);
      _startAmplitudeMonitoring();
      _wakeLockLease = _wakeLockService.acquire();
      return pcmCapture.frames;
    } catch (error, stackTrace) {
      loge("Failed to start PCM capture", error, stackTrace);
      if (_captureMode is _CaptureStreamingPcm) {
        pcmCapture.expectEnd();
        try {
          await _recorder.stop();
        } catch (rollbackError, rollbackStackTrace) {
          loge("Failed to stop recorder after incomplete PCM startup", rollbackError, rollbackStackTrace);
        }
      }
      _stopAmplitudeMonitoring();
      _captureMode = const _CaptureIdle();
      pcmCapture.end();
      await releaseOperation();
      throw VoiceCaptureError.failed(innerError: error);
    }
  }

  @override
  Future<void> stopPcmStream() async {
    final mode = _captureMode;
    if (mode is! _CaptureStreamingPcm) throw VoiceCaptureError.failed(innerError: null);

    mode.pcmCapture.expectEnd();
    try {
      await _recorder.stop();
    } catch (error, stackTrace) {
      // The microphone may still be on, so the mode stays for cancel to stop it again.
      loge("Failed to stop PCM capture", error, stackTrace);
      throw VoiceCaptureError.failed(innerError: error);
    }
    _stopAmplitudeMonitoring();
    _captureMode = const _CaptureIdle();
    mode.pcmCapture.end();
  }

  @override
  Future<VoiceRecordingArtifact> stop() async {
    if (_captureMode is! _CaptureRecordingFile) throw VoiceCaptureError.failed(innerError: null);

    String? path;
    try {
      path = await _recorder.stop();
    } catch (error, stackTrace) {
      loge("Failed to stop recorder", error, stackTrace);
      throw VoiceCaptureError.failed(innerError: error);
    } finally {
      _stopAmplitudeMonitoring();
      _captureMode = const _CaptureIdle();
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
    final mode = _captureMode;
    if (mode is _CaptureStreamingPcm) mode.pcmCapture.expectEnd();
    if (mode is! _CaptureIdle) {
      try {
        await _recorder.stop();
      } catch (error, stackTrace) {
        loge("Failed to stop recorder during cancel", error, stackTrace);
      }
    }
    _captureMode = const _CaptureIdle();
    if (mode is _CaptureStreamingPcm) mode.pcmCapture.end();
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
