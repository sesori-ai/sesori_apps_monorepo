enum LegacyStorageMigrationOperation() {
  readCompletion,
  readSource,
  copyValues,
  deleteSource,
  writeCompletion,
  resetSecrets,
  clearPreferences,
  clearSource,
  markReset,
}

/// Safe presentation; retain the native/SQL/format cause and original stack for
/// diagnostics without interpolating a possibly sensitive legacy payload.
final class const LegacyStorageMigrationException({
  required final LegacyStorageMigrationOperation operation,
  required final Object innerError,
  required final StackTrace innerStackTrace,
}) implements Exception {
  @override
  String toString() => "Legacy storage migration failed during ${operation.name}";
}
