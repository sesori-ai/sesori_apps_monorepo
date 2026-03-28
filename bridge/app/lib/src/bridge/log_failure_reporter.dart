import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:sesori_shared/sesori_shared.dart';

/// Log-based implementation of [FailureReporter] for the bridge.
///
/// This is a minimal wrapper that logs all failures to stdout/stderr via [Log].
/// No deduplication, no persistence — just logging. The backend isn't wired yet,
/// but interface calls will flow automatically when it is.
class LogFailureReporter implements FailureReporter {
  @override
  void setGlobalKey({required String key, required Object value}) {
    Log.i('[reporter] $key=$value');
  }

  @override
  void log({required String message}) {
    Log.i('[reporter] $message');
  }

  @override
  Future<void> recordFailure({
    required Object error,
    required StackTrace stackTrace,
    required String uniqueIdentifier,
    required bool fatal,
    required String? reason,
    required Iterable<Object> information,
  }) {
    final severity = fatal ? 'FATAL' : 'non-fatal';
    Log.e(
      '[reporter:$uniqueIdentifier] $severity: $reason — $error\n$stackTrace${information.isNotEmpty ? '\nInformation: $information' : ''}',
    );
    return Future<void>.value();
  }
}
