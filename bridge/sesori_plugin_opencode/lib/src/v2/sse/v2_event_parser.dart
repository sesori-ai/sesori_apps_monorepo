import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../models/v2_decode_exception.dart";
import "../models/v2_event.g.dart";

/// Parses data frames from `/api/event`. Heartbeat comments are consumed by
/// SseConnection; unknown or malformed frames are observable drops, not fatal
/// stream failures. Raw prompts/transcripts are never included in log text.
class const V2EventParser() {
  V2EventEnvelope? parse({required String rawData}) {
    try {
      final json = jsonDecodeMap(rawData);
      final type = json["type"];
      // OpenCode emits many registry/catalog events the bridge does not use.
      if (type is String && !V2EventData.knownTypes.contains(type)) {
        Log.d("[opencode-v2] ignoring unsupported SSE event type: $type");
        return null;
      }
      return V2EventEnvelope.fromJson(json);
    } on Object catch (error, stackTrace) {
      Log.w(
        "[opencode-v2] dropping malformed or unsupported SSE event",
        V2DecodeException(operation: "SSE event", innerError: error),
        stackTrace,
      );
      return null;
    }
  }
}
