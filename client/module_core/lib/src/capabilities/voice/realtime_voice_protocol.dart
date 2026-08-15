// ignore_for_file: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters

import "project_glossary_key.dart";

const int realtimeProtocolVersion = 1;
const int realtimeNormalCloseCode = 1000;
const int realtimePolicyCloseCode = 1008;
const int realtimeInternalCloseCode = 1011;
const int realtimeUnavailableCloseCode = 1013;

enum RealtimeCompleteReason({required final String wireName}) {
  finished(wireName: "finished"),
  sessionLimit(wireName: "session_limit"),
  quotaLimit(wireName: "quota_limit");

  static RealtimeCompleteReason parse(Object? value) {
    if (value is String) {
      for (final reason in values) {
        if (reason.wireName == value) return reason;
      }
    }
    throw const FormatException("Invalid realtime complete reason");
  }
}

enum RealtimeVoiceErrorCode({
  required final String wireName,
  required final bool retryable,
  required final int closeCode,
}) {
  invalidMessage(wireName: "invalid_message", retryable: false, closeCode: realtimePolicyCloseCode),
  unsupportedProtocol(wireName: "unsupported_protocol", retryable: false, closeCode: realtimePolicyCloseCode),
  quotaExhausted(wireName: "quota_exhausted", retryable: false, closeCode: realtimePolicyCloseCode),
  invalidAudio(wireName: "invalid_audio", retryable: false, closeCode: realtimePolicyCloseCode),
  providerRejected(wireName: "provider_rejected", retryable: false, closeCode: realtimeInternalCloseCode),
  audioTimeout(wireName: "audio_timeout", retryable: true, closeCode: realtimeInternalCloseCode),
  providerTimeout(wireName: "provider_timeout", retryable: true, closeCode: realtimeInternalCloseCode),
  internalError(wireName: "internal_error", retryable: true, closeCode: realtimeInternalCloseCode),
  startTimeout(wireName: "start_timeout", retryable: true, closeCode: realtimeUnavailableCloseCode),
  providerCapacity(wireName: "provider_capacity", retryable: true, closeCode: realtimeUnavailableCloseCode),
  providerUnavailable(wireName: "provider_unavailable", retryable: true, closeCode: realtimeUnavailableCloseCode),
  slowClient(wireName: "slow_client", retryable: true, closeCode: realtimeUnavailableCloseCode),
  serviceRestarting(wireName: "service_restarting", retryable: true, closeCode: realtimeUnavailableCloseCode);

  static RealtimeVoiceErrorCode parse(Object? value) {
    if (value is String) {
      for (final code in values) {
        if (code.wireName == value) return code;
      }
    }
    throw const FormatException("Invalid realtime error code");
  }
}

final class const RealtimeAudioFormat({required final int sampleRate}) {
  Map<String, Object?> toJson() => {"encoding": "pcm_s16le", "sampleRate": sampleRate, "channels": 1};
}

final class const RealtimeVoiceProtocolException(@override final String message) implements FormatException {
  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => "RealtimeVoiceProtocolException: $message";
}

sealed class const RealtimeClientMessage();

final class const RealtimeStartMessage({required final RealtimeAudioFormat audio, required final String? projectKey})
    extends RealtimeClientMessage {
  Map<String, Object?> toJson() => {
    "type": "start",
    "protocolVersion": realtimeProtocolVersion,
    "projectKey": projectKey,
    "audio": audio.toJson(),
  };
}

final class const RealtimeFinishMessage() extends RealtimeClientMessage {
  Map<String, Object?> toJson() => {"type": "finish"};
}

final class const RealtimeCancelMessage() extends RealtimeClientMessage {
  Map<String, Object?> toJson() => {"type": "cancel"};
}

sealed class const RealtimeVoiceEvent();

final class const RealtimeVoiceReadyEvent({
  required final int maxSessionSeconds,
  required final int dailySecondsRemaining,
}) extends RealtimeVoiceEvent;

final class const RealtimeVoiceTranscriptEvent({
  required final String confirmedDelta,
  required final String provisional,
}) extends RealtimeVoiceEvent;

final class const RealtimeVoiceCompleteEvent({
  required final RealtimeCompleteReason reason,
  required final int dailySecondsRemaining,
}) extends RealtimeVoiceEvent;

final class const RealtimeVoiceErrorEvent({required final RealtimeVoiceErrorCode code}) extends RealtimeVoiceEvent {
  bool get retryable => code.retryable;
  int get closeCode => code.closeCode;
}

RealtimeClientMessage parseRealtimeClientMessage(Object? json) {
  final map = _expectMap(json);
  return switch (map["type"]) {
    "start" => _parseStart(map),
    "finish" => _parseFinish(map),
    "cancel" => _parseCancel(map),
    _ => throw const FormatException("Unknown realtime client message type"),
  };
}

