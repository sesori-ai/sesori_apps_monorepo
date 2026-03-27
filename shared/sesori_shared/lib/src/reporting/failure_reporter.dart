abstract interface class FailureReporter {
  /// Sets a global key-value pair for crash report context.
  void setGlobalKey({required String key, required Object value});

  /// Logs a free-form message to the crash report.
  void log({required String message});

  /// Records a handled failure with error details and context.
  Future<void> recordFailure({
    required Object error,
    required StackTrace stackTrace,
    required String uniqueIdentifier,
    required bool fatal,
    required String? reason,
    required Iterable<Object> information,
  });
}
