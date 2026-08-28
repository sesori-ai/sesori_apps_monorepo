import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "../capabilities/voice/project_glossary_key.dart";
import "../foundation/platform/realtime_websocket_connector.dart";
import "../logging/logging.dart";
import "models/realtime_voice_protocol.dart";

final class const RealtimeVoiceTransportClosedException() implements Exception;

const realtimeVoiceConnectTimeout = Duration(seconds: 10);

/// Maximum time close/cancel waits for stream cancellation and socket close.
const realtimeVoiceCloseTimeout = Duration(seconds: 3);

@lazySingleton
class RealtimeVoiceApi({
  required final RealtimeWebSocketConnector connector,
  required final AuthTokenProvider tokenProvider,
}) {
  Future<RealtimeVoiceSession> start({required RealtimeAudioFormat audio, required String? projectKey}) async {
    // This API promises auth only ever sees the opaque derived key. Refuse a
    // value that is not one rather than forwarding it, so a caller that passes
    // a raw project ID fails here instead of leaking it off the device.
    if (projectKey != null && !isValidProjectGlossaryKey(value: projectKey)) {
      throw const RealtimeVoiceProtocolException("Realtime projectKey must be an opaque project glossary key");
    }
    final token = await tokenProvider.getFreshAccessToken();
    if (token == null) {
      throw const RealtimeVoiceOpenAuthenticationException(cause: null, httpStatus: null);
    }
    final channel = await connector.connect(
      uri: Uri.parse(authBaseUrl).replace(scheme: "wss", path: "/voice/realtime", query: null),
      headers: {"Authorization": "Bearer $token"},
      connectTimeout: realtimeVoiceConnectTimeout,
    );
    final session = RealtimeVoiceSession(channel: channel);
    try {
      session._sendJson(RealtimeStartMessage(audio: audio, projectKey: projectKey).toJson());
    } on Object {
      // The session already subscribed to the channel, so a send that fails
      // between `ready` and the start frame would strand the transport. Release
      // it here and let the original failure reach the caller unchanged.
      unawaited(session.close());
      rethrow;
    }
    return session;
  }
}

final class RealtimeVoiceSession({required final WebSocketChannel channel}) {
  final StreamController<RealtimeVoiceEvent> _events = StreamController<RealtimeVoiceEvent>();
  final Completer<RealtimeVoiceEvent> _terminal = Completer<RealtimeVoiceEvent>();
  // ignore: no_slop_linter/prefer_specific_type, web_socket_channel exposes a dynamic stream
  late final StreamSubscription<dynamic> _subscription;
  bool _closed = false;
  bool _terminalControlSent = false;
  bool _finishRequested = false;

  this {
    _subscription = channel.stream.listen(
      _handleInbound,
      onError: _handleInboundError,
      onDone: _handleInboundDone,
    );
  }

  Stream<RealtimeVoiceEvent> get events => _events.stream;

  void sendAudio(Uint8List frame) {
    _ensureOpen();
    if (_terminalControlSent) {
      throw StateError("Realtime voice session already sent a terminal control");
    }
    if (frame.isEmpty || frame.length.isOdd || frame.length > 65536) {
      throw const RealtimeVoiceProtocolException("Realtime audio frame must be non-empty aligned PCM16 <= 65536 bytes");
    }
    channel.sink.add(frame);
  }

  Future<RealtimeVoiceEvent> finish() async {
    if (_terminal.isCompleted) {
      return await _terminal.future;
    }
    _ensureOpen();
    if (_terminalControlSent) {
      throw StateError("Realtime voice session already received a terminal control");
    }
    _finishRequested = true;
    _terminalControlSent = true;
    _sendJson(const RealtimeFinishMessage().toJson());
    return await _terminal.future;
  }

  Future<void> cancel() async {
    _ensureOpen();
    if (!_terminalControlSent) {
      _terminalControlSent = true;
      _sendJson(const RealtimeCancelMessage().toJson());
    }
    await close();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    var teardownTimedOut = false;
    final teardown = Future.wait<void>([
      () async {
        await _subscription.cancel();
      }(),
      () async {
        await channel.sink.close(realtimeNormalCloseCode);
      }(),
    ], eagerError: true).then<void>((_) {});

    try {
      await teardown.timeout(
        realtimeVoiceCloseTimeout,
        onTimeout: () {
          teardownTimedOut = true;
          logw("Realtime voice session teardown timed out");
        },
      );
    } on Object catch (error, stackTrace) {
      // Teardown is best-effort. close() is scheduled with scheduleMicrotask
      // from the inbound handlers, so rethrowing here would surface as an
      // unhandled async error, and it is also awaited from stopAndTranscribe's
      // finally, where throwing would abort the remaining cleanup.
      loge("Realtime voice session teardown failed", error, stackTrace);
    } finally {
      if (teardownTimedOut) {
        unawaited(
          teardown.catchError((Object error, StackTrace stackTrace) {
            loge("Realtime voice session teardown failed after close timeout", error, stackTrace);
          }),
        );
      }
      _closeEvents();
    }
  }

  // ignore: no_slop_linter/prefer_specific_type, JSON encoding requires Object-valued maps
  void _sendJson(Map<String, Object?> json) {
    channel.sink.add(jsonEncode(json));
  }

  // ignore: no_slop_linter/prefer_specific_type, web_socket_channel exposes arbitrary inbound frames
  void _handleInbound(Object? event) {
    if (_closed) return;

    final RealtimeVoiceEvent parsed;
    try {
      if (event is! String) {
        throw const RealtimeVoiceProtocolException("Realtime server events must be text JSON");
      }
      parsed = parseRealtimeServerEvent(jsonDecode(event));
    } on Object catch (error, stackTrace) {
      _failProtocol(error, stackTrace: stackTrace);
      return;
    }
    _events.add(parsed);
    if (parsed is RealtimeVoiceCompleteEvent || parsed is RealtimeVoiceErrorEvent) {
      _terminalControlSent = true;
      if (!_terminal.isCompleted) _terminal.complete(parsed);
      scheduleMicrotask(close);
    }
  }

  // ignore: no_slop_linter/prefer_specific_type, stream error callback receives arbitrary errors
  // ignore: no_slop_linter/prefer_required_named_parameters, stream callback signature is positional
  void _handleInboundError(Object error, StackTrace stackTrace) {
    if (_closed) return;

    _events.addError(error, stackTrace);
    if (!_terminal.isCompleted) _terminal.completeError(error, stackTrace);
    scheduleMicrotask(close);
  }

  void _handleInboundDone() {
    _closed = true;
    if (!_terminal.isCompleted && _finishRequested) {
      _terminal.completeError(const RealtimeVoiceTransportClosedException(), StackTrace.current);
    }
    _closeEvents();
  }

  // ignore: no_slop_linter/prefer_specific_type, JSON/protocol parsing may throw arbitrary errors
  void _failProtocol(Object error, {required StackTrace stackTrace}) {
    _events.addError(error, stackTrace);
    if (_terminalControlSent && !_terminal.isCompleted) _terminal.completeError(error, stackTrace);
    scheduleMicrotask(close);
  }

  void _ensureOpen() {
    if (_closed) {
      throw const RealtimeVoiceTransportClosedException();
    }
  }

  void _closeEvents() {
    if (_events.isClosed) return;
    unawaited(_events.close());
  }
}