RealtimeVoiceEvent parseRealtimeServerEvent(Object? json) {
  final map = _expectMap(json);
  return switch (map["type"]) {
    "ready" => _parseReady(map),
    "transcript" => _parseTranscript(map),
    "complete" => _parseComplete(map),
    "error" => _parseError(map),
    _ => throw const FormatException("Unknown realtime server event type"),
  };
}

RealtimeStartMessage _parseStart(Map<String, Object?> map) {
  _expectKeys(map, {"type", "protocolVersion", "projectKey", "audio"});
  if (map["protocolVersion"] != realtimeProtocolVersion) {
    throw const FormatException("Unsupported realtime protocol version");
  }
  final Object? projectKey = map["projectKey"];
  final audio = _parseAudio(map["audio"]);
  if (projectKey != null && (projectKey is! String || !isValidProjectGlossaryKey(value: projectKey))) {
    throw const FormatException("Invalid realtime project key");
  }
  return switch (projectKey) {
    null => RealtimeStartMessage(audio: audio, projectKey: null),
    // ignore: prefer_final_locals, switch pattern variable cannot use final modifier in this SDK
    String key => RealtimeStartMessage(audio: audio, projectKey: key),
    _ => throw const FormatException("Invalid realtime project key"),
  };
}

RealtimeAudioFormat _parseAudio(Object? value) {
  final map = _expectMap(value);
  _expectKeys(map, {"encoding", "sampleRate", "channels"});
  if (map["encoding"] != "pcm_s16le" || map["channels"] != 1) {
    throw const FormatException("Unsupported realtime audio format");
  }
  final sampleRate = map["sampleRate"];
  if (sampleRate is! int || !const {16000, 24000, 44100, 48000}.contains(sampleRate)) {
    throw const FormatException("Unsupported realtime sample rate");
  }
  return RealtimeAudioFormat(sampleRate: sampleRate);
}

RealtimeFinishMessage _parseFinish(Map<String, Object?> map) {
  _expectKeys(map, {"type"});
  return const RealtimeFinishMessage();
}

RealtimeCancelMessage _parseCancel(Map<String, Object?> map) {
  _expectKeys(map, {"type"});
  return const RealtimeCancelMessage();
}

RealtimeVoiceReadyEvent _parseReady(Map<String, Object?> map) {
  _expectKeys(map, {"type", "protocolVersion", "maxSessionSeconds", "dailySecondsRemaining"});
  if (map["protocolVersion"] != realtimeProtocolVersion) {
    throw const FormatException("Unsupported realtime ready protocol version");
  }
  return RealtimeVoiceReadyEvent(
    maxSessionSeconds: _boundedInt(map["maxSessionSeconds"], min: 1, max: 900),
    dailySecondsRemaining: _nonnegativeInt(map["dailySecondsRemaining"]),
  );
}

RealtimeVoiceTranscriptEvent _parseTranscript(Map<String, Object?> map) {
  _expectKeys(map, {"type", "confirmedDelta", "provisional"});
  final confirmedDelta = _boundedString(map["confirmedDelta"]);
  final provisional = _boundedString(map["provisional"]);
  if (confirmedDelta.isEmpty && provisional.isEmpty) {
    throw const FormatException("Realtime transcript must carry text");
  }
  return RealtimeVoiceTranscriptEvent(confirmedDelta: confirmedDelta, provisional: provisional);
}

RealtimeVoiceCompleteEvent _parseComplete(Map<String, Object?> map) {
  _expectKeys(map, {"type", "reason", "dailySecondsRemaining"});
  return RealtimeVoiceCompleteEvent(
    reason: RealtimeCompleteReason.parse(map["reason"]),
    dailySecondsRemaining: _nonnegativeInt(map["dailySecondsRemaining"]),
  );
}

RealtimeVoiceErrorEvent _parseError(Map<String, Object?> map) {
  _expectKeys(map, {"type", "code", "retryable"});
  final code = RealtimeVoiceErrorCode.parse(map["code"]);
  if (map["retryable"] != code.retryable) {
    throw const FormatException("Realtime error retryability must match code");
  }
  return RealtimeVoiceErrorEvent(code: code);
}

Map<String, Object?> _expectMap(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException("Expected realtime JSON object");
  }
  return value;
}

void _expectKeys(Map<String, Object?> map, Set<String> keys) {
  if (map.length != keys.length || !map.keys.every(keys.contains)) {
    throw FormatException("Unexpected realtime JSON keys: ${map.keys.join(",")}");
  }
}

int _boundedInt(Object? value, {required int min, required int max}) {
  if (value is! int || value < min || value > max) {
    throw const FormatException("Realtime integer is out of bounds");
  }
  return value;
}

int _nonnegativeInt(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException("Realtime integer is out of bounds");
  }
  return value;
}

String _boundedString(Object? value) {
  if (value is! String || value.length > 32768) {
    throw const FormatException("Realtime text is out of bounds");
  }
  return value;
}
