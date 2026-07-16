import "dart:async";
import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:test/test.dart";

void main() {
  group("AcpStdioClient", () {
    late FakeAcpProcess fake;
    late AcpStdioClient client;

    setUp(() async {
      fake = FakeAcpProcess();
      client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();
    });

    tearDown(() async {
      await client.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    test("request writes an ndjson frame and correlates the response by id", () async {
      final future = client.request(method: "initialize", params: {"a": 1});

      expect(fake.written, hasLength(1));
      final frame = fake.written.single;
      expect(frame["method"], "initialize");
      expect(frame["jsonrpc"], "2.0");
      final id = frame["id"];

      fake.emit({"jsonrpc": "2.0", "id": id, "result": {"ok": true}});
      final result = await future;
      expect((result as Map)["ok"], true);
    });

    test("error responses surface as AcpRpcException", () async {
      final future = client.request(method: "session/new");
      final id = fake.written.single["id"];
      fake.emit({
        "jsonrpc": "2.0",
        "id": id,
        "error": {"code": -32000, "message": "boom"},
      });
      await expectLater(future, throwsA(isA<AcpRpcException>()));
    });

    test("notifications route to the notifications stream", () async {
      final seen = <AcpNotification>[];
      client.notifications.listen(seen.add);
      fake.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {"sessionId": "s1"},
      });
      await pump();
      expect(seen, hasLength(1));
      expect(seen.single.method, "session/update");
      expect(seen.single.params["sessionId"], "s1");
    });

    test("server requests route to serverRequests and can be answered", () async {
      final reqs = <AcpServerRequest>[];
      client.serverRequests.listen(reqs.add);
      fake.emit({
        "jsonrpc": "2.0",
        "id": 42,
        "method": "session/request_permission",
        "params": {"sessionId": "s1"},
      });
      await pump();
      expect(reqs.single.id, 42);

      client.respondToServerRequest(id: 42, result: {"outcome": "ok"});
      final reply = fake.written.last;
      expect(reply["id"], 42);
      expect((reply["result"] as Map)["outcome"], "ok");
    });

    test("notify sends an id-less frame", () {
      client.notify(method: "session/cancel", params: {"sessionId": "s1"});
      final frame = fake.written.single;
      expect(frame["method"], "session/cancel");
      expect(frame.containsKey("id"), isFalse);
    });

    test("early process exit fails in-flight requests", () async {
      final future = client.request(method: "session/prompt");
      fake.exit(1);
      await expectLater(future, throwsA(isA<AcpRpcException>()));
    });

    test("a request after the process exited fails fast instead of timing out", () async {
      fake.exit(1);
      await pump();
      // Without the post-exit guard this would write to a dead pipe and block
      // for the full timeout; it must throw synchronously-ish instead.
      await expectLater(
        client.request(method: "session/prompt"),
        throwsA(isA<StateError>()),
      );
    });

    test("a malformed error payload still completes the pending request", () async {
      // `error` is not a map: the old `as Map` cast threw inside the line
      // handler (caught + logged) and orphaned the completer until timeout.
      final future = client.request(method: "session/new");
      final id = fake.written.single["id"];
      fake.emit({"jsonrpc": "2.0", "id": id, "error": "totally malformed"});
      await expectLater(future, throwsA(isA<AcpRpcException>()));
    });

    test("an error payload with a non-int code falls back to a generic code", () async {
      final future = client.request(method: "session/new");
      final id = fake.written.single["id"];
      fake.emit({
        "jsonrpc": "2.0",
        "id": id,
        "error": {"code": "nope", "message": 123},
      });
      await expectLater(
        future,
        throwsA(isA<AcpRpcException>()
            .having((e) => e.code, "code", -32603)
            .having((e) => e.message, "message", "unknown error")),
      );
    });
  });

  group("AcpStdioClient reset", () {
    Future<void> pump() => Future<void>.delayed(Duration.zero);

    test("permits reconnect while keeping notification streams open", () async {
      final first = FakeAcpProcess();
      final replacement = FakeAcpProcess();
      final processes = <FakeAcpProcess>[first, replacement];
      var spawnIndex = 0;
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        processFactory: (_) async => processes[spawnIndex++],
      );
      addTearDown(() async {
        await client.dispose();
        await first.close();
        await replacement.close();
      });
      final notifications = <AcpNotification>[];
      final serverRequests = <AcpServerRequest>[];
      client.notifications.listen(notifications.add);
      client.serverRequests.listen(serverRequests.add);

      await client.connect();
      final pending = client.request(method: "session/prompt");
      final pendingFailure = expectLater(pending, throwsA(isA<StateError>()));

      await client.reset(gracefulTimeout: const Duration(seconds: 5));
      await pendingFailure;
      expect(client.isConnected, isFalse);

      await client.connect();
      expect(client.isConnected, isTrue);
      replacement.emit({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {"sessionId": "replacement"},
      });
      replacement.emit({
        "jsonrpc": "2.0",
        "id": 42,
        "method": "session/request_permission",
        "params": {"sessionId": "replacement"},
      });
      await pump();
      expect(notifications.single.params["sessionId"], "replacement");
      expect(serverRequests.single.params["sessionId"], "replacement");

      final request = client.request(method: "initialize");
      final id = replacement.written.single["id"];
      replacement.emit({"jsonrpc": "2.0", "id": id, "result": {"ok": true}});
      expect((await request as Map)["ok"], isTrue);
      expect(spawnIndex, 2);
    });

    test("a late old-process exit cannot fail or mark the replacement", () async {
      final old = _LateExitAcpProcess();
      final replacement = FakeAcpProcess();
      var spawnIndex = 0;
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        processFactory: (_) async => spawnIndex++ == 0 ? old : replacement,
      );
      addTearDown(() async {
        await client.dispose();
        await old.close();
        await replacement.close();
      });

      await client.connect();
      await client.reset(gracefulTimeout: Duration.zero);
      await client.connect();

      var replacementExited = false;
      unawaited(client.processExit.then((_) => replacementExited = true));
      final outcome = client.request(method: "initialize").then<Object>(
        (result) => result as Object,
        onError: (Object error, StackTrace _) => error,
      );
      final id = replacement.written.single["id"];

      old.exit(23);
      await pump();
      expect(client.isConnected, isTrue);
      expect(replacementExited, isFalse);

      replacement.emit({"jsonrpc": "2.0", "id": id, "result": {"ok": true}});
      expect((await outcome as Map)["ok"], isTrue);
    });
  });

  group("AcpStdioClient disposed mid-connect", () {
    test("reaps the just-spawned process instead of wiring a disposed client", () async {
      final fake = FakeAcpProcess();
      final spawn = Completer<AcpProcessHandle>();
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        processFactory: (_) => spawn.future,
      );

      // Start connecting; it parks on the spawn future.
      final connecting = client.connect();
      // Shut down while the spawn is still in flight — dispose() sees no
      // process to kill.
      await client.dispose();
      // The process only finishes spawning after the client was disposed.
      spawn.complete(fake);

      await expectLater(connecting, throwsA(isA<StateError>()));
      // The orphaned process was reaped (kill() completes exitCode with -15)…
      expect(await fake.exitCode, -15);
      // …and the disposed client never came up.
      expect(client.isConnected, isFalse);

      await fake.close();
    });
  });
}

class _LateExitAcpProcess implements AcpProcessHandle {
  final FakeAcpProcess _delegate = FakeAcpProcess();

  @override
  Stream<List<int>> get stdout => _delegate.stdout;

  @override
  Stream<List<int>> get stderr => _delegate.stderr;

  @override
  io.IOSink get stdin => _delegate.stdin;

  @override
  Future<int> get exitCode => _delegate.exitCode;

  @override
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]) => true;

  void exit(int code) => _delegate.exit(code);

  Future<void> close() => _delegate.close();
}
