import "../keys/secret_storage_key.dart";

/// Platform-provided persistence for secret values, with no caller-selected
/// encryption flag or plaintext-key overload.
///
/// Null means absence; backend/unlock failures must remain failed futures.
abstract interface class SecureStorage() {
  Future<String?> read({required SecretStorageKey key});

  Future<void> write({required SecretStorageKey key, required String value});

  Future<void> delete({required SecretStorageKey key});
}
