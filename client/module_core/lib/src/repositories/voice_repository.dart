import "dart:async";
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey;

import "../api/embedded_speech_api.dart";
import "../api/on_device_speech_api.dart";
import "../capabilities/voice/realtime_voice_client.dart";
import "../capabilities/voice/realtime_voice_protocol.dart";
import "../capabilities/voice/voice_api.dart";
import "../foundation/models/voice/voice_dictation_outcome.dart";
import "../foundation/models/voice/voice_realtime.dart";
import "../foundation/models/voice/voice_transcription_error.dart";
import "../foundation/platform/on_device_speech_source.dart";
import "../logging/logging.dart";

/// How long the device's engine gets to start before a dictation goes to the server.
const Duration _onDeviceStartTimeout = Duration(seconds: 5);

/// How long the device's engine gets to finish after the last audio. It works
/// locally, so this only ever fires for an engine that stopped answering.
const Duration _onDeviceFinishTimeout = Duration(seconds: 15);

@lazySingleton
class VoiceRepository({
  required final VoiceApi _api,
  required final RealtimeVoiceClient _realtimeClient,
  required final OnDeviceSpeechApi _onDeviceSpeechApi,
  required final EmbeddedSpeechApi _embeddedSpeechApi,
}) {
  Future<VoiceTranscriptionOutcome> transcribe({
    required String audioFilePath,
    required String mimeType,
    required ProjectGlossaryKey? projectGlossaryKey,
  }) async {
    final response = await _api.transcribe(
      audioFilePath: audioFilePath,
      mimeType: mimeType,
      projectGlossaryKey: projectGlossaryKey,
    );
    return switch (response) {
      VoiceTranscriptionApiSuccess(:final transcript) => VoiceTranscriptionOutcome.success(
        transcript: transcript,
      ),
      VoiceTranscriptionApiFailure(:final error, :final retryable) => _mapError(
        error: error,
        retryable: retryable,
      ),
    };
  }

  /// Opens a live dictation socket. Returns once the upgrade succeeded; audio may
  /// follow only after [VoiceRealtimeReady].
  ///
  /// Throws a [VoiceTranscriptionError] holding the original as its `innerError`.
  /// A disabled server rejects the upgrade with 404, so it is a [ServerVoiceError].
  Future<VoiceRealtimeConnection> openRealtime({
    required VoiceRealtimeSampleRate sampleRate,
    required ProjectGlossaryKey? projectKey,
  }) async {
    try {
      final session = await _realtimeClient.open(sampleRate: sampleRate, projectKey: projectKey);
      return _ServerVoiceConnection(session: session);
    } on RealtimeVoiceException catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapRealtimeException(exception: error), stackTrace);
    }
  }

  /// Whether this device can transcribe right now. Never throws: any doubt means
  /// the dictation stays on the server.
  Future<bool> prepareOnDevice() => _prepareEngine(preparing: _onDeviceSpeechApi.prepare());

  /// Like [prepareOnDevice], for the speech model shipped inside the app.
  Future<bool> prepareEmbedded() => _prepareEngine(preparing: _embeddedSpeechApi.prepare());

  /// Opens a dictation on the device's own engine. It is ready as soon as this
  /// returns. Throws a [VoiceTranscriptionError] holding the original as its
  /// `innerError`.
  Future<VoiceRealtimeConnection> openOnDevice({required VoiceRealtimeSampleRate sampleRate}) =>
      _openEngine(opening: _onDeviceSpeechApi.open(sampleRate: sampleRate));

  /// Like [openOnDevice], for the speech model shipped inside the app.
  Future<VoiceRealtimeConnection> openEmbedded({required VoiceRealtimeSampleRate sampleRate}) =>
      _openEngine(opening: _embeddedSpeechApi.open(sampleRate: sampleRate));

  Future<bool> _prepareEngine({required Future<bool> preparing}) async {
    try {
      return await preparing;
    } catch (error, stackTrace) {
      logw("Could not check on-device speech; staying on the server", error, stackTrace);
      return false;
    }
  }

  Future<VoiceRealtimeConnection> _openEngine({required Future<OnDeviceSpeechSession> opening}) async {
    try {
      return _OnDeviceVoiceConnection(session: await opening.timeout(_onDeviceStartTimeout));
    } catch (error, stackTrace) {
      // A late start would otherwise leave an engine running that nobody can stop.
      if (error is TimeoutException) unawaited(_cancelLateOnDeviceStart(opening: opening));
      Error.throwWithStackTrace(VoiceTranscriptionError.recordingFailed(innerError: error), stackTrace);
    }
  }

  Future<void> _cancelLateOnDeviceStart({required Future<OnDeviceSpeechSession> opening}) async {
    try {
      final session = await opening;
      await session.cancel();
    } catch (error, stackTrace) {
      logw("A late on-device speech start failed", error, stackTrace);
    }
  }

  VoiceTranscriptionOutcome _mapError({
    required ApiError error,
    required bool? retryable,
  }) => switch (error) {
    NotAuthenticatedError() => const VoiceTranscriptionOutcome.notAuthenticated(),
    NonSuccessCodeError(:final errorCode) when retryable ?? false => VoiceTranscriptionOutcome.retryableServerFailure(
      statusCode: errorCode,
    ),
    // COMPATIBILITY 2026-08-28 (v1.8.2): Older auth servers can omit retryability.
    // Retire when every supported auth server returns a boolean for every transcribe failure.
    NonSuccessCodeError(:final errorCode) => VoiceTranscriptionOutcome.terminalServerFailure(statusCode: errorCode),
    DartHttpClientError() => const VoiceTranscriptionOutcome.networkFailure(),
    GenericError() => const VoiceTranscriptionOutcome.unexpectedFailure(),
    JsonParsingError() || EmptyResponseError() => const VoiceTranscriptionOutcome.emptyTranscript(),
  };
}

