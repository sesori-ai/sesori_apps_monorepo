import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

@LazySingleton(as: FailureReporter)
class CrashlyticsFailureReporter implements FailureReporter {
  final FirebaseCrashlytics _crashlytics;
  final Set<String> _reportedNonFatalIds = {};

  CrashlyticsFailureReporter(FirebaseCrashlytics crashlytics) : _crashlytics = crashlytics;

  @override
  void setGlobalKey({required String key, required Object value}) => _crashlytics.setCustomKey(key, value);

  @override
  void log({required String message}) => _crashlytics.log(message);

  @override
  Future<void> recordFailure({
    required Object error,
    required StackTrace stackTrace,
    required String uniqueIdentifier,
    required bool fatal,
    required String? reason,
    required Iterable<Object> information,
  }) async {
    if (fatal) {
      await _crashlytics.recordError(
        error,
        stackTrace,
        reason: reason,
        information: information.toList(),
        fatal: true,
      );
      return;
    }

    if (_reportedNonFatalIds.contains(uniqueIdentifier)) {
      return;
    }
    _reportedNonFatalIds.add(uniqueIdentifier);
    await _crashlytics.recordError(
      error,
      stackTrace,
      reason: reason,
      information: information.toList(),
      fatal: false,
    );
  }
}
