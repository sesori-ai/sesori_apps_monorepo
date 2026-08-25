import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../di/firebase_register_module.dart";

/// The [FailureReporter] for builds with no Firebase SDK (web, Linux, Windows,
/// Android profile). There is no crash reporter to forward to, so every member
/// discards its input.
@firebaseDisabledEnvironment
@LazySingleton(as: FailureReporter)
class NoOpFailureReporter() implements FailureReporter {
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
