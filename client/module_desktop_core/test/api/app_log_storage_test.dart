import "dart:async";
import "dart:io";

import "package:sesori_dart_core/logging.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_desktop_core/src/api/app_log_storage.dart";
import "package:sesori_desktop_core/src/api/rotating_file_storage.dart";
import "package:test/test.dart";

void main() {
  late Directory root;
  late _DirectorySource directory;
  late List<String> failures;
  setUp(() {
    root = Directory.systemTemp.createTempSync("sesori_app_logs_");
    directory = _DirectorySource(root: root);
    failures = [];
  });
  tearDown(() => root.deleteSync(recursive: true));

  AppLogStorage createSink({required int cap}) => AppLogStorage.forTesting(
    applicationSupportDirectory: directory,
    storage: RotatingFileStorage.forTesting(
      fileName: "app.log",
      maxFileBytes: cap,
      isWindows: true,
      setPermissions: ({required path, required mode}) async {},
    ),
    reportFailure: failures.add,
  );

  test("construction is lazy; writes preserve console, metadata and context", () async {
    final sink = createSink(cap: 1024);
    expect(directory.calls, 0);
    final console = <String>[];
    await runZoned(
      () async {
        sink.write(
          record: _record(message: "context", error: "disk /tmp/repo", stack: StackTrace.fromString("stack")),
        );
        await sink.flush();
      },
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => console.add(line)),
    );
    expect(console, ["context: disk /tmp/repo", "stack"]);
    expect(File("${root.path}/logs/app.log").readAsStringSync(), contains("[INFO] context: disk /tmp/repo\nstack\n"));
    expect(failures, isEmpty);
  });

  test("orders writes, rotates one predecessor, appends on restart and isolates bridge output", () async {
    final bridge = BridgeProcessLogStorage.forTesting(
      applicationSupportDirectory: directory,
      maxFileBytes: 64,
      isWindows: true,
      setPermissions: ({required path, required mode}) async {},
    );
    await bridge.appendLine(line: "helper");
    final sink = createSink(cap: 64);
    for (final message in ["first", "second", "third"]) {
      sink.write(record: _record(message: message, error: null, stack: null));
    }
    await sink.flush();
    expect(File("${root.path}/logs/app.log").readAsStringSync(), endsWith("third\n"));
    expect(File("${root.path}/logs/app.log.1").readAsStringSync(), endsWith("second\n"));
    final restarted = createSink(cap: 64);
    restarted.write(record: _record(message: "fourth", error: null, stack: null));
    await restarted.flush();
    expect(File("${root.path}/logs/app.log.1").readAsStringSync(), endsWith("third\n"));
    expect(File("${root.path}/logs/app.log").lengthSync(), lessThanOrEqualTo(64));
    expect(File(await bridge.logFilePath).readAsStringSync(), "helper\n");
  });

  test("oversized records retain complete UTF-8 scalars within the cap", () async {
    final sink = createSink(cap: 8);
    sink.write(record: _record(message: "prefix🙂🙂", error: null, stack: null));
    await sink.flush();
    expect(File("${root.path}/logs/app.log").readAsStringSync(), "🙂\n");
  });

  test("file failures report once per episode and resume after recovery", () async {
    final blocker = File("${root.path}/logs")..writeAsStringSync("blocked");
    final sink = createSink(cap: 1024);
    sink.write(record: _record(message: "first", error: null, stack: null));
    sink.write(record: _record(message: "second", error: null, stack: null));
    await sink.flush();
    expect(failures, hasLength(1));
    expect(failures.single, contains(root.path));
    blocker.deleteSync();
    sink.write(record: _record(message: "recovered", error: null, stack: null));
    await sink.flush();
    expect(File("${root.path}/logs/app.log").readAsStringSync(), endsWith("recovered\n"));
    Directory(blocker.path).deleteSync(recursive: true);
    blocker.writeAsStringSync("blocked again");
    sink.write(record: _record(message: "later failure", error: null, stack: null));
    sink.write(record: _record(message: "same episode", error: null, stack: null));
    await sink.flush();
    expect(failures, hasLength(2));
  });

  test("flush waits for admitted records through pending directory resolution", () async {
    final pending = Completer<Directory>();
    directory.pending = pending.future;
    final sink = createSink(cap: 1024);
    final records = [
      _record(message: "earlier", error: null, stack: null),
      _record(message: "final cleanup", error: null, stack: null),
    ];
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

  test("directory lookup failures use the same non-recursive fallback", () async {
    directory.failure = const FileSystemException("lookup");
    final sink = createSink(cap: 1024);
    sink.write(record: _record(message: "still visible", error: null, stack: null));
    await sink.flush();
    expect(failures.single, contains("lookup"));
    expect(Directory("${root.path}/logs").existsSync(), isFalse);
  });
}

LogRecord _record({required String message, required String? error, required StackTrace? stack}) => LogRecord(
  level: LogLevel.info,
  timestamp: DateTime.utc(2026),
  message: message,
  diagnosticError: error,
  stackTrace: stack,
);

class _DirectorySource({required final Directory root}) implements DesktopApplicationSupportDirectory {
  int calls = 0;
  FileSystemException? failure;
  Future<Directory>? pending;
  @override
  Future<Directory> resolve() async {
    calls++;
    if (failure case final error?) throw error;
    if (pending case final waiting?) return await waiting;
    return root;
  }
}
