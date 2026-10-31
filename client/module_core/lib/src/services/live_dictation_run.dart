import "dart:async";
import "dart:collection";
import "dart:typed_data";

import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey;

import "../foundation/models/voice/voice_dictation_outcome.dart";
import "../foundation/models/voice/voice_live.dart";
import "../foundation/models/voice/voice_realtime.dart";
import "../foundation/models/voice/voice_transcription_error.dart";
import "../logging/logging.dart";
import "../platform/voice_capture.dart";
import "../repositories/voice_repository.dart";

const int _pcmBytesPerSample = 2;

final int _pcmBytesPerSecond = _pcmBytesPerSample * voiceCapturePcmSampleRate.hertz;

/// How far audio may get ahead of real time, counted from `ready`: 4 seconds. The
/// server allows 5 and ends a session that sends more with `invalid_audio`, which
/// would lose everything said so far.
final int _maxLeadBytes = 4 * _pcmBytesPerSecond;

/// How much audio may wait for `ready` (D29): 30 seconds, under 1 MB. All of it is
/// sent, at most [_maxLeadBytes] at once and then at real time, so a release after
/// the slowest start waits about 26 seconds. By 30 seconds a socket has had its full
/// chance: the upgrade gives up at 10, and a dead one closes after two 15 second
/// pings. Falling back then keeps the rest of the dictation, and it reaches the box
/// with a cut-off notice.
final int _maxHeldAudioBytes = 30 * _pcmBytesPerSecond;

const Duration _pacingTick = Duration(milliseconds: 100);

/// How a [LiveDictationRun] ended. By then its socket and microphone are released.
sealed class const LiveDictationEnding();

/// There are words to hand over.
final class const LiveDictationEnded({
  required final String transcript,
  required final VoiceDictationOutcome outcome,
}) extends LiveDictationEnding;

/// There is nothing to hand over and nothing left to try.
final class const LiveDictationFailed({required final VoiceTranscriptionError error}) extends LiveDictationEnding;

/// [error] came before any audio left, so a dictation still held can go on as a
/// recording (D21).
final class const LiveDictationFellBack({required final VoiceTranscriptionError error}) extends LiveDictationEnding;

final class const LiveDictationCancelled() extends LiveDictationEnding;

sealed class const _SocketPhase();

final class const _SocketConnecting() extends _SocketPhase;

final class const _SocketAwaitingReady({required final VoiceRealtimeConnection connection}) extends _SocketPhase;

final class const _SocketStreaming({required final VoiceRealtimeConnection connection}) extends _SocketPhase;

/// Streaming, with held audio the server doesn't allow yet. [timer] sends it, and new
/// frames queue behind it.
final class const _SocketPacing({
  required final VoiceRealtimeConnection connection,
  required final Timer timer,
}) extends _SocketPhase;

final class const _SocketEnded() extends _SocketPhase;

