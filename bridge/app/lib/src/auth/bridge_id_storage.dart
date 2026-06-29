import "dart:io";

/// File-backed persistence for the bridge id assigned by the auth server's
/// `/auth/bridges` endpoint.
///
/// The bridge id lives in its own plain-text file (one trimmed string, no
/// JSON) rather than inside the token file, so it survives in supervised mode
/// where the GUI supplies tokens over the control channel and no token file
/// exists on disk.
class BridgeIdStorage {
  final String _path;

  BridgeIdStorage({required String filePath}) : _path = filePath;

  /// Returns the persisted bridge id, or null when no id has been stored yet
  /// (missing file) or the file is empty.
  Future<String?> read() async {
    if (!File(_path).existsSync()) {
      return null;
    }
    final contents = (await File(_path).readAsString()).trim();
    return contents.isEmpty ? null : contents;
  }

  /// Persists [bridgeId], creating the data directory (0700) and the file
  /// (0600) with restricted permissions on Unix, mirroring the token file.
  Future<void> write({required String bridgeId}) async {
    final dir = Directory(_path).parent;

    await dir.create(recursive: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['700', dir.path]);
    }

    await File(_path).writeAsString(bridgeId);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', _path]);
    }
  }

  /// Deletes the bridge id file. Does nothing when the file is absent.
  Future<void> clear() async {
    final file = File(_path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
