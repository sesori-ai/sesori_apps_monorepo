import "dart:io";
import "dart:typed_data";

import "package:sesori_shared/sesori_shared.dart" show RelayProtocol;

/// Builds the plaintext that is encrypted into one relay frame.
///
/// Returns [json] unchanged when [deflate] is false. Otherwise returns
/// [RelayProtocol.deflatedPlaintextMarker] followed by a raw deflate stream
/// of [json].
List<int> encodeRelayPlaintext({required List<int> json, required bool deflate}) {
  if (!deflate) return json;
  final deflated = ZLibEncoder(raw: true).convert(json);
  return Uint8List(1 + deflated.length)
    ..[0] = RelayProtocol.deflatedPlaintextMarker
    ..setRange(1, 1 + deflated.length, deflated);
}
