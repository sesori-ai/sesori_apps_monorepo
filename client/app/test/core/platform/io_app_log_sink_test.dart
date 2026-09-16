import "dart:async";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/io_app_log_sink.dart";

void main() {
  late Directory root;
  late TemporaryDirectoryClient directory;
  late List<String> failures;
  late int lookups;
  setUp(() {
    root = Directory.systemTemp.createTempSync("sesori_mobile_logs_");
    failures = [];
    lookups = 0;
    directory = TemporaryDirectoryClient(
      provider: _DirectoryProvider(
        load: () async {
          lookups++;
          return root;
        },
      ),
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  IoAppLogSink createSink({required int cap}) => IoAppLogSink.forTesting(
    directoryClient: directory,
    maxFileBytes: cap,
    reportFailure: failures.add,
  );

  test("production sink lazily uses the temporary directory and preserves diagnostics", () async {
    final sink = IoAppLogSink(directoryClient: directory);
    expect(lookups, 0);
    final lines = <String>[];
    await runZoned(
      () async {
        sink.write(
          record: LogRecord(
            level: LogLevel.warning,
            timestamp: DateTime.utc(2026),
            message: "context",
            diagnosticError: "disk /tmp/repo",
            stackTrace: StackTrace.fromString("stack"),
          ),
        );
        await sink.flush();
      },
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)),
    );
    expect(lines, ["context: disk /tmp/repo", "stack"]);
    expect(
      File("${root.path}/logs/app.log").readAsStringSync(),
      contains("[WARNING] context: disk /tmp/repo\nstack\n"),
    );
    expect(lookups, 1);
  });

  test("serializes append and restart rotation with a single bounded predecessor", () async {
    final sink = createSink(cap: 64);
    for (final message in ["first", "second", "third"]) {
      sink.write(record: _record(message: message));
    }
    await sink.flush();
    expect(File("${root.path}/logs/app.log").readAsStringSync(), endsWith("third\n"));
    expect(File("${root.path}/logs/app.log.1").readAsStringSync(), endsWith("second\n"));
    final restarted = createSink(cap: 64);
    restarted.write(record: _record(message: "fourth"));
    await restarted.flush();
    expect(File("${root.path}/logs/app.log.1").readAsStringSync(), endsWith("third\n"));
    expect(File("${root.path}/logs/app.log").lengthSync(), lessThanOrEqualTo(64));
    expect(Directory("${root.path}/logs").listSync(), hasLength(2));
    expect(lookups, 1);
  });

  test("caps oversized records without cutting a UTF-8 scalar", () async {
    final sink = createSink(cap: 8);
    sink.write(record: _record(message: "prefix🙂🙂"));
    await sink.flush();
    expect(File("${root.path}/logs/app.log").readAsStringSync(), "🙂\n");
  });

  test("file failures report once per episode and resume after recovery", () async {
    final blocker = File("${root.path}/logs")..writeAsStringSync("blocked");
    final sink = createSink(cap: 1024);
    sink.write(record: _record(message: "first"));
    sink.write(record: _record(message: "second"));
    await sink.flush();
    expect(failures, hasLength(1));
    expect(failures.single, contains(root.path));
    blocker.deleteSync();
    sink.write(record: _record(message: "recovered"));
    await sink.flush();
    expect(File("${root.path}/logs/app.log").readAsStringSync(), endsWith("recovered\n"));
    Directory(blocker.path).deleteSync(recursive: true);
    blocker.writeAsStringSync("blocked again");
    sink.write(record: _record(message: "later failure"));
    sink.write(record: _record(message: "same episode"));
    await sink.flush();
    expect(failures, hasLength(2));
  });

  test("flush waits for admitted records through pending directory resolution", () async {
    final pending = Completer<Directory>();
    directory = TemporaryDirectoryClient(provider: _DirectoryProvider(load: () => pending.future));
    final sink = createSink(cap: 1024);
    final records = [_record(message: "earlier"), _record(message: "final cleanup")];
    for (final record in records) {
      sink.write(record: record);
    }
    var completed = false;
    final flushing = sink.flush().then((_) => completed = true);
    await Future<void>.value();
    expect(completed, isFalse);
    pending.complete(root);
    await flushing;
    expect(File("${root.path}/logs/app.log").readAsLinesSync(), records.map((record) => record.formatted));
    expect(failures, isEmpty);
  });

  test("cache eviction is recreated on the next append", () async {
    final sink = createSink(cap: 1024);
    sink.write(record: _record(message: "before eviction"));
    await sink.flush();
    Directory("${root.path}/logs").deleteSync(recursive: true);
    sink.write(record: _record(message: "after eviction"));
    await sink.flush();
    expect(File("${root.path}/logs/app.log").readAsLinesSync(), [_record(message: "after eviction").formatted]);
    expect(failures, isEmpty);
    expect(lookups, 1);
  });

  test("path-provider failure never escapes logging callers", () async {
    directory = TemporaryDirectoryClient(
      provider: _DirectoryProvider(load: () async => throw const FileSystemException("lookup unavailable")),
    );
    final sink = createSink(cap: 1024);
    expect(() => sink.write(record: _record(message: "original")), returnsNormally);
    await sink.flush();
    expect(failures.single, contains("lookup unavailable"));
  });
}

class _DirectoryProvider({required final Future<Directory> Function() load}) implements TemporaryDirectoryProvider {
  @override
  Future<Directory> temporaryDirectory() => load();
}

LogRecord _record({required String message}) => LogRecord(
  level: LogLevel.info,
  timestamp: DateTime.utc(2026),
  message: message,
  diagnosticError: null,
  stackTrace: null,
);
