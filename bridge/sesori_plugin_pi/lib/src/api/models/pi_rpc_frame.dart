import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../models/pi_rpc_command.dart";
import "pi_event.dart";
import "pi_extension_ui_request.dart";
import "pi_frame_fields.dart";

/// One decoded line of Pi's JSONL RPC stdout.
///
/// Pi has no handshake and no protocol version, so the transport must absorb
/// anything it does not recognize: every unrouted shape becomes
/// [PiUnknownFrame] instead of an error, and the process keeps running.
///
/// The raw frame is retained on every variant so later steps can reach payload
/// fields this build does not model. It is never logged.
sealed class PiRpcFrame {
  const PiRpcFrame({required this.raw});

  final Map<String, Object?> raw;

  /// Routes one decoded stdout object.
  ///
  /// Never throws and never returns null.
  static PiRpcFrame parse({required Map<String, Object?> json}) {
    final type = stringOrNull(json["type"]);
    switch (type) {
      case "response":
        // `command` is Pi's own echo of what failed and is the only clue on a
        // parse failure, which carries no request ID at all.
        final rawCommand = stringOrNull(json["command"]);
        final command = PiRpcCommand.tryParse(value: rawCommand);
        if (rawCommand != null && rawCommand != "parse" && command == null) {
          Log.w("[pi] received a response for an unknown command type");
        }
        final id = stringOrNull(json["id"]);
        return boolOrFalse(json["success"])
            ? PiSuccessResponseFrame(
                id: id,
                command: command,
                rawCommand: rawCommand,
                data: mapOrEmpty(json["data"]),
                raw: json,
              )
            : PiFailureResponseFrame(
                id: id,
                command: command,
                rawCommand: rawCommand,
                error: stringOrNull(json["error"]),
                raw: json,
              );
      case "extension_ui_request":
        final request = PiExtensionUiRequest.parse(json: json);
        return request == null
            ? PiUnknownFrame(type: type, raw: json)
            : PiExtensionUiFrame(request: request, raw: json);
      case null:
        return PiUnknownFrame(type: null, raw: json);
      default:
        return PiEventFrame(
          event: PiEvent.parse(type: type, json: json),
          raw: json,
        );
    }
  }
}

/// A response correlated to one command by [id].
sealed class PiResponseFrame extends PiRpcFrame {
  const PiResponseFrame({required this.id, required this.command, required this.rawCommand, required super.raw});

  /// The request ID this answers, or null when Pi could not read one — which
  /// happens for its `parse` failures.
  final String? id;

  /// The command Pi believes it answered when it belongs to the integration's
  /// closed command set.
  final PiRpcCommand? command;

  /// Pi's untyped command echo. This also preserves `parse` and future commands.
  final String? rawCommand;
}

/// A command Pi accepted. For `prompt`, acceptance is not completion: the
/// agent's own events may arrive before or after this frame.
final class PiSuccessResponseFrame extends PiResponseFrame {
  const PiSuccessResponseFrame({
    required super.id,
    required super.command,
    required super.rawCommand,
    required this.data,
    required super.raw,
  });

  /// The command's payload, empty for commands that answer with no data.
  final Map<String, Object?> data;
}

/// A command Pi rejected. Pi's error strings are untyped prose; classification
/// belongs to the repository layer, not the transport.
final class PiFailureResponseFrame extends PiResponseFrame {
  const PiFailureResponseFrame({
    required super.id,
    required super.command,
    required super.rawCommand,
    required this.error,
    required super.raw,
  });

  final String? error;
}

/// An agent event. Never correlated to a request.
final class PiEventFrame extends PiRpcFrame {
  const PiEventFrame({required this.event, required super.raw});

  final PiEvent event;
}

/// An extension dialog or decoration request.
final class PiExtensionUiFrame extends PiRpcFrame {
  const PiExtensionUiFrame({required this.request, required super.raw});

  final PiExtensionUiRequest request;
}

/// A frame with no `type`, or one this build does not model.
final class PiUnknownFrame extends PiRpcFrame {
  const PiUnknownFrame({required this.type, required super.raw});

  final String? type;
}
