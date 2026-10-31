import "dart:async";
import "dart:io" show WebSocketException;
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey;
import "package:web_socket_channel/io.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "../../foundation/models/voice/voice_realtime.dart";
import "../../logging/logging.dart";
import "realtime_voice_protocol.dart";

typedef RealtimeVoiceChannelConnector = WebSocketChannel Function({
  required Uri uri,
  required Map<String, String> headers,
});

const _upgradeTimeout = Duration(seconds: 10);
const _closeTimeout = Duration(seconds: 3);

/// Same cadence as [RelayClient]: `dart:io` closes the socket when a pong does
/// not arrive within the next interval, so a dead network ends the session
/// through the normal close path.
const _pingInterval = Duration(seconds: 15);

/// The default [RealtimeVoiceChannelConnector].
@visibleForTesting
WebSocketChannel connectRealtimeVoiceChannel({required Uri uri, required Map<String, String> headers}) =>
    IOWebSocketChannel.connect(uri, headers: headers, pingInterval: _pingInterval);

/// Opens `/voice/realtime` sockets. The access token goes only in the upgrade
/// header. A server that rejects it fails the attempt rather than refreshing and
/// retrying here: live falls back to after-recording, whose upload refreshes.
@lazySingleton
class RealtimeVoiceClient._({
  required final AuthTokenProvider _tokenProvider,
  required final RealtimeVoiceChannelConnector _channelConnector,
}) {
  new({required AuthTokenProvider tokenProvider})
    : this._(tokenProvider: tokenProvider, channelConnector: connectRealtimeVoiceChannel);

  @visibleForTesting
  new withChannelConnector({
    required AuthTokenProvider tokenProvider,
    required RealtimeVoiceChannelConnector channelConnector,
  }) : this._(tokenProvider: tokenProvider, channelConnector: channelConnector);

  /// Returns once the upgrade succeeded and `start` is on its way, without
  /// waiting for `ready`, which arrives through [RealtimeVoiceSession.events].
  ///
  /// Throws a [RealtimeVoiceException] if the token read or the upgrade fails.
  Future<RealtimeVoiceSession> open({
    required VoiceRealtimeSampleRate sampleRate,
    required ProjectGlossaryKey? projectKey,
  }) async {
    final sinceConnect = Stopwatch()..start();
    final String? token;
    try {
      token = await _tokenProvider.getFreshAccessToken();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        RealtimeVoiceConnectionException(closeCode: null, closeReason: null, cause: error),
        stackTrace,
      );
    }
    if (token == null) {
      throw const RealtimeVoiceNotAuthenticatedException();
    }

    final channel = _channelConnector(
      uri: Uri.parse(authBaseUrl).replace(scheme: "wss", path: "/voice/realtime"),
      headers: {"Authorization": "Bearer $token"},
    );
    // Upgrade failures reach both the stream and `ready`, so the session
    // subscribes first to drain the stream, and `ready` owns the error.
    final session = RealtimeVoiceSession._(channel: channel, sinceConnect: sinceConnect);
    try {
      await channel.ready.timeout(_upgradeTimeout);
    } on Object catch (error, stackTrace) {
      unawaited(session.cancel());
      Error.throwWithStackTrace(_upgradeFailure(error: error), stackTrace);
    }
    channel.sink.add(encodeRealtimeVoiceStart(sampleRate: sampleRate, projectKey: projectKey));
    return session;
  }

  static RealtimeVoiceException _upgradeFailure({required Object error}) => switch (error) {
    WebSocketChannelException(inner: WebSocketException(httpStatusCode: final int statusCode)) =>
      RealtimeVoiceUpgradeRejectedException(statusCode: statusCode, cause: error),
    _ => RealtimeVoiceConnectionException(closeCode: null, closeReason: null, cause: error),
  };
}

enum _SessionPhase() {
  awaitingReady,
  streaming,
  finishing,
  ended,
}

