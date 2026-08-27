import "dart:convert";
import "dart:io";
import "dart:math";
import "dart:typed_data";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../auth/restricted_file_writer.dart";

abstract interface class ProjectGlossarySecretStorage() {
  Future<Uint8List> getOrCreate();
}

/// Lazily persists bridge-local glossary HMAC material with owner-only
/// permissions. No file is touched until the glossary service is requested.
class FileProjectGlossarySecretStorage({
  required String dataDirectory,
  required final RestrictedFileWriter _writeRestrictedFile,
}) implements ProjectGlossarySecretStorage {
  static const int secretLength = 32;
  static const String _fileName = "project_glossary_secret_v1";

  final String _path = p.join(dataDirectory, _fileName);
  Uint8List? _cached;
  Future<Uint8List>? _pending;

  @override
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
    final file = File(_path);
    if (file.existsSync()) {
      try {
        return _decode((await file.readAsString()).trim());
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
    await _writeRestrictedFile(
      filePath: _path,
      contents: base64UrlEncode(bytes).replaceAll("=", ""),
    );
    return bytes;
  }
}
