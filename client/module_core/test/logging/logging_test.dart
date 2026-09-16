import "dart:async";

import "package:sesori_dart_core/logging.dart";
import "package:test/test.dart";

void main() {
  final originalLevel = logLevel;
  tearDown(() {
    setLogLevel(originalLevel);
    setLogSink(sink: const StdoutLogSink());
  });

  for (final level in LogLevel.values) {
    test("filters records at $level", () {
      final sink = _RecordingSink();
      setLogSink(sink: sink);
      setLogLevel(level);
      logt("trace");
      logd("debug");
      logi("info");
      logw("warning");
      loge("error");
      expect(sink.records.map((r) => r.level), LogLevel.values.take(5).where((l) => l.index >= level.index));
      expect(sink.records.every((r) => r.timestamp.isUtc), isTrue);
    });
  }

  test("converts supplied diagnostics only after filtering, including debug", () {
    final sink = _RecordingSink();
    final error = _DiagnosticError();
    final stack = StackTrace.fromString("useful stack");
    setLogSink(sink: sink);
    setLogLevel(LogLevel.warning);
    logd("hidden", error, stack);
    expect(error.renderings, 0);
    setLogLevel(LogLevel.debug);
    logd("visible", error, stack);
    expect(error.renderings, 1);
    expect(sink.records.single.diagnosticError, "useful error /tmp/path");
    expect(sink.records.single.stackTrace, same(stack));
    expect(sink.records.single.formatted, contains("[DEBUG] visible: useful error /tmp/path\nuseful stack"));
  });

  test("stdout retains chunking and error/stack details", () {
    final lines = <String>[];
    setLogLevel(LogLevel.debug);
    setLogSink(sink: const StdoutLogSink());
    runZoned(
      () {
        logi("x" * 1701);
        logd("context", StateError("disk"), StackTrace.fromString("stack"));
      },
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)),
    );
    expect(lines.take(3).map((l) => l.length), [800, 800, 101]);
    expect(lines[3], "context: Bad state: disk");
    expect(lines.last, "stack");
  });

  test("flush awaits admitted output", () async {
    final sink = _PendingSink();
    setLogSink(sink: sink);
    var completed = false;
    final flushing = flushLogs(timeout: const Duration(seconds: 1)).then((_) => completed = true);
    await Future<void>.value();
    expect(completed, isFalse);
    sink.pending.complete();
    await flushing;
    expect(completed, isTrue);
  });

  for (final timeout in [false, true]) {
    test("flush failure stays bounded and bypasses the sink (timeout=$timeout)", () async {
      final pending = _PendingSink();
      setLogSink(sink: timeout ? pending : _ThrowingSink());
      final lines = <String>[];
      await runZoned(
        () => flushLogs(timeout: const Duration(milliseconds: 1)),
        zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)),
      );
      pending.pending.complete();
      expect(lines.join("\n"), contains("Log sink flush failed; pending diagnostics may be lost"));
      expect(lines.join("\n"), contains(timeout ? "TimeoutException" : "Bad state: flush"));
    });
  }

  test("a throwing sink cannot throw into the caller or suppress the record", () {
    final lines = <String>[];
    setLogLevel(LogLevel.info);
    setLogSink(sink: _ThrowingSink());
    runZoned(
      () => expect(() => loge("original record"), returnsNormally),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)),
    );
    expect(lines.first, "original record");
    expect(lines.join("\n"), contains("Log sink failed; using console output: Bad state: sink"));
  });
}

class _RecordingSink() implements LogSink {
  final records = <LogRecord>[];
  @override
  void write({required LogRecord record}) => records.add(record);
  @override
  Future<void> flush() => Future<void>.value();
}

class _PendingSink() extends _RecordingSink {
  final pending = Completer<void>();
  @override
  Future<void> flush() => pending.future;
}

class _ThrowingSink() implements LogSink {
  @override
  void write({required LogRecord record}) => throw StateError("sink");
  @override
  Future<void> flush() => Future<void>.error(StateError("flush"));
}

class _DiagnosticError() implements Exception {
  int renderings = 0;
  @override
  String toString() {
    renderings++;
    return "useful error /tmp/path";
  }
}