/// One open socket, from `start` to its terminal event.
///
/// Sending audio or `finish` before `ready`, or audio after `finish`, would make
/// the server end the session, so those calls throw [StateError]. Their order is
/// the caller's to hold. Once the session has ended, sends do nothing: the
/// microphone can outrun the terminal event, and the caller hears that event.
final class RealtimeVoiceSession._({
  required final WebSocketChannel _channel,
  required final Stopwatch _sinceConnect,
}) {
  final StreamController<RealtimeVoiceEvent> _events = StreamController<RealtimeVoiceEvent>();
  late final StreamSubscription<void> _subscription;
  _SessionPhase _phase = _SessionPhase.awaitingReady;

  this {
    unawaited(
      _channel.sink.done.catchError((Object error, StackTrace stackTrace) {
        logw("Realtime voice sink closed with an error", error, stackTrace);
      }),
    );
    _subscription = _channel.stream.listen(_onFrame, onError: _onSocketError, onDone: _onSocketDone);
  }

  /// Single subscription. Closes after a terminal event or [cancel].
  Stream<RealtimeVoiceEvent> get events => _events.stream;

  /// Sends one PCM16 frame. Throws [ArgumentError] unless it is even-length and
  /// within the protocol's frame size.
  void sendAudio({required Uint8List frame}) {
    if (frame.length < realtimeVoiceMinFrameBytes || frame.length > realtimeVoiceMaxFrameBytes || frame.length.isOdd) {
      throw ArgumentError.value(frame.length, "frame.length", "Not a valid PCM16 frame size");
    }
    switch (_phase) {
      case _SessionPhase.awaitingReady:
        throw StateError("Realtime voice audio before ready");
      case _SessionPhase.finishing:
        throw StateError("Realtime voice audio after finish");
      case _SessionPhase.streaming:
        _channel.sink.add(frame);
      case _SessionPhase.ended:
        break;
    }
  }

  /// Asks the server to finalize. The terminal event arrives through [events].
  void finish() {
    switch (_phase) {
      case _SessionPhase.awaitingReady:
        throw StateError("Realtime voice finish before ready");
      case _SessionPhase.streaming:
        _phase = _SessionPhase.finishing;
        _channel.sink.add(realtimeVoiceFinishFrame);
      case _SessionPhase.finishing:
      case _SessionPhase.ended:
        break;
    }
  }

  /// Ends the session and closes the socket. Only a streaming server is sent
  /// `cancel`: before `ready` it would answer with an error, after `finish` it
  /// ignores controls, and closing the socket releases the session either way.
  Future<void> cancel() async {
    if (_phase == _SessionPhase.ended) return;
    if (_phase == _SessionPhase.streaming) {
      _channel.sink.add(realtimeVoiceCancelFrame);
    }
    _phase = _SessionPhase.ended;
    unawaited(_events.close());
    await _closeSocket();
  }

  // ignore: no_slop_linter/prefer_specific_type, web_socket_channel exposes arbitrary inbound frames
  void _onFrame(Object? frame) {
    if (_phase == _SessionPhase.ended) return;

    final RealtimeVoiceServerEvent event;
    try {
      if (frame is! String) {
        throw const RealtimeVoiceProtocolException(message: "Server sent a binary frame");
      }
      event = parseRealtimeVoiceEvent(frame: frame);
    } on RealtimeVoiceProtocolException catch (error) {
      _end(event: RealtimeVoiceConnectionFailedEvent(exception: error));
      return;
    }

    switch (event) {
      case RealtimeVoiceReadyEvent():
        if (_phase == _SessionPhase.awaitingReady) {
          _phase = _SessionPhase.streaming;
          // Audio waits in memory until now (D29), so this sizes that buffer.
          logi("[voice] realtime ready ${_sinceConnect.elapsedMilliseconds} ms after connect");
        }
        _events.add(event);
      case RealtimeVoiceTranscriptEvent():
        _events.add(event);
      case RealtimeVoiceCompleteEvent() || RealtimeVoiceErrorEvent():
        _end(event: event);
    }
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, stream callback signature is positional
  void _onSocketError(Object error) => _endForConnectionLoss(cause: error);

  void _onSocketDone() => _endForConnectionLoss(cause: null);

  // ignore: no_slop_linter/prefer_specific_type, socket errors can be any object
  void _endForConnectionLoss({required Object? cause}) {
    if (_phase == _SessionPhase.ended) return;
    final exception = RealtimeVoiceConnectionException(
      closeCode: _channel.closeCode,
      closeReason: _channel.closeReason,
      cause: cause,
    );
    _end(event: RealtimeVoiceConnectionFailedEvent(exception: exception));
  }

  void _end({required RealtimeVoiceEvent event}) {
    _phase = _SessionPhase.ended;
    _events.add(event);
    unawaited(_events.close());
    unawaited(_closeSocket());
  }

  /// Always closes as normal: `package:web_socket` throws for any other code
  /// below 3000, from a callback nothing here could catch.
  Future<void> _closeSocket() async {
    try {
      await _subscription.cancel();
      await _channel.sink.close(realtimeVoiceNormalCloseCode).timeout(_closeTimeout);
    } on Object catch (error, stackTrace) {
      logw("Realtime voice socket teardown failed", error, stackTrace);
    }
  }
}
