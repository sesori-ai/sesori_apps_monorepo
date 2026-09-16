import "log_record.dart";

/// Per-isolate diagnostic output. File implementations own their async failures.
abstract interface class LogSink() {
  void write({required LogRecord record});

  /// Completes writes admitted before this call; callers own their wait budget.
  Future<void> flush();
}
