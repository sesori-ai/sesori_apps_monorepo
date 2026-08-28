import "dart:async";
import "dart:convert";

import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  group("BridgeProcessLogTracker", () {
    late _RecordingLogStorage storage;
    late DateTime now;
    late List<String> warnings;
    late BridgeProcessLogTracker tracker;
    late StreamController<List<int>> stdout;
    late StreamController<List<int>> stderr;

    setUp(() {
      storage = _RecordingLogStorage();
      now = DateTime.utc(2026, 8, 28, 12);
      warnings = <String>[];
      tracker = BridgeProcessLogTracker.forTesting(
        storage: storage,
        maxEntries: 2,
        maxPendingPersistenceEntries: 3,
        storageWarningInterval: const Duration(minutes: 1),
        now: () => now,
        reportWarning: ({required String message, required Object error, required StackTrace stackTrace}) {
          warnings.add(message);
        },
      );
      stdout = StreamController<List<int>>(sync: true);
      stderr = StreamController<List<int>>(sync: true);
    });

    tearDown(() async {
      if (!stdout.isClosed) {
        await stdout.close();
      }
      if (!stderr.isClosed) {
        await stderr.close();
      }
      await tracker.dispose();
    });

    test("drains fragmented stdout/stderr and retains the last-N snapshot", () async {
      await tracker.attach(stdout: stdout.stream, stderr: stderr.stream);

      stdout.add(utf8.encode("hel"));
      stdout.add(utf8.encode("lo\none\n"));
      stderr.add(utf8.encode("error\n"));
      await stdout.close();
      await stderr.close();
      await pumpEventQueue();

      expect(
        tracker.snapshot.map((entry) => (entry.source, entry.message)),
        equals(<(BridgeProcessLogSource, String)>[
          (BridgeProcessLogSource.stdout, "one"),
          (BridgeProcessLogSource.stderr, "error"),
        ]),
      );
      expect(tracker.snapshots.value, tracker.snapshot);
      expect(storage.logicalLines, hasLength(3));
      expect(storage.logicalLines.first, contains("[stdout] hello"));
      expect(storage.logicalLines.last, contains("[stderr] error"));
    });

    test("malformed bytes cannot stop the pipe drain", () async {
      await tracker.attach(stdout: stdout.stream, stderr: stderr.stream);

      stdout
        ..add(const [0xFF, 0x0A])
        ..add(utf8.encode("after\n"));
      await stdout.close();
      await pumpEventQueue();

      expect(tracker.snapshot.map((entry) => entry.message), containsAll(<String>["�", "after"]));
      expect(storage.logicalLines, hasLength(2));
    });

    test("storage failures are rate-limited and never stop capture", () async {
      storage.error = StateError("disk full");
      await tracker.attach(stdout: stdout.stream, stderr: stderr.stream);

      stdout
        ..add(utf8.encode("one\n"))
        ..add(utf8.encode("two\n"));
      await pumpEventQueue();

      expect(tracker.snapshot.map((entry) => entry.message), ["one", "two"]);
      expect(storage.attempts, 2);
      expect(warnings, hasLength(1));

      now = now.add(const Duration(seconds: 30));
      stdout.add(utf8.encode("three\n"));
      await pumpEventQueue();
      expect(warnings, hasLength(1));

      now = now.add(const Duration(seconds: 31));
      stdout.add(utf8.encode("four\n"));
      await pumpEventQueue();
      expect(warnings, hasLength(2));
      expect(tracker.snapshot.map((entry) => entry.message), ["three", "four"]);
    });

    test("bounds queued persistence and batches the newest pending lines", () async {
      final Completer<void> releaseWrite = Completer<void>();
      storage.writeGate = releaseWrite.future;
      await tracker.attach(stdout: stdout.stream, stderr: stderr.stream);

      for (int index = 0; index < 10; index++) {
        stdout.add(utf8.encode("line-$index\n"));
      }
      await pumpEventQueue();

      expect(storage.attempts, 1);
      expect(tracker.snapshot.map((entry) => entry.message), ["line-8", "line-9"]);
      expect(warnings, hasLength(1));

      releaseWrite.complete();
      await pumpEventQueue();

      expect(storage.attempts, 2);
      expect(storage.logicalLines, hasLength(4));
      expect(storage.logicalLines.first, endsWith("line-0"));
      expect(
        storage.logicalLines.skip(1),
        everyElement(anyOf(endsWith("line-7"), endsWith("line-8"), endsWith("line-9"))),
      );
    });

    test("attaching a new process cancels the old pipe subscriptions", () async {
      await tracker.attach(stdout: stdout.stream, stderr: stderr.stream);
      final StreamController<List<int>> replacementStdout = StreamController<List<int>>(sync: true);
      final StreamController<List<int>> replacementStderr = StreamController<List<int>>(sync: true);
      addTearDown(replacementStdout.close);
      addTearDown(replacementStderr.close);

      await tracker.attach(stdout: replacementStdout.stream, stderr: replacementStderr.stream);
      stdout.add(utf8.encode("stale\n"));
      replacementStdout.add(utf8.encode("current\n"));
      await pumpEventQueue();

      expect(tracker.snapshot.map((entry) => entry.message), ["current"]);
    });
  });
}

class _RecordingLogStorage() implements BridgeProcessLogStorage {
  final List<String> lines = <String>[];
  int attempts = 0;
  Object? error;
  Future<void>? writeGate;

  List<String> get logicalLines => lines.expand((chunk) => chunk.split("\n")).toList(growable: false);

  @override
  Future<void> appendLine({required String line}) async {
    attempts++;
    final Future<void>? gate = writeGate;
    if (gate != null) {
      await gate;
    }
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    lines.add(line);
  }

  @override
  Future<String> get logFilePath async => "/tmp/bridge.log";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
