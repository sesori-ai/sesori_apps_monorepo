import "dart:async";
import "dart:convert";

import "package:claude_plugin/claude_plugin.dart";
import "package:test/test.dart";

import "support/claude_stream_client_test_factory.dart";
import "support/fake_claude_process.dart";

void main() {
  group("connect", () {
    test("performs the initialize handshake and retains its catalog", () async {
      final connected = await connectTestClient(handshake: sampleHandshake);
      addTearDown(connected.client.dispose);

      final request = await waitForFrame(connected.fake, "control_request");
      expect(request.field<Map<String, Object?>>("request")["subtype"], "initialize");
      expect(request.field<Map<String, Object?>>("request")["elicitation"], isEmpty);

      // One handshake yields commands, agents and models together, which is
      // why the catalog service needs no separate startup probes.
      expect(connected.client.handshake, isNotNull);
      expect(connected.client.handshake?["models"], hasLength(3));
      expect(connected.client.handshake?["commands"], hasLength(1));
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
      fake.emitControlError(requestId: request.field<String>("request_id"), error: "boom");

      // Continuing without the catalog would surface an empty model and command
      // list as if the backend genuinely had none.
      await expectLater(connecting, throwsA(isA<ClaudeControlException>()));
      expect(fake.killed, isTrue);
    });

    test("names the option a CLI that does not know it refused at startup", () async {
      final fake = FakeClaudeProcess();
      addTearDown(fake.close);
      final client = ClaudeStreamClient(
        launchSpec: testLaunchSpec(),
        processFactory: (_) async => fake,
        controlTimeout: const Duration(seconds: 5),
      );

      final connecting = client.connect();
      await waitForFrame(fake, "control_request");
      // Recorded from 2.1.221 given a flag it predates: the exit can land
      // before the stderr line.
      fake.exit(1);
      await pump();
      fake.emitStderrRaw(utf8.encode("error: unknown option '--resume-session-at=$testSessionId'\n"));
      await fake.close();

      await expectLater(
        connecting,
        throwsA(
          isA<ClaudeUnknownOptionException>()
              .having((error) => error.option, "option", "--resume-session-at")
              .having((error) => error.innerError, "innerError", isA<ClaudeControlException>()),
        ),
      );
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
      final requestId = frames.last.field<String>("request_id");
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
      final request = frame.field<Map<String, Object?>>("request");
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

      final request = connected.fake.written.last.field<Map<String, Object?>>("request");
      expect(request["subtype"], "set_model");
      expect(request["model"], "small");
    });

    test("ignores a response for an unknown request id", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      connected.fake.emitControlResponse(requestId: "not-ours", payload: {"a": 1});
      await pump(10);

      // Absorbed, and the client stays usable. The handshake used the first id.
      final pending = connected.client.sendControlRequest(subtype: "list_models");
      connected.fake.emitControlResponse(requestId: "sesori-2", payload: const {});
      expect(await pending, isEmpty);
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
    });

    test("times out when no reply arrives", () async {
      // The short timeout also covers the handshake, so the fake answers it as
      // it is written: no timer turn lets the timeout win on a loaded machine.
      final fake = FakeClaudeProcess();
      var handshakeAnswered = false;
      fake.onWrite((frame) {
        if (handshakeAnswered || frame["type"] != "control_request") return;
        handshakeAnswered = true;
        fake.emitControlResponse(requestId: frame.field<String>("request_id"), payload: const {});
      });
      final client = ClaudeStreamClient(
        launchSpec: testLaunchSpec(),
        processFactory: (_) async => fake,
        controlTimeout: const Duration(milliseconds: 50),
      );
      addTearDown(client.dispose);
      await client.connect();

      await expectLater(client.sendControlRequest(subtype: "list_models"), throwsA(isA<TimeoutException>()));
    });

    test("fails an in-flight request on dispose", () async {
      final connected = await connectTestClient();

      final pending = connected.client.sendControlRequest(subtype: "list_models");
      final expectation = expectLater(pending, throwsA(isA<ClaudeControlException>()));
      await pump();
      await connected.client.dispose();

      await expectation;
    });
  });

  group("side questions", () {
    test("sends the question with its history and parses the answer", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      final pending = connected.client.sendSideQuestion(
        question: "What changed?",
        history: const [(question: "Which file?", response: "main.dart")],
        timeout: const Duration(seconds: 5),
      );
      await pump();
      final frame = connected.fake.written.last;
      expect(frame["type"], "control_request");
      expect(frame["request"], {
        "subtype": "side_question",
        "question": "What changed?",
        "history": [
          {"question": "Which file?", "response": "main.dart"},
        ],
      });
      connected.fake.emitControlResponse(
        requestId: frame.field<String>("request_id"),
        payload: {
          "response": "Only the parser.",
          "synthetic": false,
          "refusal_fallback": {"original_model": "a", "fallback_model": "b", "content": "A fallback answered."},
        },
      );

      final response = await pending;
      expect(response.response, "Only the parser.");
      expect(response.synthetic, isFalse);
      expect(response.refusalFallback?.content, "A fallback answered.");
    });

    test("omits empty history", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      connected.client
          .sendSideQuestion(question: "Why?", history: const [], timeout: const Duration(seconds: 5))
          .ignore();
      await pump();

      expect(connected.fake.written.last["request"], {"subtype": "side_question", "question": "Why?"});
    });

    test("raises the CLI's unknown-subtype error as a typed exception", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      final pending = connected.client.sendSideQuestion(
        question: "Why?",
        history: const [],
        timeout: const Duration(seconds: 5),
      );
      final expectation = expectLater(
        pending,
        throwsA(isA<ClaudeControlUnsupportedSubtypeException>().having((e) => e.subtype, "subtype", "side_question")),
      );
      await pump();
      connected.fake.emitControlError(
        requestId: connected.fake.written.last.field<String>("request_id"),
        error: "Unsupported control request subtype: side_question",
      );

      await expectation;
    });

    test("keeps other failures as control exceptions", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      final pending = connected.client.sendSideQuestion(
        question: "Why?",
        history: const [],
        timeout: const Duration(seconds: 5),
      );
      final expectation = expectLater(
        pending,
        throwsA(
          isA<ClaudeControlException>().having((e) => e.message, "message", "Session is shutting down"),
        ),
      );
      await pump();
      connected.fake.emitControlError(
        requestId: connected.fake.written.last.field<String>("request_id"),
        error: "Session is shutting down",
      );

      await expectation;
    });

    test("cancels the ask when its own timeout passes", () async {
      // The generic control timeout never fires within the test, so a timeout
      // proves the ask uses its own.
      final connected = await connectTestClient(controlTimeout: const Duration(hours: 1));
      addTearDown(connected.client.dispose);

      final pending = connected.client.sendSideQuestion(
        question: "Why?",
        history: const [],
        timeout: const Duration(milliseconds: 10),
      );
      final requestId = connected.fake.written.last.field<String>("request_id");
      expect(connected.fake.written.where((frame) => frame["type"] == "control_cancel_request"), isEmpty);

      await expectLater(pending, throwsA(isA<TimeoutException>()));
      expect(connected.fake.written.last, {"type": "control_cancel_request", "request_id": requestId});

      // The CLI's reply to the cancel is for a request nobody waits on.
      connected.fake.emitControlError(requestId: requestId, error: "Side question cancelled");
      await pump();
    });

    test("does not cancel an ordinary control request on timeout", () async {
      final connected = await connectTestClient(controlTimeout: const Duration(milliseconds: 20));
      addTearDown(connected.client.dispose);

      await expectLater(
        connected.client.sendControlRequest(subtype: "list_models"),
        throwsA(isA<TimeoutException>()),
      );
      expect(connected.fake.written.where((frame) => frame["type"] == "control_cancel_request"), isEmpty);
    });
  });

  group("outbound frames", () {
    test("writes a user turn carrying the session id", () async {
      final connected = await connectTestClient(sessionId: otherTestSessionId);
      addTearDown(connected.client.dispose);

      connected.client.sendUserMessage(
        isSynthetic: false,
        content: [
          {"type": "text", "text": "hello"},
        ],
        uuid: "prompt-uuid-1",
      );
      final frame = await waitForFrame(connected.fake, "user");

      expect(frame["session_id"], otherTestSessionId);
      expect(frame["uuid"], "prompt-uuid-1");
      expect(frame["priority"], "next");
      final message = frame.field<Map<String, Object?>>("message");
      expect(message["role"], "user");
      expect(message.field<List<Object?>>("content").single, {"type": "text", "text": "hello"});
      expect(frame.containsKey("isSynthetic"), isFalse);
    });

    test("marks a synthetic user turn beside its message", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);

      connected.client.sendUserMessage(
        isSynthetic: true,
        content: [
          {"type": "text", "text": "[SESORI NOTICE]\nA page was answered."},
        ],
        uuid: "prompt-uuid-3",
      );
      final frame = await waitForFrame(connected.fake, "user");

      expect(frame["isSynthetic"], isTrue);
    });

    test("fails a user turn after the process exits", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);
      connected.fake.exit(1);
      await pump(10);

      expect(
        () => connected.client.sendUserMessage(isSynthetic: false, content: const [], uuid: "prompt-uuid-2"),
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

      final response = frame.field<Map<String, Object?>>("response");
      expect(response["subtype"], "success");
      expect(response["request_id"], "ask-1");
      expect(response["response"], {"behavior": "allow"});
    });

    test("rejects a control response after the process exits", () async {
      final connected = await connectTestClient();
      addTearDown(connected.client.dispose);
      connected.fake.exit(1);
      await pump(10);
      final before = connected.fake.written.length;

      expect(
        connected.client.sendControlResponse(requestId: "ask-3", payload: const {}),
        isFalse,
      );
      expect(connected.fake.written, hasLength(before));
    });

    test("drops outbound writes after teardown instead of throwing", () async {
      final connected = await connectTestClient();
      await connected.client.dispose();
      final before = connected.fake.written.length;

      connected.client.sendUserMessage(
        isSynthetic: false,
        content: [
          {"type": "text", "text": "late"},
        ],
        uuid: "prompt-uuid-3",
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
    });

    test("terminates when closing stdin stalls", () async {
      final fake = FakeClaudeProcess(stdinCloseCompletes: false);
      final connected = await connectTestClient(process: fake);

      await connected.client.dispose(
        gracefulTimeout: const Duration(milliseconds: 20),
      );

      expect(fake.killed, isTrue);
    });

    test("is idempotent", () async {
      final connected = await connectTestClient();

      await connected.client.dispose();
      await connected.client.dispose();

      expect(connected.fake.killed, isTrue);
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
