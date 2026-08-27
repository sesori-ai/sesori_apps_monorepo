import "dart:convert";
import "dart:math";
import "dart:typed_data";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../api/project_glossary_secret_storage.dart";

/// Owns creation, validation, caching, and replacement policy for the
/// bridge-local HMAC secret used to namespace project glossary keys.
class ProjectGlossaryKeyMaterialRepository({
  required final FileProjectGlossarySecretStorage _storage,
}) {
  static const int secretLength = 32;

  Uint8List? _cached;
  Future<Uint8List>? _pending;

  Future<Uint8List> getOrCreate() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    final pending = _pending;
    if (pending != null) return pending;

    late final Future<Uint8List> operation;
    operation = _loadOrCreate()
        .then((secret) {
          _cached = secret;
          return secret;
        })
        .whenComplete(() {
          if (identical(_pending, operation)) _pending = null;
        });
    _pending = operation;
    return operation;
  }

  Future<Uint8List> _loadOrCreate() async {
    final encoded = await _storage.read();
    if (encoded != null) {
      try {
        return _decode(encoded.trim());
      } on Object catch (error, stackTrace) {
        // Corrupt material cannot recover its old namespace. Replace it so the
        // optional feature self-heals without blocking ordinary bridge flows.
        Log.w("Replacing invalid project glossary secret", error, stackTrace);
      }
    }
    return await _create();
  }

  Uint8List _decode(String encoded) {
    final paddingLength = (4 - encoded.length % 4) % 4;
    final padded = encoded.padRight(encoded.length + paddingLength, "=");
    final bytes = base64Url.decode(padded);
    if (bytes.length != secretLength) {
      throw const FormatException("Project glossary secret has an invalid length");
    }
    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> _create() async {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(secretLength, (_) => random.nextInt(256), growable: false),
    );
    await _storage.write(encodedSecret: base64UrlEncode(bytes).replaceAll("=", ""));
    return bytes;
  }
}
