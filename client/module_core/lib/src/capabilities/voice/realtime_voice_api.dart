import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "realtime_voice_protocol.dart";
import "realtime_websocket_connector.dart";

final class const RealtimeVoiceAuthenticationException() implements Exception;

final class const RealtimeVoiceTransportClosedException() implements Exception;

const realtimeVoiceConnectTimeout = Duration(seconds: 10);

@lazySingleton
class RealtimeVoiceApi({
  required final RealtimeWebSocketConnector connector,
  required final AuthTokenProvider tokenProvider,
}) {
  Future<RealtimeVoiceSession> start({required RealtimeAudioFormat audio, required String? projectKey}) async {
    final token = await tokenProvider.getFreshAccessToken();
    if (token == null) {
      throw const RealtimeVoiceAuthenticationException();
    }
    final channel = connector.connect(
      Uri.parse(authBaseUrl).replace(scheme: "wss", path: "/voice/realtime", query: null),
      headers: {"Authorization": "Bearer $token"},
      connectTimeout: realtimeVoiceConnectTimeout,
    );
    try {
      await channel.ready;
    } on Object {
      await channel.sink.close(realtimeNormalCloseCode);
      rethrow;
    }
    final session = RealtimeVoiceSession(channel);
    session._initialize();
    session._sendJson(RealtimeStartMessage(audio: audio, projectKey: projectKey).toJson());
    return session;
  }
}

final class RealtimeVoiceSession(final WebSocketChannel _channel) {
  final StreamController<RealtimeVoiceEvent> _events = StreamController<RealtimeVoiceEvent>.broadcast();
  final Completer<RealtimeVoiceEvent> _terminal = Completer<RealtimeVoiceEvent>();
  // ignore: no_slop_linter/prefer_specific_type, web_socket_channel exposes a dynamic stream
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;
  bool _terminalControlSent = false;
  bool _finishRequested = false;

  Stream<RealtimeVoiceEvent> get events => _events.stream;

  void _initialize() {
    _subscription ??= _channel.stream.listen(
      _handleInbound,
      onError: _handleInboundError,
      onDone: _handleInboundDone,
    );
  }

  void sendAudio(Uint8List frame) {
    _ensureOpen();
    if (_terminalControlSent) {
      throw StateError("Realtime voice session already sent a terminal control");
    }
    if (frame.isEmpty || frame.length.isOdd || frame.length > 65536) {
      throw const RealtimeVoiceProtocolException("Realtime audio frame must be non-empty aligned PCM16 <= 65536 bytes");
    }
    _channel.sink.add(frame);
  }

  Future<RealtimeVoiceEvent> finish() async {
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
    await _subscription?.cancel();
    await _channel.sink.close(realtimeNormalCloseCode);
    await _events.close();
  }

  // ignore: no_slop_linter/prefer_specific_type, JSON encoding requires Object-valued maps
  void _sendJson(Map<String, Object?> json) {
    _channel.sink.add(jsonEncode(json));
  }

  // ignore: no_slop_linter/prefer_specific_type, web_socket_channel exposes arbitrary inbound frames
  void _handleInbound(Object? event) {
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
    _events.addError(error, stackTrace);
    if (!_terminal.isCompleted) _terminal.completeError(error, stackTrace);
    scheduleMicrotask(close);
  }

  void _handleInboundDone() {
    _closed = true;
    if (!_terminal.isCompleted && _finishRequested) {
      _terminal.completeError(const RealtimeVoiceTransportClosedException(), StackTrace.current);
    }
    unawaited(_events.close());
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
}
