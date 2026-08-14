import "dart:async";
import "dart:io";
import "dart:typed_data";

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

const _realtimeReadyTimeout = Duration(seconds: 10);
const _realtimeFinishTimeout = Duration(seconds: 10);
const _activeSetupDisposeTimeout = Duration(seconds: 2);

/// dBFS floor for normalization — speech rarely drops below -60 dBFS,
/// so using -160 (the technical floor) would make the bars barely move.
const double _amplitudeFloor = -60.0;

@lazySingleton
class VoiceTranscriptionService({
  required VoiceApi voiceApi,
  required RealtimeVoiceApi realtimeVoiceApi,
  required AudioRecorder recorder,
  required RecorderPrewarmClient recorderPrewarmClient,
  required RecordingFileProvider fileProvider,
  required WakeLockService wakeLockService,
  required AudioFormatConfig audioFormat,
}) {
  final VoiceApi _voiceApi = voiceApi;
  final RealtimeVoiceApi _realtimeVoiceApi = realtimeVoiceApi;
  final AudioRecorder _recorder = recorder;
  final RecorderPrewarmClient _recorderPrewarmClient = recorderPrewarmClient;
  final RecordingFileProvider _fileProvider = fileProvider;
  final WakeLockService _wakeLockService = wakeLockService;
  final AudioFormatConfig _audioFormat = audioFormat;

  bool _isRecording = false;
  bool _isBusy = false;
  Future<void>? _prewarmFuture;
  int _transcriptionGeneration = 0;
  String? _currentRecordingPath;
  VoiceCapabilities? _observedCapabilities;
  String? _currentProjectKey;
  _VoiceRecordingMode _mode = const _AsyncVoiceRecordingMode(projectKey: null);

  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _maxDurationTimer;
  final _amplitudeController = StreamController<double>.broadcast();
  final _maxDurationReachedController = StreamController<void>.broadcast();
  final _previewController = StreamController<VoiceTranscriptionPreview>.broadcast();

  StreamSubscription<Uint8List>? _recorderStreamSub;
  StreamSubscription<RealtimeVoiceEvent>? _realtimeEventSub;
  RealtimeVoiceSession? _realtimeSession;
  Completer<void>? _realtimeReadyCompleter;
  Completer<VoiceTranscriptionError>? _realtimeFailureCompleter;
  RecordConfig? _latestRealtimeRecordConfig;
  RealtimeRecorderFormat? _announcedRealtimeFormat;
  bool _realtimeConfigCallbackSet = false;
  bool _realtimeNativeRecording = false;
  bool _realtimeRecorderStoppedByTerminal = false;
  bool _forwardRealtimeAudio = false;
  bool _sentRealtimeAudio = false;
  bool _realtimeSetupInProgress = false;
  bool _disposed = false;
  int? _activeInteractionGeneration;
  Future<void>? _activeStartFuture;
  Completer<void>? _disposeCompleter;
  Completer<_RealtimePreAudioFallback>? _preAudioFallbackCompleter;
  _RealtimePreAudioFallback? _pendingPreAudioFallback;
  Future<void>? _realtimePreAudioFallbackTransition;
  Future<void>? _terminalCaptureStopFuture;
  RealtimeVoiceEvent? _realtimeTerminalEvent;
  VoiceTranscriptionError? _realtimeTerminalFailure;
  String _confirmedRealtimeTranscript = "";
  String _provisionalRealtimeTranscript = "";

  bool get isRecording => _isRecording;
  bool get isBusy => _isBusy;
  bool get isTranscribing => _isBusy && !_isRecording;

  /// Normalized amplitude stream (0.0–1.0) emitted during recording.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Emits when the recording reaches [maxRecordingDuration].
  ///
  /// Listeners should call [stopAndTranscribe] to finalize the recording.
  Stream<void> get onMaxDurationReached => _maxDurationReachedController.stream;

  VoiceTranscriptionPreview get currentPreview => VoiceTranscriptionPreview(
    confirmedText: _confirmedRealtimeTranscript,
    provisionalText: _provisionalRealtimeTranscript,
  );

  Stream<VoiceTranscriptionPreview> get previewStream => _previewController.stream;

  /// Best-effort preparation of native resources used by the first recording.
  ///
  /// Permission is never requested here, and concurrent callers share one
  /// attempt. [startRecording] waits for an attempt already in progress so the
  /// prewarmer and recorder never contend for the same native resources.
  Future<void> prewarmRecording() {
    if (_disposed || _isBusy) return Future<void>.value();

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

  Future<void> startRecording({required String projectId}) {
    if (_disposed) {
      return Future<void>.error(VoiceTranscriptionError.cancelled());
    }
    if (_isBusy) {
      logw("Operation already in progress, ignoring startRecording call");
      return Future<void>.value();
    }

    final startFuture = _startRecording(projectId: projectId);
    _activeStartFuture = startFuture;
    return startFuture.whenComplete(() {
      if (identical(_activeStartFuture, startFuture)) {
        _activeStartFuture = null;
      }
    });
  }

  Future<void> _startRecording({required String projectId}) async {
    _isBusy = true;
    final generation = ++_transcriptionGeneration;
    _activeInteractionGeneration = generation;
    _disposeCompleter = Completer<void>();
    _resetRealtimeState(emitPreview: true);

    try {
      final prewarmFuture = _prewarmFuture;
      if (prewarmFuture != null) {
        await prewarmFuture.timeout(_recorderPrewarmTimeout);
      }
      _ensureInteractionActive(generation);

      final hasPermission = await _awaitActiveSetup(_checkMicrophonePermission(), generation: generation);
      _ensureInteractionActive(generation);
      if (!hasPermission) {
        throw VoiceTranscriptionError.microphonePermissionDenied();
      }

      final capabilities = await _awaitActiveSetup(_voiceApi.discoverCapabilities(), generation: generation);
      _mode = _selectMode(capabilities, projectId: projectId);
      _ensureInteractionActive(generation);
      switch (_mode) {
        case _AsyncVoiceRecordingMode():
          await _startAsyncRecording(generation: generation);
        case _RealtimeVoiceRecordingMode(:final projectKey):
          try {
            await _startRealtimeRecording(projectKey: projectKey, generation: generation);
          } on _RealtimePreAudioFallback {
            _ensureInteractionActive(generation);
            if (_sentRealtimeAudio) rethrow;
            await _stopRealtimeResources(sendCancel: true);
            await _stopRealtimeNativeRecorder();
            _ensureInteractionActive(generation);
            _mode = _AsyncVoiceRecordingMode(projectKey: projectKey);
            await _startAsyncRecording(generation: generation);
          }
      }
    } on TranscriptionCancelledError {
      if (_mode is _RealtimeVoiceRecordingMode) {
        await _stopRealtimeResources(sendCancel: true);
        await _stopRealtimeNativeRecorder();
      }
      _isBusy = false;
      _isRecording = false;
      rethrow;
    } catch (_) {
      if (_mode is _RealtimeVoiceRecordingMode) {
        await _stopRealtimeResources(sendCancel: true);
        await _stopRealtimeNativeRecorder();
      }
      if (!_isRecording) _isBusy = false;
      rethrow;
    }
  }

  void _ensureInteractionActive(int generation) {
    if (_disposed || !_isBusy || generation != _transcriptionGeneration) {
      throw VoiceTranscriptionError.cancelled();
    }
  }

  Future<T> _awaitActiveSetup<T>(Future<T> future, {required int generation}) async {
    final disposeFuture = _disposeCompleter?.future.then<T>((_) => throw VoiceTranscriptionError.cancelled());
    if (disposeFuture == null) {
      final result = await future;
      _ensureInteractionActive(generation);
      return result;
    }
    final result = await Future.any<T>([future, disposeFuture]);
    _ensureInteractionActive(generation);
    return result;
  }

  Future<T> _awaitRealtimeSetup<T>(Future<T> future, {required int generation}) async {
    final fallbackFuture = _preAudioFallbackCompleter?.future.then<T>((fallback) => throw fallback);
    if (fallbackFuture == null) {
      return await _awaitActiveSetup(future, generation: generation);
    }
    return await _awaitActiveSetup(Future.any<T>([future, fallbackFuture]), generation: generation);
  }

  Future<bool> _checkMicrophonePermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (error, stackTrace) {
      loge("Failed to check microphone permission", error, stackTrace);
      throw VoiceTranscriptionError.microphonePermissionDenied();
    }
  }

  _VoiceRecordingMode _selectMode(VoiceCapabilitiesDiscoveryResult result, {required String projectId}) {
    switch (result) {
      case VoiceCapabilitiesAsyncFallback():
        _observedCapabilities = null;
        _currentProjectKey = null;
        return const _AsyncVoiceRecordingMode(projectKey: null);
      case VoiceCapabilitiesContractFailure(:final reason):
        throw VoiceTranscriptionError.contractFailure(
          reason: reason,
          cause: _VoiceCapabilitiesContractException(reason),
        );
      case VoiceCapabilitiesAvailable(:final capabilities):
        _observedCapabilities = capabilities;
        final projectKey = deriveProjectGlossaryKey(projectId);
        _currentProjectKey = projectKey;
        if (capabilities.canUseRealtimeProtocol1) {
          return _RealtimeVoiceRecordingMode(projectKey: projectKey);
        }
        return _AsyncVoiceRecordingMode(projectKey: projectKey);
    }
  }

  Future<void> _startAsyncRecording({required int generation}) async {
    final path = await _fileProvider.createRecordingPath();
    _ensureInteractionActive(generation);
    _currentRecordingPath = path;
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
    } catch (error, stackTrace) {
      loge("Failed to start recording", error, stackTrace);
      await _cleanupFile(path);
      _currentRecordingPath = null;
      throw VoiceTranscriptionError.recordingFailed();
    }

    if (!_isInteractionActive(generation)) {
      await _cancelAsyncRecorderAfterStart(path);
      throw VoiceTranscriptionError.cancelled();
    }
    _markRecordingStarted();
  }

  Future<void> _cancelAsyncRecorderAfterStart(String path) async {
    try {
      await _recorder.cancel();
    } catch (error, stackTrace) {
      logw("Failed to cancel recorder after interaction cancellation", error, stackTrace);
    } finally {
      await _cleanupFile(path);
      _currentRecordingPath = null;
      _isRecording = false;
    }
  }

  Future<void> _startRealtimeRecording({required String projectKey, required int generation}) async {
    try {
      await _runStartRealtimeRecording(projectKey: projectKey, generation: generation);
    } finally {
      _realtimeSetupInProgress = false;
    }
  }

  Future<void> _runStartRealtimeRecording({required String projectKey, required int generation}) async {
    _resetRealtimeState(emitPreview: true);
    _realtimeSetupInProgress = true;
    _latestRealtimeRecordConfig = _audioFormat.realtimeRecorder.requestedRecordConfig;
    await _recorder.setOnConfigChanged(_handleRealtimeConfigChanged);
    _realtimeConfigCallbackSet = true;
    _ensureInteractionActive(generation);

    final stream = await _recorder.startStream(_audioFormat.realtimeRecorder.requestedRecordConfig);
    _realtimeNativeRecording = true;
    if (!_isInteractionActive(generation)) {
      await _stopRealtimeNativeRecorder();
      throw VoiceTranscriptionError.cancelled();
    }
    _recorderStreamSub = stream.listen(
      _handleRealtimeAudioFrame,
      // ignore: prefer_specific_type -- Stream.listen error handlers require Object.
      onError: (Object error, StackTrace stackTrace) {
        _handleRealtimeNativeStreamError(_asException(error));
      },
    );
    await _recorder.pause();
    _ensureInteractionActive(generation);
    _throwIfPendingPreAudioFallback();

    final RealtimeRecorderFormat effectiveFormat;
    try {
      effectiveFormat = _validateRealtimeFormat();
    } on _RealtimeFormatException catch (error) {
      throw _RealtimePreAudioFallback(error);
    }
    _announcedRealtimeFormat = effectiveFormat;

    final session = await _openRealtimeSession(effectiveFormat: effectiveFormat, projectKey: projectKey);
    if (!_isInteractionActive(generation)) {
      await _cancelLateRealtimeSession(session);
      throw VoiceTranscriptionError.cancelled();
    }
    try {
      _throwIfPendingPreAudioFallback();
    } on _RealtimePreAudioFallback {
      await _cancelLateRealtimeSession(session);
      rethrow;
    }
    _realtimeSession = session;
    _listenToRealtimeEvents(session);

    try {
      final ready = _realtimeReadyCompleter;
      if (ready == null) {
        throw const _RealtimePreAudioFallback(_RealtimeSetupException("Realtime setup ended before ready wait"));
      }
      await _awaitRealtimeSetup(ready.future.timeout(_realtimeReadyTimeout), generation: generation);
      _ensureInteractionActive(generation);
    } on TimeoutException catch (error) {
      throw _RealtimePreAudioFallback(error);
    } on RealtimeVoiceTransportClosedException catch (error) {
      throw _RealtimePreAudioFallback(error);
    } on VoiceTranscriptionError {
      rethrow;
    } on RealtimeVoiceProtocolException catch (error) {
      throw VoiceTranscriptionError.contractFailure(reason: error.message, cause: error);
    } on FormatException catch (error) {
      throw VoiceTranscriptionError.contractFailure(reason: error.message, cause: error);
    }

    try {
      _validateRealtimeFormat(expected: effectiveFormat);
    } on _RealtimeFormatException catch (error) {
      throw _RealtimePreAudioFallback(error);
    }
    await _recorder.resume();
    _ensureInteractionActive(generation);
    _throwIfPendingPreAudioFallback();
    _forwardRealtimeAudio = true;
    _ensureInteractionActive(generation);
    _markRecordingStarted();
  }

  Future<RealtimeVoiceSession> _openRealtimeSession({
    required RealtimeRecorderFormat effectiveFormat,
    required String projectKey,
  }) async {
    try {
      return await _realtimeVoiceApi.start(
        audio: RealtimeAudioFormat(sampleRate: effectiveFormat.sampleRate),
        projectKey: projectKey,
      );
    } on RealtimeVoiceOpenAuthenticationException catch (error) {
      throw VoiceTranscriptionError.notAuthenticated(cause: error);
    } on RealtimeVoiceOpenHandshakeNotFoundException catch (error) {
      throw _RealtimePreAudioFallback(error);
    } on RealtimeVoiceOpenHandshakeRateLimitedException catch (error) {
      throw _RealtimePreAudioFallback(error);
    } on RealtimeVoiceOpenTimeoutException catch (error) {
      throw _RealtimePreAudioFallback(error);
    } on RealtimeVoiceOpenTransportException catch (error) {
      throw _RealtimePreAudioFallback(error);
    }
  }

  void _listenToRealtimeEvents(RealtimeVoiceSession session) {
    _realtimeReadyCompleter = Completer<void>();
    _realtimeFailureCompleter = Completer<VoiceTranscriptionError>();
    _realtimeEventSub = session.events.listen(
      _handleRealtimeEvent,
      // ignore: prefer_specific_type -- Stream.listen error handlers require Object.
      onError: (Object error, StackTrace stackTrace) {
        final exception = _asException(error);
        if (_canFallbackBeforeAudio && _isRealtimeTransportFallback(exception)) {
          unawaited(_consumeCompletedSessionTerminal(session));
          _completePreAudioFallback(exception);
          return;
        }
        _completeRealtimeFailure(_mapRealtimeStreamError(exception));
        unawaited(_stopCaptureAfterRealtimeTerminal());
        final ready = _realtimeReadyCompleter;
        if (ready != null && !ready.isCompleted) ready.completeError(exception, stackTrace);
      },
      onDone: () {
        if (_realtimeTerminalEvent != null || _realtimeTerminalFailure != null) return;
        if (_pendingPreAudioFallback != null) return;
        if (_canFallbackBeforeAudio) {
          _completePreAudioFallback(const RealtimeVoiceTransportClosedException());
          return;
        }
        final error = VoiceTranscriptionError.realtimeTransport(cause: null, retryable: true);
        _completeRealtimeFailure(error);
        unawaited(_stopCaptureAfterRealtimeTerminal());
        final ready = _realtimeReadyCompleter;
        if (ready != null && !ready.isCompleted) {
          ready.completeError(const RealtimeVoiceTransportClosedException(), StackTrace.current);
        }
      },
    );
  }

  void _markRecordingStarted() {
    _isRecording = true;
    _startAmplitudeMonitoring(_recorder);
    _startMaxDurationTimer();
    unawaited(_wakeLockService.enable());
  }

  RealtimeRecorderFormat _validateRealtimeFormat({RealtimeRecorderFormat? expected}) {
    final RealtimeRecorderFormat effective;
    try {
      effective = _audioFormat.realtimeRecorder.validateEffectiveRecordConfig(
        latestRecordConfig: _latestRealtimeRecordConfig,
      );
      // ignore: avoid_catching_errors -- record format drift is surfaced by the provider as UnsupportedError.
    } on UnsupportedError catch (error) {
      throw _RealtimeFormatException(message: error.message ?? error.toString(), cause: error);
    }
    if (expected != null && effective != expected) {
      throw const _RealtimeFormatException(message: "Realtime recorder format changed after ready", cause: null);
    }
    return effective;
  }

  void _handleRealtimeConfigChanged(RecordConfig config) {
    _latestRealtimeRecordConfig = config;
    final expected = _announcedRealtimeFormat;
    try {
      _validateRealtimeFormat(expected: expected);
    } on _RealtimeFormatException catch (error) {
      if (_sentRealtimeAudio) {
        _forwardRealtimeAudio = false;
        _completeRealtimeFailure(
          VoiceTranscriptionError.realtimeContract(reason: error.message, cause: error),
        );
        unawaited(_stopCaptureAfterRealtimeTerminal());
      } else if (expected != null) {
        _forwardRealtimeAudio = false;
        if (_realtimeSetupInProgress) {
          _completePreAudioFallback(error);
        } else {
          final ready = _realtimeReadyCompleter;
          if (ready != null && !ready.isCompleted) {
            ready.completeError(_RealtimePreAudioFallback(error));
          } else {
            _startRealtimePreAudioFallbackTransition(error);
          }
        }
      } else {
        final ready = _realtimeReadyCompleter;
        if (ready != null && !ready.isCompleted) ready.completeError(_RealtimePreAudioFallback(error));
      }
    }
  }

  bool get _canFallbackBeforeAudio {
    final ready = _realtimeReadyCompleter;
    return !_sentRealtimeAudio && (ready == null || !ready.isCompleted);
  }

  bool _isRealtimeTransportFallback(Exception error) => switch (error) {
    RealtimeVoiceProtocolException() => false,
    FormatException() => false,
    VoiceTranscriptionError() => false,
    _ => true,
  };

  void _handleRealtimeNativeStreamError(Exception error) {
    if (!_sentRealtimeAudio) {
      _completePreAudioFallback(error);
      return;
    }
    _completeRealtimeFailure(VoiceTranscriptionError.realtimeTransport(cause: error, retryable: true));
    unawaited(_stopCaptureAfterRealtimeTerminal());
  }

  void _completePreAudioFallback(Exception cause) {
    final fallback = _RealtimePreAudioFallback(cause);
    _pendingPreAudioFallback ??= fallback;
    final fallbackCompleter = _preAudioFallbackCompleter;
    if (fallbackCompleter != null && !fallbackCompleter.isCompleted) {
      fallbackCompleter.complete(fallback);
    }
    final ready = _realtimeReadyCompleter;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(fallback);
    }
  }

  void _startRealtimePreAudioFallbackTransition(_RealtimeFormatException error) {
    final generation = _activeInteractionGeneration;
    final mode = _mode;
    if (generation == null || mode is! _RealtimeVoiceRecordingMode) {
      return;
    }
    _realtimePreAudioFallbackTransition ??= _transitionRealtimePreAudioFallback(
      generation: generation,
      projectKey: mode.projectKey,
      cause: error,
    );
  }

  void _throwIfPendingPreAudioFallback() {
    final pending = _pendingPreAudioFallback;
    if (pending != null) throw pending;
  }

  Future<void> _cancelLateRealtimeSession(RealtimeVoiceSession session) async {
    try {
      await session.cancel();
    } on RealtimeVoiceTransportClosedException {
      return;
    }
  }

  Future<void> _transitionRealtimePreAudioFallback({
    required int generation,
    required String projectKey,
    required _RealtimeFormatException cause,
  }) async {
    try {
      _ensureInteractionActive(generation);
      await _stopRealtimeResources(sendCancel: true);
      await _stopRealtimeNativeRecorder();
      _ensureInteractionActive(generation);
      if (_sentRealtimeAudio) {
        throw VoiceTranscriptionError.realtimeContract(reason: cause.message, cause: cause);
      }
      _mode = _AsyncVoiceRecordingMode(projectKey: projectKey);
      await _startAsyncRecording(generation: generation);
    } on TranscriptionCancelledError {
      return;
    } on VoiceTranscriptionError catch (error) {
      _completeRealtimeFailure(error);
    } finally {
      _realtimePreAudioFallbackTransition = null;
    }
  }

  void _invalidateActiveInteraction() {
    _transcriptionGeneration++;
    _activeInteractionGeneration = null;
    _isBusy = false;
    _isRecording = false;
    final disposeCompleter = _disposeCompleter;
    if (disposeCompleter != null && !disposeCompleter.isCompleted) {
      disposeCompleter.complete();
    }
    final ready = _realtimeReadyCompleter;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(VoiceTranscriptionError.cancelled());
    }
    final fallback = _preAudioFallbackCompleter;
    if (fallback != null && !fallback.isCompleted) {
      fallback.complete(_RealtimePreAudioFallback(VoiceTranscriptionError.cancelled()));
    }
  }

  bool _isInteractionActive(int generation) => !_disposed && _isBusy && generation == _transcriptionGeneration;

  void _handleRealtimeAudioFrame(Uint8List frame) {
    if (!_forwardRealtimeAudio) return;
    try {
      _realtimeSession?.sendAudio(frame);
      _sentRealtimeAudio = true;
    } on RealtimeVoiceProtocolException catch (error) {
      _completeRealtimeFailure(VoiceTranscriptionError.realtimeContract(reason: error.message, cause: error));
      unawaited(_stopCaptureAfterRealtimeTerminal());
    } on Exception catch (error) {
      _completeRealtimeFailure(VoiceTranscriptionError.realtimeTransport(cause: error, retryable: true));
      unawaited(_stopCaptureAfterRealtimeTerminal());
    }
  }

  void _handleRealtimeEvent(RealtimeVoiceEvent event) {
    switch (event) {
      case RealtimeVoiceReadyEvent():
        final ready = _realtimeReadyCompleter;
        if (ready != null && !ready.isCompleted) ready.complete();
      case RealtimeVoiceTranscriptEvent(:final confirmedDelta, :final provisional):
        _confirmedRealtimeTranscript += confirmedDelta;
        _provisionalRealtimeTranscript = provisional;
        _emitPreview();
      case RealtimeVoiceCompleteEvent():
        _realtimeTerminalEvent = event;
        unawaited(_stopCaptureAfterRealtimeTerminal());
      case RealtimeVoiceErrorEvent(:final code):
        final error = VoiceTranscriptionError.realtimeServer(code: code);
        final ready = _realtimeReadyCompleter;
        if (ready != null && !ready.isCompleted) {
          ready.completeError(error);
        }
        _completeRealtimeFailure(error);
        unawaited(_stopCaptureAfterRealtimeTerminal());
    }
  }

  /// Stops the current recording, uploads the audio to the server,
  /// and returns the transcribed text.
  Future<String> stopAndTranscribe() async {
    if (!_isRecording && _realtimeTerminalEvent == null && _realtimeTerminalFailure == null) {
      throw VoiceTranscriptionError.notRecording();
    }

    _cancelMaxDurationTimer();
    final generation = ++_transcriptionGeneration;

    try {
      switch (_mode) {
        case _RealtimeVoiceRecordingMode():
          return await _stopRealtimeAndTranscribe();
        case _AsyncVoiceRecordingMode():
          return await _stopAsyncAndTranscribe(generation: generation);
      }
    } finally {
      _isBusy = false;
      await _wakeLockService.disable();
      await _stopRealtimeResources(sendCancel: false);
      await _cleanup();
      _resetRealtimeState(emitPreview: true);
      _mode = const _AsyncVoiceRecordingMode(projectKey: null);
      _activeInteractionGeneration = null;
    }
  }

  Future<String> _stopAsyncAndTranscribe({required int generation}) async {
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

    final fileSize = await File(path).length();
    logt("[voice] recorded file: $fileSize bytes");
    if (fileSize == 0) {
      loge("Recording produced a 0-byte file");
      throw VoiceTranscriptionError.recordingFailed();
    }

    final response = await _voiceApi.transcribe(
      path,
      mimeType: _audioFormat.mimeType,
      projectKey: _currentProjectKey,
      capabilities: _observedCapabilities,
    );

    if (generation != _transcriptionGeneration) throw VoiceTranscriptionError.cancelled();

    switch (response) {
      case SuccessResponse(:final data):
        return data;
      case ErrorResponse(:final error):
        throw _mapApiError(error);
    }
  }

  Future<String> _stopRealtimeAndTranscribe() async {
    _forwardRealtimeAudio = false;
    final terminalFailure = _realtimeTerminalFailure;
    if (terminalFailure != null) {
      await _stopCaptureAfterRealtimeTerminal();
      throw VoiceRealtimePartialTranscriptionError(
        confirmedText: _confirmedRealtimeTranscript,
        failure: terminalFailure,
      );
    }
    final terminalEvent = _realtimeTerminalEvent;
    if (terminalEvent != null) {
      await _stopCaptureAfterRealtimeTerminal();
      return _confirmedRealtimeTranscript;
    }
    if (!_realtimeRecorderStoppedByTerminal) {
      try {
        await _recorder.stop();
      } catch (error, stackTrace) {
        loge("Failed to stop realtime recorder", error, stackTrace);
        throw VoiceTranscriptionError.recordingFailed();
      } finally {
        _realtimeNativeRecording = false;
        _stopAmplitudeMonitoring();
        _isRecording = false;
        await _recorderStreamSub?.cancel();
        _recorderStreamSub = null;
      }
    }

    final session = _realtimeSession;
    if (session == null) {
      throw VoiceRealtimePartialTranscriptionError(
        confirmedText: _confirmedRealtimeTranscript,
        failure: VoiceTranscriptionError.realtimeTransport(cause: null, retryable: true),
      );
    }

    try {
      final terminal = await _raceFinishWithFailure(session);
      if (terminal case RealtimeVoiceErrorEvent(:final code)) {
        throw VoiceRealtimePartialTranscriptionError(
          confirmedText: _confirmedRealtimeTranscript,
          failure: VoiceTranscriptionError.realtimeServer(code: code),
        );
      }
      return _confirmedRealtimeTranscript;
    } on VoiceTranscriptionError catch (error) {
      if (error is VoiceRealtimePartialTranscriptionError) {
        rethrow;
      }
      throw VoiceRealtimePartialTranscriptionError(confirmedText: _confirmedRealtimeTranscript, failure: error);
    } on TimeoutException catch (error) {
      throw VoiceRealtimePartialTranscriptionError(
        confirmedText: _confirmedRealtimeTranscript,
        failure: VoiceTranscriptionError.realtimeTimeout(cause: error),
      );
    } on RealtimeVoiceTransportClosedException catch (error) {
      throw VoiceRealtimePartialTranscriptionError(
        confirmedText: _confirmedRealtimeTranscript,
        failure: VoiceTranscriptionError.realtimeTransport(cause: error, retryable: true),
      );
    } on RealtimeVoiceProtocolException catch (error) {
      throw VoiceRealtimePartialTranscriptionError(
        confirmedText: _confirmedRealtimeTranscript,
        failure: VoiceTranscriptionError.realtimeContract(reason: error.message, cause: error),
      );
    }
  }

  Future<RealtimeVoiceEvent> _raceFinishWithFailure(RealtimeVoiceSession session) async {
    final failureFuture = _realtimeFailureCompleter?.future.then<RealtimeVoiceEvent>((error) => throw error);
    final finishFuture = session
        .finish()
        .timeout(_realtimeFinishTimeout)
        .onError<RealtimeVoiceTransportClosedException>((
          error,
          stackTrace,
        ) {
          final terminalEvent = _realtimeTerminalEvent;
          if (terminalEvent != null) {
            return terminalEvent;
          }
          Error.throwWithStackTrace(error, stackTrace);
        });
    if (failureFuture == null) return await finishFuture;
    return await Future.any<RealtimeVoiceEvent>([finishFuture, failureFuture]);
  }

  Future<void> _consumeCompletedSessionTerminal(RealtimeVoiceSession session) async {
    try {
      await session.finish();
    } catch (_) {
      return;
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
    _transcriptionGeneration++;

    if (_mode is _RealtimeVoiceRecordingMode) {
      await _stopRealtimeResources(sendCancel: true);
      await _stopRealtimeNativeRecorder();
    } else if (_isRecording) {
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
    _resetRealtimeState(emitPreview: true);
    _mode = const _AsyncVoiceRecordingMode(projectKey: null);
    _activeInteractionGeneration = null;
  }

  VoiceTranscriptionError _mapApiError(ApiError error) => switch (error) {
    NotAuthenticatedError() => VoiceTranscriptionError.notAuthenticated(
      cause: const _VoiceApiNotAuthenticatedException(),
    ),
    NonSuccessCodeError(:final errorCode) => VoiceTranscriptionError.serverError(errorCode),
    DartHttpClientError() => VoiceTranscriptionError.networkError(),
    JsonParsingError() => VoiceTranscriptionError.emptyTranscript(),
    EmptyResponseError() => VoiceTranscriptionError.emptyTranscript(),
    GenericError() => VoiceTranscriptionError.networkError(),
  };

  VoiceTranscriptionError _mapRealtimeStreamError(Exception error) => switch (error) {
    RealtimeVoiceProtocolException(:final message) => VoiceTranscriptionError.realtimeContract(
      reason: message,
      cause: error,
    ),
    FormatException(:final message) => VoiceTranscriptionError.realtimeContract(reason: message, cause: error),
    RealtimeVoiceTransportClosedException() => VoiceTranscriptionError.realtimeTransport(
      cause: error,
      retryable: true,
    ),
    _ => VoiceTranscriptionError.realtimeTransport(cause: error, retryable: true),
  };

  Exception _asException(Object error) => switch (error) {
    Exception() => error,
    Error() => _RealtimeUnknownErrorException(original: error),
    _ => _RealtimeUnknownValueException(original: error),
  };

  void _completeRealtimeFailure(VoiceTranscriptionError error) {
    _realtimeTerminalFailure ??= error;
    final failure = _realtimeFailureCompleter;
    if (failure != null && !failure.isCompleted) failure.complete(error);
  }

  void _resetRealtimeState({required bool emitPreview}) {
    _realtimeReadyCompleter = null;
    _realtimeFailureCompleter = null;
    _preAudioFallbackCompleter = Completer<_RealtimePreAudioFallback>();
    _pendingPreAudioFallback = null;
    _latestRealtimeRecordConfig = null;
    _announcedRealtimeFormat = null;
    _realtimeConfigCallbackSet = false;
    _realtimeNativeRecording = false;
    _realtimeRecorderStoppedByTerminal = false;
    _forwardRealtimeAudio = false;
    _sentRealtimeAudio = false;
    _realtimeSetupInProgress = false;
    _realtimePreAudioFallbackTransition = null;
    _terminalCaptureStopFuture = null;
    _realtimeTerminalEvent = null;
    _realtimeTerminalFailure = null;
    _confirmedRealtimeTranscript = "";
    _provisionalRealtimeTranscript = "";
    if (emitPreview) {
      _emitPreview();
    }
  }

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
          // ignore: prefer_specific_type -- Stream.listen error handlers require Object.
          onError: (Object error, StackTrace stackTrace) {
            logw("Amplitude stream error", error, stackTrace);
          },
        );
  }

  void _stopAmplitudeMonitoring() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(0.0);
    }
  }

  static double _normalizeAmplitude(double dBFS) {
    if (dBFS <= _amplitudeFloor) return 0.0;
    if (dBFS >= 0.0) return 1.0;
    return (dBFS - _amplitudeFloor) / -_amplitudeFloor;
  }

  Future<void> _stopRealtimeResources({required bool sendCancel}) async {
    _forwardRealtimeAudio = false;
    final ready = _realtimeReadyCompleter;
    if (sendCancel && ready != null && !ready.isCompleted) {
      ready.completeError(VoiceTranscriptionError.cancelled());
    }
    if (!_realtimeConfigCallbackSet &&
        _recorderStreamSub == null &&
        _realtimeEventSub == null &&
        _realtimeSession == null) {
      return;
    }
    if (_realtimeConfigCallbackSet) {
      await _recorder.setOnConfigChanged(null);
      _realtimeConfigCallbackSet = false;
    }
    await _recorderStreamSub?.cancel();
    _recorderStreamSub = null;
    await _realtimeEventSub?.cancel();
    _realtimeEventSub = null;
    final session = _realtimeSession;
    _realtimeSession = null;
    if (session == null) return;
    try {
      if (sendCancel) {
        await session.cancel();
      } else {
        await session.close();
      }
    } on RealtimeVoiceTransportClosedException {
      return;
    }
  }

  Future<void> _stopCaptureAfterRealtimeTerminal() async {
    final existingStop = _terminalCaptureStopFuture;
    if (existingStop != null) {
      await existingStop;
      return;
    }
    final stopFuture = _runStopCaptureAfterRealtimeTerminal();
    _terminalCaptureStopFuture = stopFuture;
    await stopFuture;
  }

  Future<void> _runStopCaptureAfterRealtimeTerminal() async {
    _forwardRealtimeAudio = false;
    _cancelMaxDurationTimer();
    _stopAmplitudeMonitoring();
    await _wakeLockService.disable();
    if (!_realtimeNativeRecording || _realtimeRecorderStoppedByTerminal) {
      _isRecording = false;
      return;
    }
    _realtimeRecorderStoppedByTerminal = true;
    try {
      await _recorder.stop();
    } catch (error, stackTrace) {
      logw("Failed to stop realtime recorder after terminal event", error, stackTrace);
    } finally {
      _realtimeNativeRecording = false;
      _isRecording = false;
      await _recorderStreamSub?.cancel();
      _recorderStreamSub = null;
    }
  }

  Future<void> _stopRealtimeNativeRecorder() async {
    final terminalStop = _terminalCaptureStopFuture;
    if (terminalStop != null) {
      await terminalStop;
      return;
    }
    if (!_realtimeNativeRecording || _realtimeRecorderStoppedByTerminal) return;
    _realtimeNativeRecording = false;
    _realtimeRecorderStoppedByTerminal = true;
    _isRecording = false;
    try {
      await _recorder.cancel();
    } catch (error, stackTrace) {
      logw("Failed to cancel realtime recorder", error, stackTrace);
    }
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

  void _emitPreview() {
    if (!_previewController.isClosed) {
      _previewController.add(currentPreview);
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final activeStart = _activeStartFuture;
    _invalidateActiveInteraction();
    _cancelMaxDurationTimer();
    _stopAmplitudeMonitoring();
    await _wakeLockService.disable();
    await _stopRealtimeResources(sendCancel: true);
    await _stopRealtimeNativeRecorder();
    var deferRecorderDispose = false;
    if (activeStart != null) {
      try {
        await activeStart.timeout(_activeSetupDisposeTimeout);
      } on TimeoutException catch (error, stackTrace) {
        logw("Timed out waiting for active voice setup during disposal", error, stackTrace);
        deferRecorderDispose = true;
      } on TranscriptionCancelledError {
        // Expected: disposal invalidates the active setup generation.
      }
    }
    await _amplitudeController.close();
    await _maxDurationReachedController.close();
    await _previewController.close();

    final prewarmFuture = _prewarmFuture;
    if (prewarmFuture != null) {
      try {
        await prewarmFuture.timeout(_recorderPrewarmTimeout);
      } on TimeoutException catch (error, stackTrace) {
        logw("Timed out waiting for recorder prewarm during disposal", error, stackTrace);
      }
    }

    if (deferRecorderDispose && activeStart != null) {
      unawaited(
        activeStart.whenComplete(_disposeRecorderSafely).catchError((Object error, StackTrace stackTrace) {
          logw("Active voice setup failed after deferred disposal", error, stackTrace);
        }),
      );
    } else {
      await _disposeRecorderSafely();
    }
    await _cleanup();
  }

  Future<void> _disposeRecorderSafely() async {
    try {
      await _recorder.dispose();
    } catch (error, stackTrace) {
      logw("Failed to dispose AudioRecorder", error, stackTrace);
    }
  }
}

final class const VoiceTranscriptionPreview({
  required final String confirmedText,
  required final String provisionalText,
});

sealed class const VoiceTranscriptionError._(final String message) implements Exception {
  factory microphonePermissionDenied() = MicrophonePermissionDeniedError._;

  factory recordingFailed() = RecordingFailedError._;

  factory notRecording() = NotRecordingError._;

  factory notAuthenticated({required Exception? cause}) = NotAuthenticatedVoiceError._;

  factory serverError(int statusCode) = ServerVoiceError._;

  factory emptyTranscript() = EmptyTranscriptError._;

  factory networkError() = NetworkVoiceError._;

  factory cancelled() = TranscriptionCancelledError._;

  factory contractFailure({required String reason, required Exception? cause}) = ContractVoiceError._;

  factory realtimeServer({required RealtimeVoiceErrorCode code}) = RealtimeServerVoiceError._;

  factory realtimeTransport({required Exception? cause, required bool retryable}) = RealtimeTransportVoiceError._;

  factory realtimeContract({required String reason, required Exception? cause}) = RealtimeContractVoiceError._;

  factory realtimeTimeout({required TimeoutException cause}) = RealtimeTimeoutVoiceError._;

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

class const NotAuthenticatedVoiceError._({required final Exception? cause}) extends VoiceTranscriptionError {
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

class const ContractVoiceError._({required final String reason, required final Exception? cause})
    extends VoiceTranscriptionError {
  this : super._("Realtime voice contract failure");
}

class const RealtimeServerVoiceError._({required final RealtimeVoiceErrorCode code}) extends VoiceTranscriptionError {
  bool get retryable => code.retryable;

  this : super._("Realtime voice server failure");
}

class const RealtimeTransportVoiceError._({required final Exception? cause, required final bool retryable})
    extends VoiceTranscriptionError {
  this : super._("Realtime voice transport failure");
}

class const RealtimeContractVoiceError._({required final String reason, required final Exception? cause})
    extends VoiceTranscriptionError {
  bool get retryable => false;

  this : super._("Realtime voice protocol failure");
}

class const RealtimeTimeoutVoiceError._({required final TimeoutException cause}) extends VoiceTranscriptionError {
  bool get retryable => true;

  this : super._("Realtime voice timed out");
}

class const VoiceRealtimePartialTranscriptionError({
  required final String confirmedText,
  required final VoiceTranscriptionError failure,
}) extends VoiceTranscriptionError {
  bool get retryable => switch (failure) {
    RealtimeServerVoiceError(:final retryable) => retryable,
    RealtimeTransportVoiceError(:final retryable) => retryable,
    RealtimeContractVoiceError(:final retryable) => retryable,
    RealtimeTimeoutVoiceError(:final retryable) => retryable,
    MicrophonePermissionDeniedError() => false,
    RecordingFailedError() => false,
    NotRecordingError() => false,
    NotAuthenticatedVoiceError() => false,
    ServerVoiceError() => false,
    EmptyTranscriptError() => false,
    NetworkVoiceError() => false,
    TranscriptionCancelledError() => false,
    ContractVoiceError() => false,
    VoiceRealtimePartialTranscriptionError() => false,
  };

  this : super._("Realtime voice partial transcription failure");
}

sealed class const _VoiceRecordingMode();

final class const _AsyncVoiceRecordingMode({required final String? projectKey}) extends _VoiceRecordingMode;

final class const _RealtimeVoiceRecordingMode({required final String projectKey}) extends _VoiceRecordingMode;

final class const _RealtimePreAudioFallback(final Exception cause) implements Exception;

final class const _RealtimeFormatException({required final String message, required final UnsupportedError? cause})
    implements Exception;

final class const _RealtimeSetupException(final String message) implements Exception;

final class const _RealtimeUnknownErrorException({required final Error original}) implements Exception;

final class const _RealtimeUnknownValueException({
  // ignore: no_slop_linter/prefer_specific_type -- preserves arbitrary stream error values exactly.
  required final Object original,
}) implements Exception;

final class const _VoiceApiNotAuthenticatedException() implements Exception;

final class const _VoiceCapabilitiesContractException(final String reason) implements Exception;
