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
}

class _ThrowingSink() implements LogSink {
  @override
  void write({required LogRecord record}) => throw StateError("sink");
}

class _DiagnosticError() implements Exception {
  int renderings = 0;
  @override
  String toString() {
    renderings++;
    return "useful error /tmp/path";
  }
}
