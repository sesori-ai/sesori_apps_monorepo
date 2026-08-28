import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/control_channel_server.dart";

/// Layer-1 typed write boundary over the GUI-hosted control channel.
///
/// Outbound callers provide protocol messages; this API owns their wire
/// serialization and delegates only the encoded frame to the Layer-0 server.
@lazySingleton
class ControlChannelApi({required final ControlChannelServer _server}) {
  void send({required ControlMessage message}) {
    _server.send(jsonEncode(message.toJson()));
  }
}
