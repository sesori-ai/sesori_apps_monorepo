import "dart:async";

import "package:sesori_shared/sesori_shared.dart" show StringExtensions;

import "log_record.dart";
import "log_sink.dart";

/// Preserves the existing console presentation and zone-based log capture.
class const StdoutLogSink() implements LogSink {
  // This sink owns no asynchronous write queue.
  @override
  Future<void> flush() => Future<void>.value();

  @override
  void write({required LogRecord record}) {
    if (record.diagnosticError case final error?) {
      Zone.current.print("${record.message}: $error");
    } else {
      record.message.chunked(chunkSize: 800).forEach(Zone.current.print);
    }
    if (record.stackTrace case final stack?) {
      Zone.current.print(stack.toString());
    }
  }
}
