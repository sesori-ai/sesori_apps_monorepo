import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:pi_plugin/pi_plugin.dart";
import "package:pi_plugin/pi_testing.dart";
import "package:test/test.dart";

import "support/pi_rpc_client_test_factory.dart";

void main() {
  group("framing", () {
    test("splits several records arriving in one chunk", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);
      final seen = <PiRpcFrame>[];
      started.client.frames.listen(seen.add);

      started.process.emitRaw(
        bytes: utf8.encode(
          [
            jsonEncode(piEventFixture(type: "agent_start", fields: const {})),
            jsonEncode(piEventFixture(type: "turn_start", fields: const {})),
            jsonEncode(piEventFixture(type: "agent_settled", fields: const {})),
          ].join("\n"),
        ),
      );
      started.process.emitRaw(bytes: utf8.encode("\n"));
      await pump(10);

      expect(
        seen.map((frame) => (frame as PiEventFrame).event.runtimeType.toString()),
        ["PiAgentStartEvent", "PiTurnStartEvent", "PiAgentSettledEvent"],
      );
    });

    test("reassembles a record split across chunks", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);
      final seen = <PiRpcFrame>[];
      started.client.frames.listen(seen.add);

      started.process.emitRaw(bytes: utf8.encode('{"type":"agent_'));
      await pump();
      expect(seen, isEmpty);

      started.process.emitRaw(bytes: utf8.encode('settled"}\n'));
      await pump(10);

      expect((seen.single as PiEventFrame).event, isA<PiAgentSettledEvent>());
    });

    test("reassembles a multi-byte character split across chunks", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);
      final seen = <PiRpcFrame>[];
      started.client.frames.listen(seen.add);

      final bytes = utf8.encode('{"type":"session_info_changed","name":"café ☕"}\n');
      // Cut inside the two-byte "é" so a chunk ends mid-character.
      final split = utf8.encode('{"type":"session_info_changed","name":"caf').length + 1;
      started.process.emitRaw(bytes: bytes.sublist(0, split));
      await pump();
      started.process.emitRaw(bytes: bytes.sublist(split));
      await pump(10);

      final event = (seen.single as PiEventFrame).event as PiSessionInfoChangedEvent;
      expect(event.name, "café ☕");
    });

    test("reassembles a large record split across many chunks", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);
      final seen = <PiRpcFrame>[];
      started.client.frames.listen(seen.add);
      final name = "x" * 100000;
      final bytes = utf8.encode('${jsonEncode({"type": "session_info_changed", "name": name})}\n');

      for (var offset = 0; offset < bytes.length; offset += 97) {
        started.process.emitRaw(bytes: bytes.sublist(offset, min(offset + 97, bytes.length)));
      }
      await pump(20);

      expect(((seen.single as PiEventFrame).event as PiSessionInfoChangedEvent).name, name);
    });

    test("tolerates CRLF separators without corrupting the record", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);
      final seen = <PiRpcFrame>[];
      started.client.frames.listen(seen.add);

      started.process.emitRaw(
        bytes: utf8.encode('{"type":"agent_start"}\r\n{"type":"agent_settled"}\r\n'),
      );
      await pump(10);

      expect(seen, hasLength(2));
      expect(seen.whereType<PiUnknownFrame>(), isEmpty);
    });

    test("does not split on a bare CR, U+2028, or U+2029 inside a JSON string", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);
      final seen = <PiRpcFrame>[];
      started.client.frames.listen(seen.add);

      // A bare CR must be escaped in JSON, so it reaches the framer as "\\r".
      // U+2028/U+2029 are literal characters that a line splitter would break
      // on, splitting one frame into unparseable halves.
      started.process.emitRaw(
        bytes: utf8.encode('{"type":"session_info_changed","name":"a\\rb\u2028c\u2029d"}\n'),
      );
      await pump(10);

      final event = (seen.single as PiEventFrame).event as PiSessionInfoChangedEvent;
      expect(event.name, "a\rb\u2028c\u2029d");
    });

    test("absorbs blank and undecodable records without dropping the stream", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);
      final seen = <PiRpcFrame>[];
      started.client.frames.listen(seen.add);

      started.process.emitRaw(bytes: utf8.encode('\n   \nnot json\n[1,2,3]\n{"type":"agent_settled"}\n'));
      await pump(10);

      expect(seen, hasLength(1));
      expect(started.client.isRunning, isTrue);
    });
  });

  group("request correlation", () {
    test("correlates a response by id regardless of event order", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      final first = started.client.send(
        command: PiRpcCommand.getState,
        arguments: const {},
        timeout: const Duration(seconds: 5),
      );
      final second = started.client.send(
        command: PiRpcCommand.getAvailableModels,
        arguments: const {},
        timeout: const Duration(seconds: 5),
      );
      await pump();
      final ids = started.process.written.map((frame) => frame["id"]).toList();

      // Events interleave, and the second response lands before the first: only
      // the id may decide which future completes.
      started.process.emit(
        frame: piEventFixture(type: "agent_start", fields: const {}),
      );
      started.process.emitResponse(
        id: ids[1]! as String,
        command: "get_available_models",
        data: {"models": <Object?>[]},
      );
      started.process.emit(
        frame: piEventFixture(type: "agent_settled", fields: const {}),
      );
      started.process.emitResponse(id: ids[0]! as String, command: "get_state", data: {"sessionId": "s1"});

      expect((await first).data["sessionId"], "s1");
      expect((await second).command, PiRpcCommand.getAvailableModels);
    });

    test("completes a prompt from its acceptance response even after its events", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      final prompt = started.client.send(
        command: PiRpcCommand.prompt,
        arguments: {"message": "hi"},
        timeout: const Duration(seconds: 5),
      );
      final command = await waitForCommand(process: started.process, type: "prompt");

      // Pi answers prompt from an asynchronous preflight, so the whole turn can
      // stream before the acceptance arrives.
      started.process.emit(
        frame: piEventFixture(type: "agent_start", fields: const {}),
      );
      started.process.emit(
        frame: piEventFixture(type: "agent_settled", fields: const {}),
      );
      await pump();
      expect(started.client.isRunning, isTrue);
      started.process.emitResponse(id: command["id"]! as String, command: "prompt");

      expect((await prompt).command, PiRpcCommand.prompt);
      expect(command["message"], "hi");
    });

    test("fails a request when Pi answers it with an error", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      final pending = started.client.send(
        command: PiRpcCommand.getEntries,
        arguments: {"since": "missing"},
        timeout: const Duration(seconds: 5),
      );
      final command = await waitForCommand(process: started.process, type: "get_entries");
      started.process.emitFailure(id: command["id"]! as String, command: "get_entries", error: "Unknown entry");

      await expectLater(
        pending,
        throwsA(
          isA<PiRpcCommandFailureException>()
              .having((error) => error.error, "error", "Unknown entry")
              .having((error) => error.command, "command", PiRpcCommand.getEntries)
              .having((error) => error.toString(), "presentation", isNot(contains("Unknown entry"))),
        ),
      );
      expect(started.client.isRunning, isTrue);
    });

    test("never lets arguments overwrite the request id or command type", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      final pending = started.client.send(
        command: PiRpcCommand.prompt,
        arguments: {"id": "spoofed", "type": "abort"},
        timeout: const Duration(seconds: 5),
      );
      final command = await waitForCommand(process: started.process, type: "prompt");
      started.process.emitResponse(id: command["id"]! as String, command: "prompt");

      expect(command["id"], isNot("spoofed"));
      expect((await pending).command, PiRpcCommand.prompt);
    });

    test("absorbs an uncorrelated response, including Pi's id-less parse failure", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      started.process.emitResponse(id: "not-ours", command: "get_state");
      started.process.emit(
        frame: {
          "type": "response",
          "command": "parse",
          "success": false,
          "error": "Failed to parse command",
        },
      );
      await pump(10);

      expect(started.client.isRunning, isTrue);
    });

    test("times out when no response arrives", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      await expectLater(
        started.client.send(
          command: PiRpcCommand.getState,
          arguments: const {},
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group("process failure", () {
    test("keeps a process-exit listener attached before startup", () async {
      final process = FakePiProcess();
      addTearDown(process.close);
      final client = PiRpcClient(
        launchSpec: testLaunchSpec(),
        processFactory: ({required spec}) async => process,
      );
      addTearDown(client.dispose);
      final exit = client.processExit;

      await client.start();
      process.exit(code: 7);

      expect(await exit.timeout(const Duration(milliseconds: 50)), 7);
    });

    test("fails in-flight requests when the process exits", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      final pending = started.client.send(
        command: PiRpcCommand.getState,
        arguments: const {},
        timeout: const Duration(seconds: 5),
      );
      final expectation = expectLater(
        pending,
        throwsA(isA<PiRpcProcessExitException>().having((error) => error.exitCode, "exitCode", 3)),
      );
      await pump();
      started.process.exit(code: 3);

      await expectation;
      expect(started.client.isRunning, isFalse);
    });

    test("handles a buffered final response before failing requests on exit", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);
      final pending = started.client.send(
        command: PiRpcCommand.getState,
        arguments: const {},
        timeout: const Duration(seconds: 5),
      );
      final command = await waitForCommand(process: started.process, type: "get_state");

      started.process.emitResponse(
        id: command["id"]! as String,
        command: "get_state",
        data: {"sessionId": "s1"},
      );
      started.process.exit(code: 0);

      expect((await pending).data["sessionId"], "s1");
    });

    test("surfaces an asynchronous stdin failure and reaps the process", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);
      final pending = started.client.send(
        command: PiRpcCommand.getState,
        arguments: const {},
        timeout: const Duration(seconds: 5),
      );
      await waitForCommand(process: started.process, type: "get_state");

      started.process.failStdin(error: const SocketException("broken pipe"));

      await expectLater(
        pending,
        throwsA(isA<PiRpcStdinException>().having((error) => error.cause, "cause", isA<SocketException>())),
      );
      expect(started.process.killed, isTrue);
    });

    test("fails fast once the process has exited", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);
      started.process.exit(code: 0);
      await pump(10);

      // Without the exit check this would write to a dead pipe and then block
      // for the whole timeout awaiting a reply that can never come.
      await expectLater(
        started.client.send(
          command: PiRpcCommand.getState,
          arguments: const {},
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<PiRpcProcessExitException>()),
      );
    });

    test("reports a broken pipe instead of orphaning the request", () async {
      final process = FakePiProcess(stdinWritesFail: true);
      final started = await startTestClient(process: process);
      addTearDown(started.client.dispose);

      await expectLater(
        started.client.send(
          command: PiRpcCommand.getState,
          arguments: const {},
          timeout: const Duration(seconds: 5),
        ),
        throwsA(
          isA<PiRpcWriteException>()
              .having((error) => error.command, "command", PiRpcCommand.getState)
              .having((error) => error.cause, "cause", isA<SocketException>()),
        ),
      );
      expect(started.client.sendExtensionUiResponse(id: "d1", reply: const PiExtensionUiCancelledReply()), isFalse);
    });

    test("fails in-flight requests on dispose", () async {
      final started = await startTestClient();

      final pending = started.client.send(
        command: PiRpcCommand.getState,
        arguments: const {},
        timeout: const Duration(seconds: 5),
      );
      final expectation = expectLater(pending, throwsA(isA<PiRpcDisposedException>()));
      await pump();
      await started.client.dispose();

      await expectation;
    });
  });

  group("startup buffering", () {
    test("replays frames parsed before the first listener attached", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      // Pi streams as soon as it starts; the router attaches afterwards.
      started.process.emit(
        frame: piEventFixture(type: "agent_start", fields: const {}),
      );
      started.process.emit(
        frame: piEventFixture(type: "turn_start", fields: const {}),
      );
      await pump(10);

      final seen = <PiRpcFrame>[];
      started.client.frames.listen(seen.add);
      await pump(10);
      started.process.emit(
        frame: piEventFixture(type: "agent_settled", fields: const {}),
      );
      await pump(10);

      expect(
        seen.map((frame) => (frame as PiEventFrame).event.runtimeType.toString()),
        ["PiAgentStartEvent", "PiTurnStartEvent", "PiAgentSettledEvent"],
      );
    });

    test("keeps draining stdout when nothing ever attaches", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      // Pi applies stdout backpressure to its own agent, so the drain must stay
      // unconditional and bounded rather than growing with the run.
      for (var i = 0; i < 600; i++) {
        started.process.emit(
          frame: piEventFixture(type: "agent_start", fields: const {}),
        );
      }
      await pump(20);
      final pending = started.client.send(
        command: PiRpcCommand.getState,
        arguments: const {},
        timeout: const Duration(seconds: 5),
      );
      final command = await waitForCommand(process: started.process, type: "get_state");
      started.process.emitResponse(id: command["id"]! as String, command: "get_state");

      expect((await pending).command, PiRpcCommand.getState);
    });
  });

  group("stderr diagnostics", () {
    test("process exit waits for stderr diagnostics to drain", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      final exit = started.client.processExit;
      started.process.emitStderrRaw(bytes: utf8.encode("late diagnostic\n"));
      started.process.exit(code: 1);

      expect(await exit, 1);
      expect(started.client.stderrDiagnostics, contains("late diagnostic"));
    });

    test("retains a bounded redacted tail and survives non-UTF-8 output", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      started.process.emitStderrRaw(bytes: [0xC3, 0x28, 0xA0, 0xA1, 0x0A]);
      for (var i = 0; i < 30; i++) {
        started.process.emitStderrRaw(bytes: utf8.encode("warning $i\n"));
      }
      started.process.emitStderrRaw(bytes: utf8.encode('{"api_key":"sk-live-secret","note":"x"}\n'));
      started.process.emitStderrRaw(
        bytes: utf8.encode('{"authorization":"Bearer quoted-secret"}\n'),
      );
      started.process.emitStderrRaw(bytes: utf8.encode("Authorization: Bearer header-secret\n"));
      started.process.emitStderrRaw(bytes: utf8.encode("Authorization: Basic basic-secret\n"));
      started.process.emitStderrRaw(
        bytes: utf8.encode('{"access_token":"long-secret-${"x" * 600}"}\n'),
      );
      started.process.emitStderrRaw(bytes: utf8.encode('{"password": malformed-secret}\n'));
      started.process.emitStderrRaw(bytes: utf8.encode('{"refreshToken":"refresh-secret"}\n'));
      started.process.emitStderrRaw(
        bytes: utf8.encode('{"token":["array-secret","second-secret"]}\n'),
      );
      started.process.emitStderrRaw(bytes: utf8.encode('{"x-api-key":"prefixed-secret"}\n'));
      started.process.emitStderrRaw(
        bytes: utf8.encode(
          '{"headers":{"sessionToken":"session-secret","safe":"kept"},'
          '"client_secret":"client-secret","model":"pi"}\n',
        ),
      );
      started.process.emitStderrRaw(bytes: utf8.encode("${"z" * 900}\n"));
      await pump(10);

      final tail = started.client.stderrDiagnostics;
      expect(tail, hasLength(20));
      expect(tail.first, "warning 21");
      expect(tail.join("\n"), isNot(contains("sk-live-secret")));
      expect(tail.join("\n"), isNot(contains("quoted-secret")));
      expect(tail.join("\n"), isNot(contains("header-secret")));
      expect(tail.join("\n"), isNot(contains("basic-secret")));
      expect(tail.join("\n"), isNot(contains("long-secret")));
      expect(tail.join("\n"), isNot(contains("malformed-secret")));
      expect(tail.join("\n"), isNot(contains("refresh-secret")));
      expect(tail.join("\n"), isNot(contains("array-secret")));
      expect(tail.join("\n"), isNot(contains("second-secret")));
      expect(tail.join("\n"), isNot(contains("prefixed-secret")));
      expect(tail.join("\n"), isNot(contains("session-secret")));
      expect(tail.join("\n"), isNot(contains("client-secret")));
      expect(tail, contains('{"api_key":"***","note":"x"}'));
      expect(tail, contains('{"authorization":"***"}'));
      expect(tail, contains("Authorization: Bearer ***"));
      expect(tail, contains("Authorization: Basic ***"));
      expect(tail, contains('{"access_token":"***"'));
      expect(tail, contains('{"password": ***'));
      expect(tail, contains('{"refreshToken":"***"}'));
      expect(tail, contains('{"token":"***"}'));
      expect(tail, contains('{"x-api-key":"***"}'));
      expect(
        tail,
        contains(
          '{"headers":{"sessionToken":"***","safe":"kept"},'
          '"client_secret":"***","model":"pi"}',
        ),
      );
      expect(tail.last.length, 500);
      expect(started.client.isRunning, isTrue);
    });

    test("bounds a fragmented stderr record before LF arrives", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      for (var i = 0; i < 100; i++) {
        started.process.emitStderrRaw(bytes: utf8.encode("x" * 100));
      }
      started.process.emitStderrRaw(bytes: utf8.encode("\n"));
      await pump(10);

      expect(started.client.stderrDiagnostics.single.length, 500);
      expect(started.client.isRunning, isTrue);
    });
  });

  group("teardown", () {
    test("does not wait for a stalled process factory", () async {
      final process = FakePiProcess();
      final processFactory = Completer<PiProcessHandle>();
      final client = PiRpcClient(
        launchSpec: testLaunchSpec(),
        processFactory: ({required spec}) => processFactory.future,
      );
      final starting = client.start();
      final startingFailure = expectLater(starting, throwsStateError);
      await pump();
      final completion = Timer(const Duration(milliseconds: 100), () => processFactory.complete(process));
      final stopwatch = Stopwatch()..start();

      await client.dispose(gracefulTimeout: const Duration(milliseconds: 20));

      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 50)));
      await startingFailure;
      completion.cancel();
      expect(process.killed, isTrue);
    });

    test("closes stdin first and then terminates the process", () async {
      final started = await startTestClient();

      await started.client.dispose();

      expect(started.process.stdinClosed, isTrue);
      expect(started.process.killed, isTrue);
      expect(started.client.isRunning, isFalse);
    });

    test("terminates when closing stdin stalls", () async {
      final process = FakePiProcess(stdinCloseCompletes: false);
      final started = await startTestClient(process: process);

      await started.client.dispose(gracefulTimeout: const Duration(milliseconds: 20));

      expect(process.killed, isTrue);
    });

    test("is idempotent and refuses a restart", () async {
      final started = await startTestClient();

      await started.client.dispose();
      await started.client.dispose();

      await expectLater(started.client.start(), throwsStateError);
    });

    test("makes concurrent dispose callers await the same teardown", () async {
      final process = FakePiProcess(stdinCloseCompletes: false);
      final started = await startTestClient(process: process);

      final first = started.client.dispose(gracefulTimeout: const Duration(seconds: 1));
      final second = started.client.dispose(gracefulTimeout: const Duration(seconds: 1));
      var secondCompleted = false;
      unawaited(second.then((_) => secondCompleted = true));
      await pump();
      expect(secondCompleted, isFalse);

      process.completeStdinClose();
      await Future.wait([first, second]);
      expect(process.killed, isTrue);
    });

    test("ignores frames from a process torn down earlier", () async {
      final started = await startTestClient();
      final seen = <PiRpcFrame>[];
      started.client.frames.listen(seen.add);
      await pump();

      await started.client.dispose();
      started.process.emit(
        frame: piEventFixture(type: "agent_settled", fields: const {}),
      );
      await pump(10);

      expect(seen, isEmpty);
    });

    test("reaps a process that spawned while teardown was in flight", () async {
      final process = FakePiProcess();
      addTearDown(process.close);
      final spawnGate = Completer<void>();
      final client = PiRpcClient(
        launchSpec: testLaunchSpec(),
        processFactory: ({required spec}) async {
          await spawnGate.future;
          return process;
        },
      );

      final starting = client.start();
      await pump();
      // Dispose sees no process to reap, because the spawn has not returned.
      final disposing = client.dispose();
      var disposeCompleted = false;
      unawaited(disposing.then((_) => disposeCompleted = true));
      await pump();
      expect(disposeCompleted, isTrue);
      spawnGate.complete();

      await expectLater(starting, throwsStateError);
      await disposing;
      // Without the post-spawn generation check the child would leak.
      expect(process.killed, isTrue);
    });
  });

  group("extension ui replies", () {
    test("writes each reply shape against the dialog id", () async {
      final started = await startTestClient();
      addTearDown(started.client.dispose);

      started.client.sendExtensionUiResponse(
        id: "d1",
        reply: const PiExtensionUiValueReply(value: "picked"),
      );
      started.client.sendExtensionUiResponse(id: "d2", reply: const PiExtensionUiConfirmationReply(confirmed: true));
      started.client.sendExtensionUiResponse(id: "d3", reply: const PiExtensionUiCancelledReply());
      await pump();

      final written = started.process.written;
      expect(written.map((frame) => frame["type"]).toSet(), {"extension_ui_response"});
      expect(written[0]["id"], "d1");
      expect(written[0]["value"], "picked");
      expect(written[1]["confirmed"], isTrue);
      expect(written[2]["cancelled"], isTrue);
    });
  });
}
