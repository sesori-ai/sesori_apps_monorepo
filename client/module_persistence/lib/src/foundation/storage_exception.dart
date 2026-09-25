/// Operations whose underlying exceptions may carry protected payload bytes.
enum StorageOperation() {
  readMasterKey,
  writeMasterKey,
  decodeMasterKey,
  encryptValue,
  decryptValue,
}

/// Retains the original diagnostic cause without rendering key/value payloads.
class const StorageException({
  required final StorageOperation operation,
  required final Object innerError,
}) implements Exception {
  @override
  String toString() => "Client storage failed during ${operation.name}";
}

/// Encrypted data cannot be recovered by silently generating a different key.
class const MasterKeyMissingException() implements Exception {
  @override
  String toString() => "The client master key is missing while encrypted values exist; existing data was not replaced";
}
