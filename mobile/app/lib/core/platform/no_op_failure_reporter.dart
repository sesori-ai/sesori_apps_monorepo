import "package:sesori_shared/sesori_shared.dart";

class NoOpFailureReporter implements FailureReporter {
  @override
  void setGlobalKey({required String key, required Object value}) {}

  @override
  void log({required String message}) {}

  @override
  Future<void> recordFailure({
    required Object error,
    required StackTrace stackTrace,
    required String uniqueIdentifier,
    required bool fatal,
    required String? reason,
    required Iterable<Object> information,
  }) async {}
}