/// A live dictation's engine, in domain terms. [events] closes after a terminal
/// event or [cancel].
abstract interface class VoiceRealtimeConnection() {
  Stream<VoiceRealtimeEvent> get events;

  /// Returns whether the frame went out; once the session has ended it doesn't.
  /// Call only after [VoiceRealtimeReady] and before [finish].
  bool sendAudio({required Uint8List frame});

  /// Call only after [VoiceRealtimeReady].
  void finish();

  Future<void> cancel();
}

final class _ServerVoiceConnection({required final RealtimeVoiceSession _session}) implements VoiceRealtimeConnection {
  @override
  Stream<VoiceRealtimeEvent> get events => _session.events.map(_mapRealtimeEvent);

  /// Throws [StateError] before [VoiceRealtimeReady] or after [finish], and
  /// [ArgumentError] for a frame the protocol does not allow.
  @override
  bool sendAudio({required Uint8List frame}) => _session.sendAudio(frame: frame);

  /// Throws [StateError] before [VoiceRealtimeReady].
  @override
  void finish() => _session.finish();

  @override
  Future<void> cancel() => _session.cancel();
}

/// A dictation on an engine on the device. It owns the engine's session, and [events]
/// always ends with exactly one terminal event unless [cancel] came first.
final class _OnDeviceVoiceConnection({required final OnDeviceSpeechSession _session})
    implements VoiceRealtimeConnection {
  static final RegExp _startsWithUnspacedScript = RegExp(
    r"^[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]",
    unicode: true,
  );

  final StreamController<VoiceRealtimeEvent> _events = StreamController<VoiceRealtimeEvent>();
  late final StreamSubscription<OnDeviceSpeechEvent> _subscription;
  Timer? _finishTimeout;
  bool _hasConfirmedWords = false;
  bool _ended = false;

  this {
    _events.add(const VoiceRealtimeReady());
    _subscription = _session.events.listen(
      _onEvent,
      onError: (Object error, StackTrace stackTrace) => _fail(cause: error),
      onDone: () => _fail(cause: StateError("On-device speech closed without an ending")),
    );
  }

  @override
  Stream<VoiceRealtimeEvent> get events => _events.stream;

  @override
  bool sendAudio({required Uint8List frame}) {
    if (_ended) return false;
    _session.sendAudio(frame: frame);
    return true;
  }

  @override
  void finish() {
    if (_ended) return;
    _session.finish();
    _finishTimeout = Timer(_onDeviceFinishTimeout, () {
      _fail(cause: TimeoutException("On-device speech did not finish", _onDeviceFinishTimeout));
    });
  }

  @override
  Future<void> cancel() async {
    if (_ended) return;
    await _endWith(event: null);
    await _session.cancel();
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, stream callback signature is positional
  void _onEvent(OnDeviceSpeechEvent event) {
    if (_ended) return;
    switch (event) {
      case OnDeviceSpeechWords(:final confirmedDelta, :final provisional):
        final spacedDelta = _spaced(words: confirmedDelta);
        if (spacedDelta.isNotEmpty) _hasConfirmedWords = true;
        _events.add(
          VoiceRealtimeWords(
            confirmedDelta: spacedDelta,
            provisional: _spaced(words: provisional),
          ),
        );
      case OnDeviceSpeechCompleted():
        unawaited(_endWith(event: const VoiceRealtimeCompleted(outcome: VoiceDictationOutcome.finished)));
      case OnDeviceSpeechFailed(:final cause):
        _fail(cause: cause);
    }
  }

  /// The run joins words as they come, and engines report them bare. Chinese and
  /// Japanese don't put spaces between words.
  String _spaced({required String words}) {
    final trimmed = words.trim();
    final needsSpace = trimmed.isNotEmpty && _hasConfirmedWords && !_startsWithUnspacedScript.hasMatch(trimmed);
    return needsSpace ? " $trimmed" : trimmed;
  }

  // ignore: no_slop_linter/prefer_specific_type, causes can be any object
  void _fail({required Object cause}) {
    if (_ended) return;
    unawaited(_session.cancel());
    unawaited(
      _endWith(
        event: VoiceRealtimeFailed(error: VoiceTranscriptionError.recordingFailed(innerError: cause)),
      ),
    );
  }

  Future<void> _endWith({required VoiceRealtimeEvent? event}) async {
    _ended = true;
    _finishTimeout?.cancel();
    if (event != null) _events.add(event);
    // Closing waits for a listener, and a connection cancelled unused never has one.
    unawaited(_events.close());
    await _subscription.cancel();
  }
}

VoiceRealtimeEvent _mapRealtimeEvent(RealtimeVoiceEvent event) => switch (event) {
  RealtimeVoiceReadyEvent() => const VoiceRealtimeReady(),
  RealtimeVoiceTranscriptEvent(:final confirmedDelta, :final provisional) => VoiceRealtimeWords(
    confirmedDelta: confirmedDelta,
    provisional: provisional,
  ),
  RealtimeVoiceCompleteEvent(:final reason) => VoiceRealtimeCompleted(
    outcome: switch (reason) {
      RealtimeVoiceCompleteReason.finished => VoiceDictationOutcome.finished,
      RealtimeVoiceCompleteReason.sessionLimit ||
      RealtimeVoiceCompleteReason.quotaLimit => VoiceDictationOutcome.limitReached,
    },
  ),
  RealtimeVoiceErrorEvent(:final code) => VoiceRealtimeFailed(
    // The server closes with this code, so it stands in for an HTTP status.
    error: code.retryable
        ? VoiceTranscriptionError.retryableServerError(statusCode: code.closeCode, innerError: event)
        : VoiceTranscriptionError.serverError(statusCode: code.closeCode, innerError: event),
  ),
  RealtimeVoiceConnectionFailedEvent(:final exception) => VoiceRealtimeFailed(
    error: _mapRealtimeException(exception: exception),
  ),
};

VoiceTranscriptionError _mapRealtimeException({required RealtimeVoiceException exception}) => switch (exception) {
  RealtimeVoiceNotAuthenticatedException() ||
  RealtimeVoiceUpgradeRejectedException(statusCode: 401) => VoiceTranscriptionError.notAuthenticated(
    innerError: exception,
  ),
  RealtimeVoiceUpgradeRejectedException(:final statusCode) when statusCode == 429 || statusCode >= 500 =>
    VoiceTranscriptionError.retryableServerError(statusCode: statusCode, innerError: exception),
  RealtimeVoiceUpgradeRejectedException(:final statusCode) => VoiceTranscriptionError.serverError(
    statusCode: statusCode,
    innerError: exception,
  ),
  RealtimeVoiceConnectionException() => VoiceTranscriptionError.networkError(innerError: exception),
  RealtimeVoiceProtocolException() => VoiceTranscriptionError.serverError(
    statusCode: realtimeVoiceProtocolViolationCode,
    innerError: exception,
  ),
};

sealed class const VoiceTranscriptionOutcome() {
  const factory success({required String transcript}) = VoiceTranscriptionSuccess;

  const factory notAuthenticated() = VoiceTranscriptionNotAuthenticated;

  const factory retryableServerFailure({required int statusCode}) = VoiceTranscriptionRetryableServerFailure;

  const factory terminalServerFailure({required int statusCode}) = VoiceTranscriptionTerminalServerFailure;

  const factory networkFailure() = VoiceTranscriptionNetworkFailure;

  const factory unexpectedFailure() = VoiceTranscriptionUnexpectedFailure;

  const factory emptyTranscript() = VoiceTranscriptionEmptyTranscript;
}

final class const VoiceTranscriptionSuccess({required final String transcript}) extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionNotAuthenticated() extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionRetryableServerFailure({required final int statusCode})
    extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionTerminalServerFailure({required final int statusCode})
    extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionNetworkFailure() extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionUnexpectedFailure() extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionEmptyTranscript() extends VoiceTranscriptionOutcome;
