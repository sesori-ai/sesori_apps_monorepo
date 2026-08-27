import "dart:convert";
import "dart:io";
import "dart:math";
import "dart:typed_data";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "restricted_file_writer.dart";

abstract interface class BridgeIdentitySecretStorage() {
  Future<Uint8List> getOrCreate();
}

/// Persists bridge-local HMAC key material with owner-only permissions.
class FileBridgeIdentitySecretStorage({
  required String dataDirectory,
  required final RestrictedFileWriter _writeRestrictedFile,
}) implements BridgeIdentitySecretStorage {
  static const int secretLength = 32;
  static const String _fileName = "bridge_identity_secret_v1";

  final String _path = p.join(dataDirectory, _fileName);

  @override
  Future<Uint8List> getOrCreate() async {
    final file = File(_path);
    if (file.existsSync()) {
      try {
        return _decode((await file.readAsString()).trim());
      } on Object catch (error, stackTrace) {
        // Corrupt key material cannot recover its previous glossary namespace.
        // Replace it so the optional feature self-heals without blocking the bridge.
        Log.w("Replacing invalid bridge identity secret", error, stackTrace);
      }
    }
    return await _create();
  }

  Uint8List _decode(String encoded) {
    final paddingLength = (4 - encoded.length % 4) % 4;
    final padded = encoded.padRight(encoded.length + paddingLength, "=");
    final bytes = base64Url.decode(padded);
    if (bytes.length != secretLength) {
      throw const FormatException("Bridge identity secret has an invalid length");
    }
    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> _create() async {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(secretLength, (_) => random.nextInt(256), growable: false),
    );
    await _writeRestrictedFile(
      filePath: _path,
      contents: base64UrlEncode(bytes).replaceAll("=", ""),
    );
    return bytes;
  }
}
