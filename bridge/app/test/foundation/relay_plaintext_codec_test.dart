import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/foundation/relay_plaintext_codec.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("encodeRelayPlaintext", () {
    final json = utf8.encode(jsonEncode({"type": "response", "body": "repeated " * 200}));

    test("returns the JSON bytes unchanged when not deflating", () {
      expect(encodeRelayPlaintext(json: json, deflate: false), same(json));
    });

    test("prefixes the marker and inflates back to exactly the JSON", () {
      final plaintext = encodeRelayPlaintext(json: json, deflate: true);

      expect(plaintext.first, RelayProtocol.deflatedPlaintextMarker);
      expect(plaintext.length, lessThan(json.length));
      expect(ZLibDecoder(raw: true).convert(plaintext.sublist(1)), json);
    });
  });
}
