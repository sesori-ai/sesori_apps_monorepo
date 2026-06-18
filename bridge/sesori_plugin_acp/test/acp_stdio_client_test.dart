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
}
