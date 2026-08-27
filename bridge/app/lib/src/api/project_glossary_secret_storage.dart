import "dart:io";

import "package:path/path.dart" as p;

import "../auth/restricted_file_writer.dart";

/// Reads and writes bridge-local glossary HMAC material with owner-only
/// permissions. Creation, validation, and caching policy belong to Layer 2.
class FileProjectGlossarySecretStorage({
  required String dataDirectory,
  required final RestrictedFileWriter _writeRestrictedFile,
}) {
  static const String _fileName = "project_glossary_secret_v1";

  final String _path = p.join(dataDirectory, _fileName);

  Future<String?> read() async {
    final file = File(_path);
    if (!file.existsSync()) return null;
    return await file.readAsString();
  }

  Future<void> write({required String encodedSecret}) => _writeRestrictedFile(
    filePath: _path,
    contents: encodedSecret,
  );
}
