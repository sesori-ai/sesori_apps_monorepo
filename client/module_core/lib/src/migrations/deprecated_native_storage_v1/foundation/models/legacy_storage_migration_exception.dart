import "dart:async";

import "package:sesori_persistence/sesori_persistence.dart";

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

/// Local diagnostics retain underlying failures, but never a format parser's
/// source buffer, which may contain a legacy value or encoded master key.
final class const LegacyStorageMigrationException({
  required final LegacyStorageMigrationOperation operation,
  required final Object innerError,
  required final StackTrace innerStackTrace,
}) implements Exception {
  @override
  String toString() =>
      "Legacy storage migration failed during ${operation.name}: ${_diagnosticCause(error: innerError)}";

  static String _diagnosticCause({required Object error}) => switch (error) {
    FormatException(:final message, :final offset) =>
      "FormatException: $message${offset == null ? '' : ' (at offset $offset)'}",
    StorageException(:final innerError) => "${error.toString()}: ${_diagnosticCause(error: innerError)}",
    ParallelWaitError<Record, (AsyncError?, AsyncError?)>(:final errors) => [
      for (final (operation, failure) in [("ciphertext reset", errors.$1), ("master replacement", errors.$2)])
        if (failure != null) "$operation: ${_diagnosticCause(error: failure.error)}\n${failure.stackTrace.toString()}",
    ].join("\n"),
    _ => error.toString(),
  };
}
