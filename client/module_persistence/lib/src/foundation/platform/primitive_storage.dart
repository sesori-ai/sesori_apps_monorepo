/// Platform-provided I/O for non-secret primitive values.
///
/// Domain callers use PersisterRepository and typed keys instead of this raw
/// capability. Null means absence; failures must remain failed futures.
abstract interface class PrimitiveStorage() {
  Future<String?> readString({required String key});

  Future<void> writeString({required String key, required String value});

  Future<void> deleteString({required String key});

  Future<bool?> readBool({required String key});

  Future<void> writeBool({required String key, required bool value});

  Future<void> deleteBool({required String key});
}
