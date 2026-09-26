/// Temporary access to the old mobile keyspace, never a runtime fallback.
abstract interface class LegacyNativeStorage() {
  /// Returns the complete snapshot, or throws on native/decryption failure.
  /// Keys are an open native inventory; successful import retains unknown entries.
  Future<Map<String, String>> readAll();

  Future<void> delete({required String key});

  /// Destructive failed-import recovery of this app's old namespace only.
  Future<void> clear();
}