/// One live dictation: its socket, its microphone frames and the audio that waits
/// for `ready`. It starts as soon as it is built, and [ended] always completes.
final class LiveDictationRun({
  required final VoiceRepository _repository,
  required final VoiceCaptureSession _capture,
  required final void Function({required LiveWords words}) _onWords,
  required Stream<Uint8List> frames,
  required ProjectGlossaryKey? projectKey,
}) {
  final Completer<LiveDictationEnding> _ended = Completer<LiveDictationEnding>();
  final Queue<Uint8List> _heldAudio = Queue<Uint8List>();
  late final StreamSubscription<Uint8List> _frameSubscription;
  _SocketPhase _phase = const _SocketConnecting();
  LiveWords _words = LiveWords.none;
  int _heldBytes = 0;
  bool _audioForwarded = false;
  bool _micDone = false;

  /// Set once the user has released.
  Future<void>? _micStop;

  this {
    _frameSubscription = frames.listen(
      _onFrame,
      onError: (Object error, StackTrace stackTrace) => _fail(
        error: VoiceTranscriptionError.recordingFailed(innerError: error),
        stackTrace: stackTrace,
      ),
      onDone: _onFramesDone,
    );
    unawaited(_connect(projectKey: projectKey));
  }

  Future<LiveDictationEnding> get ended => _ended.future;

  /// Stops the microphone and asks for the final words once its last frames are
  /// out, which waits for `ready` after a quick release and for the allowed pace
  /// after a slow start.
  Future<LiveDictationEnding> finish() {
    if (_phase is! _SocketEnded) _micStop ??= _stopMic();
    return _ended.future;
  }

  /// Sends `cancel` when the socket is streaming, and releases everything.
  Future<void> cancel() async {
    if (_phase is! _SocketEnded) unawaited(_end(ending: const LiveDictationCancelled()));
    await _ended.future;
  }

  Future<void> _connect({required ProjectGlossaryKey? projectKey}) async {
    final VoiceRealtimeConnection connection;
    try {
      connection = await _repository.openRealtime(sampleRate: voiceCapturePcmSampleRate, projectKey: projectKey);
    } on VoiceTranscriptionError catch (error, stackTrace) {
      _fail(error: error, stackTrace: stackTrace);
      return;
    }
    if (_phase is _SocketEnded) {
      unawaited(connection.cancel());
      return;
    }
    _phase = _SocketAwaitingReady(connection: connection);
    connection.events.listen(_onSocketEvent);
  }

  void _onFrame(Uint8List frame) {
    switch (_phase) {
      case _SocketStreaming(:final connection):
        _forward(connection: connection, frame: frame);
      case _SocketPacing():
        _heldAudio.add(frame);
      case _SocketConnecting() || _SocketAwaitingReady():
        _heldAudio.add(frame);
        _heldBytes += frame.length;
        if (_heldBytes > _maxHeldAudioBytes) {
          _fail(
            error: VoiceTranscriptionError.networkError(innerError: StateError("Realtime voice was not ready in time")),
            stackTrace: StackTrace.current,
          );
        }
      case _SocketEnded():
        break;
    }
  }

  void _onFramesDone() {
    _micDone = true;
    if (_phase case _SocketStreaming(:final connection)) connection.finish();
  }

  void _onSocketEvent(VoiceRealtimeEvent event) {
    if (_phase is _SocketEnded) return;
    switch (event) {
      case VoiceRealtimeReady():
        _onReady();
      case VoiceRealtimeWords(:final confirmedDelta, :final provisional):
        _words = LiveWords(confirmed: _words.confirmed + confirmedDelta, provisional: provisional);
        _onWords(words: _words);
      case VoiceRealtimeCompleted(:final outcome):
        _onCompleted(outcome: outcome);
      case VoiceRealtimeFailed(:final error):
        _fail(error: error, stackTrace: StackTrace.current);
    }
  }

  void _onReady() {
    final phase = _phase;
    if (phase is! _SocketAwaitingReady) return;
    final connection = phase.connection;
    var sentBytes = _sendHeld(connection: connection, sentBytes: 0, allowedBytes: _maxLeadBytes);
    if (_heldAudio.isEmpty) {
      _streamDirectly(connection: connection);
      return;
    }
    _phase = _SocketPacing(
      connection: connection,
      timer: Timer.periodic(_pacingTick, (timer) {
        // The tick counts the time passed even when a callback runs late, and the
        // server's clock started first, so this can't run ahead of it.
        final allowedBytes = _maxLeadBytes + _pcmBytesPerSecond * timer.tick * _pacingTick.inMilliseconds ~/ 1000;
        sentBytes = _sendHeld(connection: connection, sentBytes: sentBytes, allowedBytes: allowedBytes);
        if (_heldAudio.isEmpty) {
          timer.cancel();
          _streamDirectly(connection: connection);
        }
      }),
    );
  }

  /// Sends the oldest held frames that fit, and returns the new total. Frames stay
  /// whole, so a sample is never cut, and one that doesn't fit yet waits its turn.
  int _sendHeld({required VoiceRealtimeConnection connection, required int sentBytes, required int allowedBytes}) {
    var total = sentBytes;
    while (_heldAudio.isNotEmpty && total + _heldAudio.first.length <= allowedBytes) {
      final frame = _heldAudio.removeFirst();
      _forward(connection: connection, frame: frame);
      total += frame.length;
    }
    return total;
  }

  void _streamDirectly({required VoiceRealtimeConnection connection}) {
    _phase = _SocketStreaming(connection: connection);
    if (_micDone) connection.finish();
  }

  void _forward({required VoiceRealtimeConnection connection, required Uint8List frame}) {
    _audioForwarded = true;
    connection.sendAudio(frame: frame);
  }

  /// The server finalizes before it completes, so what is still provisional is
  /// not part of the result.
  void _onCompleted({required VoiceDictationOutcome outcome}) {
    final transcript = _words.confirmed.trim();
    unawaited(
      _end(
        ending: transcript.isEmpty && outcome == VoiceDictationOutcome.finished
            ? LiveDictationFailed(error: VoiceTranscriptionError.emptyTranscript())
            : LiveDictationEnded(transcript: transcript, outcome: outcome),
      ),
    );
  }

  /// A failure never reaches the send path: words go to the box and nothing else
  /// can be recovered, since live keeps no recording (D20).
  void _fail({required VoiceTranscriptionError error, required StackTrace stackTrace}) {
    if (_phase is _SocketEnded) return;
    logw("Live dictation failed", _diagnosticCause(error: error), stackTrace);

    final words = _words.text.trim();
    unawaited(
      _end(
        ending: !_audioForwarded
            ? LiveDictationFellBack(error: error)
            : words.isEmpty
            ? LiveDictationFailed(error: error)
            : LiveDictationEnded(transcript: words, outcome: VoiceDictationOutcome.interrupted),
      ),
    );
  }

  Future<void> _stopMic() async {
    try {
      await _capture.stopPcmStream();
    } on VoiceCaptureError catch (error, stackTrace) {
      // The microphone may still be on and its stream still open. Cancelling stops
      // it again and closes the stream, so the audio already sent can still finish.
      logw("Failed to stop the live microphone", error, stackTrace);
      await _cancelCapture();
    }
  }

  /// Stops the microphone if it is still on, and releases the operation.
  Future<void> _cancelCapture() async {
    try {
      await _capture.cancel();
    } catch (error, stackTrace) {
      logw("Failed to release the live microphone", error, stackTrace);
    }
  }

  Future<void> _end({required LiveDictationEnding ending}) async {
    final phase = _phase;
    _phase = const _SocketEnded();
    _heldAudio.clear();
    switch (phase) {
      case _SocketPacing(:final connection, :final timer):
        timer.cancel();
        unawaited(connection.cancel());
      case _SocketAwaitingReady(:final connection) || _SocketStreaming(:final connection):
        unawaited(connection.cancel());
      case _SocketConnecting() || _SocketEnded():
        break;
    }

    await _frameSubscription.cancel();
    await _micStop;
    await _cancelCapture();
    _ended.complete(ending);
  }
}

/// The wrappers keep their presentation safe, so the close code and reason that
/// make a failure diagnosable are on the cause.
// ignore: no_slop_linter/prefer_specific_type, causes can be any object
Object _diagnosticCause({required VoiceTranscriptionError error}) => switch (error) {
  NetworkVoiceError(:final innerError) ||
  ServerVoiceError(:final innerError) ||
  RetryableServerVoiceError(:final innerError) ||
  NotAuthenticatedVoiceError(:final innerError) => innerError ?? error,
  RecordingFailedError(:final innerError) => innerError,
  MicrophonePermissionDeniedError() ||
  NotRecordingError() ||
  EmptyTranscriptError() ||
  MissingRecordingArtifactError() ||
  TranscriptionCancelledError() => error,
};
