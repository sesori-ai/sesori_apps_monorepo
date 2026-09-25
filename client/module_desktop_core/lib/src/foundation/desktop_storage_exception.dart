/// Operations whose underlying exceptions may carry protected payload bytes.
enum DesktopStorageOperation() {
  readMasterKey,
  writeMasterKey,
  decodeMasterKey,
  encryptValue,
  decryptValue,
}

/// Retains the original diagnostic cause without rendering key/value payloads.
class const DesktopStorageException({
  required final DesktopStorageOperation operation,
  required final Object innerError,
}) implements Exception {
  @override
  String toString() => "Desktop storage failed during ${operation.name}";
}

/// Encrypted data cannot be recovered by silently generating a different key.
class const DesktopMasterKeyMissingException() implements Exception {
  @override
  String toString() => "The desktop master key is missing while encrypted values exist; existing data was not replaced";
}
