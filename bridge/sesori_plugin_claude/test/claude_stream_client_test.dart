import "dart:async";
import "dart:convert";

import "package:claude_plugin/claude_plugin.dart";
import "package:claude_plugin/claude_testing.dart";
import "package:test/test.dart";

import "support/claude_stream_client_test_factory.dart";

void main() {
  group("connect", () {
    test("performs the initialize handshake and retains its catalog", () async {
      final connected = await connectTestClient(handshake: sampleHandshake);
      addTearDown(connected.client.dispose);

      final request = await waitForFrame(connected.fake, "control_request");
      expect((request["request"]! as Map)["subtype"], "initialize");

      // One handshake yields commands, agents and models together, which is
      // why the catalog service needs no separate startup probes.
      expect(connected.client.handshake, isNotNull);
      expect(connected.client.handshake!["models"], hasLength(3));
      expect(connected.client.handshake!["commands"], hasLength(1));
      expect(connected.client.isConnected, isTrue);
    });

    test("tears down and rethrows when the handshake fails", () async {
      final fake = FakeClaudeProcess();
      addTearDown(fake.close);
      final client = ClaudeStreamClient(
        launchSpec: testLaunchSpec(),
        processFactory: (_) async => fake,
        controlTimeout: const Duration(seconds: 5),
      );

      final connecting = client.connect();
      final request = await waitForFrame(fake, "control_request");
      fake.emitControlError(requestId: request["request_id"]! as String, error: "boom");

      // Continuing without the catalog would surface an empty model and command
      // list as if the backend genuinely had none.
      await expectLater(connecting, throwsA(isA<ClaudeControlException>()));
      expect(client.isConnected, isFalse);
      expect(fake.killed, isTrue);
    });

    test("refuses a second connect and a connect after dispose", () async {
      final connected = await connectTestClient();
      await expectLater(connected.client.connect(), throwsStateError);

      await connected.client.dispose();
      await expectLater(connected.client.connect(), throwsStateError);
    });

    test("reaps a process that spawned while teardown was in flight", () async {
      final fake = FakeClaudeProcess();
      addTearDown(fake.close);
      final spawnGate = Completer<void>();
      final client = ClaudeStreamClient(
        launchSpec: testLaunchSpec(),
        processFactory: (_) async {
          await spawnGate.future;
          return fake;
        },
      );

      final connecting = client.connect();
      await pump();
      // Dispose sees no process to reap, because the spawn has not returned.
      final disposing = client.dispose();
      spawnGate.complete();

      await expectLater(connecting, throwsStateError);
      await disposing;
      // Without the post-spawn generation check the subprocess would leak.
      expect(fake.killed, isTrue);
    });
  });

  group("framing", () {
    test("splits several frames arriving in one chunk", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      final seen = <ClaudeStreamMessage>[];
      connected.client.messages.listen(seen.add);

      connected.fake.emitRaw(
        ndjson([
          {"type": "system", "subtype": "status", "status": "requesting"},
          {
            "type": "stream_event",
            "event": {"type": "message_stop"},
          },
          {"type": "result", "subtype": "success"},
        ]),
      );
      connected.fake.emitRaw(utf8.encode("\n"));
      await pump(10);

      expect(seen.map((message) => message.runtimeType.toString()), [
        "ClaudeStatusMessage",
        "ClaudeStreamEventMessage",
        "ClaudeResultMessage",
      ]);
    });

    test("reassembles a frame split across chunks", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      final seen = <ClaudeStreamMessage>[];
      connected.client.messages.listen(seen.add);

      connected.fake.emitRaw(utf8.encode('{"type":"result","sub'));
      await pump();
      expect(seen, isEmpty);

      connected.fake.emitRaw(utf8.encode('type":"success"}\n'));
      await pump(10);

      expect(seen.single, isA<ClaudeResultMessage>());
    });

    test("skips blank and unparseable lines without dropping the stream", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      final seen = <ClaudeStreamMessage>[];
      connected.client.messages.listen(seen.add);

      connected.fake.emitRaw(utf8.encode('\n   \nnot json\n[1,2,3]\n{"type":"result"}\n'));
      await pump(10);

      // Only the valid object frame survives; the rest are absorbed.
      expect(seen.single, isA<ClaudeResultMessage>());
    });

    test("survives non-UTF-8 bytes on stderr", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      final seen = <ClaudeStreamMessage>[];
      connected.client.messages.listen(seen.add);

      // A crashing child emits raw bytes; a strict decoder would throw here and
      // take the diagnostic stream down exactly when it matters most.
      connected.fake.emitStderrRaw([0xC3, 0x28, 0xA0, 0xA1]);
      await pump();
      connected.fake.emit({"type": "result", "subtype": "success"});
      await pump(10);

      expect(seen.single, isA<ClaudeResultMessage>());
      expect(connected.client.isConnected, isTrue);
    });

    test("captures the init frame as it passes through", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      expect(connected.client.init, isNull);
      connected.fake.emit(sampleInit());
      await pump(10);

      expect(connected.client.init?.cliVersion, "2.1.221");
      expect(connected.client.init?.permissionMode, ClaudePermissionMode.auto);
    });
  });

  group("control requests", () {
    test("correlates a response to its request by id", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      final pending = connected.client.sendControlRequest(
        subtype: "list_models",
      );
      final frames = connected.fake.written.where((frame) => frame["type"] == "control_request").toList();
      final requestId = frames.last["request_id"]! as String;
      expect(requestId, isNot("sesori-1"), reason: "the handshake already used the first id");

      connected.fake.emitControlResponse(requestId: requestId, payload: {"models": <Object?>[]});
      expect(await pending, {"models": <Object?>[]});
    });

    test("carries request params alongside the subtype", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      unawaited(
        connected.client
            .sendControlRequest(subtype: "set_model", params: {"model": "small"})
            .catchError((Object _) => <String, Object?>{}),
      );
      await pump();

      final frame = connected.fake.written.last;
      final request = frame["request"]! as Map;
      expect(request["subtype"], "set_model");
      expect(request["model"], "small");
    });

    test("does not let params replace the requested subtype", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      unawaited(
        connected.client
            .sendControlRequest(
              subtype: "set_model",
              params: {"subtype": "interrupt", "model": "small"},
            )
            .catchError((Object _) => <String, Object?>{}),
      );
      await pump();

      final request = connected.fake.written.last["request"]! as Map;
      expect(request["subtype"], "set_model");
      expect(request["model"], "small");
    });

    test("ignores a response for an unknown request id", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      connected.fake.emitControlResponse(requestId: "not-ours", payload: {"a": 1});
      await pump(10);

      // Absorbed, and the client stays usable.
      expect(connected.client.isConnected, isTrue);
    });

    test("fails an in-flight request when the process exits", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      // Attach the expectation before the error is delivered: an in-flight
      // future that completes with an error while unobserved surfaces as an
      // unhandled zone error rather than reaching the assertion.
      final pending = connected.client.sendControlRequest(subtype: "list_models");
      final expectation = expectLater(pending, throwsA(isA<ClaudeControlException>()));
      await pump();
      connected.fake.exit(1);

      await expectation;
    });

    test("fails fast once the process has exited", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      connected.fake.exit(0);
      await pump(10);

      // Without the exit check this would write to a dead pipe and then block
      // for the full control timeout awaiting a reply that can never come.
      await expectLater(
        connected.client.sendControlRequest(subtype: "list_models"),
        throwsA(isA<ClaudeControlException>()),
      );
      expect(connected.client.isConnected, isFalse);
    });

    test("times out when no reply arrives", () async {
      final connected = await connectTestClient(controlTimeout: const Duration(milliseconds: 50));
      addTearDown(connected.client.dispose);

      await expectLater(
        connected.client.sendControlRequest(subtype: "list_models"),
        throwsA(isA<TimeoutException>()),
      );
    });

    test("fails an in-flight request on dispose", () async {
      final connected = await connectTestClient();

      final pending = connected.client.sendControlRequest(subtype: "list_models");
      final expectation = expectLater(pending, throwsStateError);
      await pump();
      await connected.client.dispose();

      await expectation;
    });
  });

  group("outbound frames", () {
    test("writes a user turn carrying the session id", () async {
      final connected = await connectTestClient(sessionId: otherTestSessionId);
      addTearDown(connected.client.dispose);

      connected.client.sendUserMessage(
        content: [
          {"type": "text", "text": "hello"},
        ],
      );
      final frame = await waitForFrame(connected.fake, "user");

      expect(frame["session_id"], otherTestSessionId);
      expect(frame["priority"], "next");
      final message = frame["message"]! as Map;
      expect(message["role"], "user");
      expect((message["content"]! as List).single, {"type": "text", "text": "hello"});
    });

    test("fails a user turn after the process exits", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);
      connected.fake.exit(1);
      await pump(10);

      expect(
        () => connected.client.sendUserMessage(content: const []),
        throwsA(isA<ClaudeControlException>()),
      );
    });

    test("answers a control request with a success payload", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      connected.client.sendControlResponse(
        requestId: "ask-1",
        payload: {"behavior": "allow"},
      );
      final frame = await waitForFrame(connected.fake, "control_response");

      final response = frame["response"]! as Map;
      expect(response["subtype"], "success");
      expect(response["request_id"], "ask-1");
      expect(response["response"], {"behavior": "allow"});
    });

    test("answers a control request with an error", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      connected.client.sendControlResponseError(requestId: "ask-2", message: "no");
      await pump();

      final response = connected.fake.written.last["response"]! as Map;
      expect(response["subtype"], "error");
      expect(response["error"], "no");
    });

    test("rejects control responses after the process exits", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);
      connected.fake.exit(1);
      await pump(10);
      final before = connected.fake.written.length;

      expect(
        connected.client.sendControlResponse(requestId: "ask-3", payload: const {}),
        isFalse,
      );
      expect(
        connected.client.sendControlResponseError(requestId: "ask-4", message: "no"),
        isFalse,
      );
      expect(connected.fake.written, hasLength(before));
    });

    test("drops outbound writes after teardown instead of throwing", () async {
      final connected = await connectTestClient();
      await connected.client.dispose();
      final before = connected.fake.written.length;

      connected.client.sendUserMessage(
        content: [
          {"type": "text", "text": "late"},
        ],
      );
      connected.client.sendControlResponse(requestId: "ask-3", payload: const {});
      await pump();

      expect(connected.fake.written, hasLength(before));
    });
  });

  group("teardown", () {
    test("closes stdin and terminates the process", () async {
      final connected = await connectTestClient();

      await connected.client.dispose();

      // Closing stdin is the protocol's own shutdown signal, so it is tried
      // before signalling.
      expect((connected.fake.stdin as CapturingIOSink).closed, isTrue);
      expect(connected.fake.killed, isTrue);
      expect(connected.client.isConnected, isFalse);
    });

    test("terminates when closing stdin stalls", () async {
      final fake = FakeClaudeProcess(stdinCloseCompletes: false);
      final connected = await connectTestClient(process: fake);

      await connected.client.dispose(
        gracefulTimeout: const Duration(milliseconds: 20),
      );

      expect(fake.killed, isTrue);
      expect(connected.client.isConnected, isFalse);
    });

    test("is idempotent", () async {
      final connected = await connectTestClient();

      await connected.client.dispose();
      await connected.client.dispose();

      expect(connected.client.isConnected, isFalse);
    });

    test("ignores frames from a process torn down earlier", () async {
      final connected = await connectTestClient();
      final seen = <ClaudeStreamMessage>[];
      connected.client.messages.listen(seen.add);

      await connected.client.dispose();
      connected.fake.emit({"type": "result", "subtype": "success"});
      await pump(10);

      // Generation fencing: a late frame from the dead process must not reach
      // consumers of a connection established afterwards.
      expect(seen, isEmpty);
    });
  });
}
