/// Platform-agnostic secure key-value storage.
///
/// Flutter apps provide a [FlutterSecureStorage]-backed implementation;
/// CLI/TUI tools can use an OS keyring or encrypted file backend.
abstract class SecureStorage {
  /// Read a value from secure storage by key.
  Future<String?> read({required String key});

  /// Write a value to secure storage.
  Future<void> write({required String key, required String value});

  /// Delete a value from secure storage.
  Future<void> delete({required String key});
}
