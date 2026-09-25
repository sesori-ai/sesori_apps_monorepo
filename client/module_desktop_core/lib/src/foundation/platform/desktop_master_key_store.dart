/// Native storage of the single master item for the shell-selected scope.
/// Implementations only perform OS credential I/O; they own no unlock cache,
/// key-generation policy, database access or arbitrary-value persistence.
abstract class DesktopMasterKeyStore() {
  Future<String?> read();

  Future<void> write({required String value});
}
